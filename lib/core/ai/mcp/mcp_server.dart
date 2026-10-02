import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';

/// Lightweight, embedded Model Context Protocol (MCP) HTTP Server.
///
/// Implements standard JSON-RPC 2.0 handling for MCP methods:
/// - `initialize`
/// - `notifications/initialized`
/// - `ping`
/// - `tools/list`
/// - `tools/call`
///
/// Security: Binds strictly to [InternetAddress.loopbackIPv4] (`127.0.0.1`)
/// so that only local client applications (e.g. Cursor, Claude Desktop, local scripts)
/// can communicate with this service. CORS is constrained to localhost or non-browser callers.
/// Optional API Key validation protects against unauthorized local port access.
class McpServer {
  McpServer({
    required AiToolRegistry registry,
    required AiToolContext Function() contextProvider,
    this.serverName = 'ordo-tasks',
    this.serverVersion = '1.0.0',
    this.protocolVersion = '2024-11-05',
    this.apiKeyProvider,
    this.isAuthEnabledProvider,
  }) : _registry = registry,
       _contextProvider = contextProvider;

  final AiToolRegistry _registry;
  final AiToolContext Function() _contextProvider;
  final String serverName;
  final String serverVersion;
  final String protocolVersion;
  final String? Function()? apiKeyProvider;
  final bool Function()? isAuthEnabledProvider;

  HttpServer? _server;
  int? _port;

  /// Whether the MCP server is currently listening.
  bool get isRunning => _server != null;

  /// The active listening port, or null if stopped.
  int? get port => _port;

  /// Full endpoint URL for external MCP clients.
  String? get endpointUrl =>
      _server != null ? 'http://127.0.0.1:$_port/mcp' : null;

