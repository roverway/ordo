import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/mcp/mcp_server.dart';
import 'package:ordo/core/ai/tools/ai_tool.dart';
import 'package:ordo/core/ai/tools/ai_tool_registry.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';

import '../../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repository;
  late McpServer server;
  late HttpClient httpClient;
  late int serverPort;

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    await repository.ensureInboxProject('收件箱');

    final registry = AiToolRegistry.standard();
    server = McpServer(
      registry: registry,
      contextProvider: () => AiToolContext(
        repository: repository,
        nowUtcMs: DateTime.utc(2026, 9, 29, 12, 0).millisecondsSinceEpoch,
      ),
    );

    // Bind to port 0 (ephemeral) for reliable test execution
    serverPort = await server.start(port: 0);
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close(force: true);
    await server.stop();
    await db.close();
  });

  Future<Map<String, dynamic>> sendRpcRequest(
    Map<String, dynamic> rpcPayload,
  ) async {
    final request = await httpClient.postUrl(
      Uri.parse('http://127.0.0.1:$serverPort/mcp'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(rpcPayload));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);

    final body = await utf8.decoder.bind(response).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('McpServer HTTP & CORS & Lifecycle', () {
    test('starts and exposes running state and port', () {
      expect(server.isRunning, isTrue);
      expect(server.port, serverPort);
      expect(server.endpointUrl, 'http://127.0.0.1:$serverPort/mcp');
    });

    test('responds with health/status info on GET request', () async {
      final request = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(response.headers.value('Access-Control-Allow-Origin'), '*');

      final body = await utf8.decoder.bind(response).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(data['status'], 'ok');
      expect(data['server'], 'ordo-tasks');
      expect(data['toolsCount'], 4);
    });

    test('supports CORS preflight OPTIONS request', () async {
      final request = await httpClient.openUrl(
        'OPTIONS',
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      final response = await request.close();

      expect(response.statusCode, HttpStatus.noContent);
      expect(response.headers.value('Access-Control-Allow-Origin'), '*');
      expect(
        response.headers.value('Access-Control-Allow-Methods'),
        contains('POST'),
      );
    });

    test('allows localhost Origin and reflects it', () async {
      final request = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      request.headers.set('Origin', 'http://localhost:3000');
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.headers.value('Access-Control-Allow-Origin'),
        'http://localhost:3000',
      );
    });

    test('blocks external Origin with 403 Forbidden', () async {
      final request = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      request.headers.set('Origin', 'https://malicious-website.com');
      final response = await request.close();

      expect(response.statusCode, HttpStatus.forbidden);
    });
  });

  group('McpServer JSON-RPC 2.0 Protocol', () {
    test('handles initialize method', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {'protocolVersion': '2024-11-05'},
      });

      expect(res['jsonrpc'], '2.0');
      expect(res['id'], 1);
      final result = res['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');
      expect(result['serverInfo']['name'], 'ordo-tasks');
      expect(result['capabilities']['tools'], isNotNull);
    });

    test('handles ping method', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 42,
        'method': 'ping',
      });

      expect(res['jsonrpc'], '2.0');
      expect(res['id'], 42);
      expect(res['result'], isEmpty);
    });

    test('handles tools/list method returning 4 standard tools', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      expect(res['jsonrpc'], '2.0');
      expect(res['id'], 2);
      final tools = res['result']['tools'] as List;
      expect(tools.length, 4);

      final toolNames = tools.map((t) => t['name']).toSet();
      expect(
        toolNames,
        containsAll([
          'query_tasks',
          'get_metadata',
          'create_tasks',
          'update_task',
        ]),
      );
    });

    test('handles tools/call for get_metadata', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {'name': 'get_metadata', 'arguments': {}},
      });

      expect(res['jsonrpc'], '2.0');
      expect(res['id'], 3);
      expect(res['result']['isError'], isFalse);

      final content = res['result']['content'] as List;
      expect(content.first['type'], 'text');
      final data =
          jsonDecode(content.first['text'] as String) as Map<String, dynamic>;
      expect(data['projects'], isNotEmpty);
      expect(data['now']['date'], contains('2026-09-29'));
    });

    test(
      'handles tools/call for query_tasks backed by TaskQueryEngine',
      () async {
        // Insert a sample task in database
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'mcp-task-1',
            projectId: 'inbox',
            title: 'Review MCP architecture specification',
            status: TaskStatus.todo,
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

        final res = await sendRpcRequest({
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'tools/call',
          'params': {
            'name': 'query_tasks',
            'arguments': {'searchQuery': 'architecture'},
          },
        });

        expect(res['result']['isError'], isFalse);
        final content = res['result']['content'] as List;
        final data =
            jsonDecode(content.first['text'] as String) as Map<String, dynamic>;
        expect(data['totalMatched'], 1);
        final tasks = data['tasks'] as List;
        expect(tasks.first['title'], 'Review MCP architecture specification');
      },
    );

    test('returns standard error for unknown method', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 99,
        'method': 'non_existent_method',
      });

      expect(res['jsonrpc'], '2.0');
      expect(res['id'], 99);
      expect(res['error']['code'], -32601);
      expect(res['error']['message'], contains('Method not found'));
    });

    test('returns standard parse error on invalid JSON', () async {
      final request = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      request.headers.contentType = ContentType.json;
      request.write('{ broken json... ');
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      final body = await utf8.decoder.bind(response).join();
      final res = jsonDecode(body) as Map<String, dynamic>;

      expect(res['error']['code'], -32700);
      expect(res['error']['message'], contains('Parse error'));
    });
  });
}