  /// Starts the MCP server on the specified [port] (default: 8765).
  ///
  /// If the requested port is taken, setting [allowFallbackPort] to true
  /// will bind to any available ephemeral port (port 0).
  Future<int> start({int port = 8765, bool allowFallbackPort = true}) async {
    if (_server != null) {
      return _port!;
    }

    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
      _port = _server!.port;
    } catch (e) {
      if (allowFallbackPort && port != 0) {
        _server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
          shared: false,
        );
        _port = _server!.port;
      } else {
        rethrow;
      }
    }

    _server!.listen(
      _handleRequest,
      onError: (Object error) {
        // Prevent unhandled server loop errors
      },
    );

    return _port!;
  }

  /// Stops the MCP server.
  Future<void> stop() async {
    if (_server == null) return;
    final serverToClose = _server;
    _server = null;
    _port = null;
    await serverToClose?.close(force: true);
  }

  /// Safely closes an HTTP response without uncaught broken pipe exceptions.
  Future<void> _safeClose(HttpResponse response) async {
    try {
      await response.close();
    } catch (_) {
      // Ignore socket reset or broken pipe from client disconnect
    }
  }

  /// Safely writes JSON content and closes the HTTP response.
  Future<void> _safeSendJson(
    HttpResponse response,
    dynamic data, {
    int statusCode = HttpStatus.ok,
  }) async {
    try {
      response.headers.contentType = ContentType.json;
      response.statusCode = statusCode;
      response.write(jsonEncode(data));
      await response.close();
    } catch (_) {
      // Ignore premature client socket close
    }
  }

  /// Internal HTTP request dispatcher with localhost CORS protection.
  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;

    // Origin header inspection to defend against cross-origin browser DNS rebinding/port scanning
    final origin = request.headers.value('origin');
    if (origin != null && origin.isNotEmpty) {
      final uri = Uri.tryParse(origin);
      final isLocal =
          uri != null &&
          (uri.host == 'localhost' ||
              uri.host == '127.0.0.1' ||
              uri.host == '::1');
      if (!isLocal) {
        response.statusCode = HttpStatus.forbidden;
        await _safeClose(response);
        return;
      }
      response.headers.set('Access-Control-Allow-Origin', origin);
    } else {
      // Non-browser local CLI / desktop tools (Claude Desktop, Cursor, curl)
      response.headers.set('Access-Control-Allow-Origin', '*');
    }

    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization, x-api-key',
    );

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await _safeClose(response);
      return;
    }

    // Health-check / Status info via GET
    if (request.method == 'GET') {
      final statusInfo = {
        'status': 'ok',
        'server': serverName,
        'version': serverVersion,
        'protocolVersion': protocolVersion,
        'toolsCount': _registry.allTools.length,
        'endpoint': endpointUrl,
        'authRequired': isAuthEnabledProvider?.call() ?? false,
      };
      await _safeSendJson(response, statusInfo);
      return;
    }

    if (request.method != 'POST') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await _safeClose(response);
      return;
    }

    // Validate API Key authentication if enabled
    final authEnabled = isAuthEnabledProvider?.call() ?? false;
    if (authEnabled) {
      final expectedKey = apiKeyProvider?.call();
      if (expectedKey != null && expectedKey.isNotEmpty) {
        final authHeader = request.headers.value('authorization');
        final xApiKey = request.headers.value('x-api-key');
        String? providedKey;
        if (xApiKey != null && xApiKey.isNotEmpty) {
          providedKey = xApiKey.trim();
        } else if (authHeader != null &&
            authHeader.toLowerCase().startsWith('bearer ')) {
          providedKey = authHeader.substring(7).trim();
        }

        if (providedKey == null || providedKey != expectedKey) {
          response.statusCode = HttpStatus.unauthorized;
          await _writeJsonRpcError(
            response,
            id: null,
            code: -32001,
            message:
                'Unauthorized: Invalid or missing API Key. Pass x-api-key or Authorization: Bearer <key>',
          );
          return;
        }
      }
    }

    // Read and parse JSON-RPC payload with timeout to avoid lingering hung sockets
    try {
      final bodyString = await utf8.decoder
          .bind(request)
          .join()
          .timeout(const Duration(seconds: 10));

      if (bodyString.trim().isEmpty) {
        await _writeJsonRpcError(
          response,
          id: null,
          code: -32600,
          message: 'Invalid Request: empty body',
        );
        return;
      }

      final dynamic decoded = jsonDecode(bodyString);
      if (decoded is List) {
        if (decoded.isEmpty) {
          await _writeJsonRpcError(
            response,
            id: null,
            code: -32600,
            message: 'Invalid Request: empty batch',
          );
          return;
        }
        // Batch requests
        final responses = <Map<String, dynamic>>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final res = await _processSingleRpc(item);
            if (res != null) responses.add(res);
          } else {
            responses.add({
              'jsonrpc': '2.0',
              'id': null,
              'error': {
                'code': -32600,
                'message': 'Invalid Request: batch item must be an object',
              },
            });
          }
        }
        if (responses.isEmpty) {
          response.statusCode = HttpStatus.accepted;
          await _safeClose(response);
          return;
        }
        await _safeSendJson(response, responses);
      } else if (decoded is Map<String, dynamic>) {
        final result = await _processSingleRpc(decoded);
        if (result != null) {
          await _safeSendJson(response, result);
        } else {
          response.statusCode = HttpStatus.accepted;
          await _safeClose(response);
        }
      } else {
        await _writeJsonRpcError(
          response,
          id: null,
          code: -32600,
          message: 'Invalid Request: expected JSON object or array',
        );
      }
    } on TimeoutException {
      await _writeJsonRpcError(
        response,
        id: null,
        code: -32603,
        message: 'Request body read timeout after 10s',
      );
    } on FormatException {
      await _writeJsonRpcError(
        response,
        id: null,
        code: -32700,
        message: 'Parse error: invalid JSON',
      );
    } catch (e) {
      await _writeJsonRpcError(
        response,
        id: null,
        code: -32603,
        message: 'Internal error: $e',
      );
    }
  }

  /// Processes a single JSON-RPC 2.0 object.
  Future<Map<String, dynamic>?> _processSingleRpc(
    Map<String, dynamic> request,
  ) async {
    final id = request['id'];
    final method = request['method'];
    final isNotification = id == null;

    if (method is! String) {
      if (isNotification) return null;
      return _buildRpcError(
        id: id,
        code: -32600,
        message: 'Invalid Request: missing method',
      );
    }

    try {
      switch (method) {
        case 'initialize':
          final initParams = request['params'] as Map<String, dynamic>?;
          final clientVersion = initParams?['protocolVersion']?.toString();
          final effectiveVersion =
              (clientVersion == '2025-03-26' || clientVersion == '2024-11-05')
              ? clientVersion!
              : protocolVersion;
          return _buildRpcSuccess(
            id: id,
            result: {
              'protocolVersion': effectiveVersion,
              'serverInfo': {'name': serverName, 'version': serverVersion},
              'capabilities': {
                'tools': {'listChanged': false},
              },
            },
          );

        case 'notifications/initialized':
          // Notification: no response required
          return null;

        case 'ping':
          return _buildRpcSuccess(id: id, result: <String, dynamic>{});

        case 'tools/list':
          return _buildRpcSuccess(
            id: id,
            result: {'tools': _registry.toMcpDefinitions()},
          );

        case 'tools/call':
          final params = request['params'] as Map<String, dynamic>?;
          if (params == null || !params.containsKey('name')) {
            return _buildRpcError(
              id: id,
              code: -32602,
              message: 'Invalid params: name required for tools/call',
            );
          }

          final rawName = params['name'];
          if (rawName is! String) {
            return _buildRpcError(
              id: id,
              code: -32602,
              message: 'Invalid params: "name" must be a string',
            );
          }
          final toolName = rawName;
          final arguments =
              (params['arguments'] as Map<String, dynamic>?) ?? {};
          final context = _contextProvider();

          final toolResult = await _registry.dispatch(
            toolName,
            arguments,
            context,
          );

          if (!toolResult.success) {
            return _buildRpcSuccess(
              id: id,
              result: {
                'content': [
                  {
                    'type': 'text',
                    'text': jsonEncode({
                      'isError': true,
                      'error': {
                        'code': toolResult.errorCode ?? 'EXECUTION_FAILED',
                        'message': toolResult.error,
                        if (toolResult.errorHint != null)
                          'hint': toolResult.errorHint,
                        if (toolResult.errorDetails != null)
                          'details': toolResult.errorDetails,
                      },
                    }),
                  },
                ],
                'isError': true,
              },
            );
          }

          return _buildRpcSuccess(
            id: id,
            result: {
              'content': [
                {'type': 'text', 'text': jsonEncode(toolResult.data)},
              ],
              'isError': false,
            },
          );

        default:
          if (isNotification) return null;
          return _buildRpcError(
            id: id,
            code: -32601,
            message: 'Method not found: $method',
          );
      }
    } catch (e) {
      if (isNotification) return null;
      return _buildRpcError(
        id: id,
        code: -32603,
        message: 'Internal error while processing $method: $e',
      );
    }
  }

  Map<String, dynamic> _buildRpcSuccess({
    required dynamic id,
    required dynamic result,
  }) {
    return {'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic> _buildRpcError({
    required dynamic id,
    required int code,
    required String message,
  }) {
    return {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message},
    };
  }

  Future<void> _writeJsonRpcError(
    HttpResponse response, {
    required dynamic id,
    required int code,
    required String message,
  }) async {
    final errorPayload = _buildRpcError(id: id, code: code, message: message);
    await _safeSendJson(response, errorPayload, statusCode: HttpStatus.ok);
  }
}
