import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/mcp/mcp_server.dart';
import 'package:ordo/core/ai/proposals/proposal_repository.dart';
import 'package:ordo/core/ai/tools/ai_tool.dart';
import 'package:ordo/core/ai/tools/ai_tool_registry.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';

import '../../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repository;
  late ProposalRepository proposalRepository;
  late McpServer server;
  late HttpClient httpClient;
  late int serverPort;

  String? currentApiKey;
  bool isAuthEnabled = false;
  String currentWriteMode = 'direct';

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    proposalRepository = ProposalRepository(db);
    await repository.ensureInboxProject('收件箱');

    isAuthEnabled = false;
    currentApiKey = 'test-secret-key-12345';
    currentWriteMode = 'direct';

    final registry = AiToolRegistry.standard();
    server = McpServer(
      registry: registry,
      apiKeyProvider: () => currentApiKey,
      isAuthEnabledProvider: () => isAuthEnabled,
      contextProvider: () => AiToolContext(
        repository: repository,
        proposalRepository: proposalRepository,
        writeMode: currentWriteMode,
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
    Map<String, dynamic> rpcPayload, {
    Map<String, String>? headers,
  }) async {
    final request = await httpClient.postUrl(
      Uri.parse('http://127.0.0.1:$serverPort/mcp'),
    );
    request.headers.contentType = ContentType.json;
    if (headers != null) {
      headers.forEach((k, v) => request.headers.set(k, v));
    }
    request.write(jsonEncode(rpcPayload));
    final response = await request.close();

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
      expect(data['toolsCount'], 11);
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
      final request = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      request.headers.set('Origin', 'http://localhost:3000');
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'jsonrpc': '2.0', 'id': 1, 'method': 'ping'}));
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      expect(
        response.headers.value('Access-Control-Allow-Origin'),
        'http://localhost:3000',
      );
    });

    test('blocks external Origin with 403 Forbidden', () async {
      final request = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$serverPort/mcp'),
      );
      request.headers.set('Origin', 'https://malicious-website.com');
      final response = await request.close();

      expect(response.statusCode, HttpStatus.forbidden);
    });
  });

  group('McpServer API Key Authentication', () {
    setUp(() {
      isAuthEnabled = true;
    });

    test('rejects request with missing API key when auth enabled', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'ping',
      });

      expect(res['error']['code'], -32001);
      expect(res['error']['message'], contains('Unauthorized'));
    });

    test('rejects request with incorrect API key', () async {
      final res = await sendRpcRequest(
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        headers: {'x-api-key': 'wrong-key'},
      );

      expect(res['error']['code'], -32001);
      expect(res['error']['message'], contains('Unauthorized'));
    });

    test('accepts request with valid x-api-key', () async {
      final res = await sendRpcRequest(
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        headers: {'x-api-key': 'test-secret-key-12345'},
      );

      expect(res['id'], 1);
      expect(res['result'], isEmpty);
    });

    test('accepts request with valid Bearer token', () async {
      final res = await sendRpcRequest(
        {'jsonrpc': '2.0', 'id': 1, 'method': 'ping'},
        headers: {'Authorization': 'Bearer test-secret-key-12345'},
      );

      expect(res['id'], 1);
      expect(res['result'], isEmpty);
    });
  });

  group('McpServer Tools Protocol & Execution', () {
    test('handles tools/list returning 11 standard tools', () async {
      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      expect(res['id'], 2);
      final tools = res['result']['tools'] as List;
      expect(tools.length, 11);

      final names = tools.map((t) => t['name']).toSet();
      expect(
        names,
        containsAll([
          'query_tasks',
          'get_metadata',
          'create_tasks',
          'update_task',
          'create_tasks_bulk',
          'list_proposals',
          'confirm_proposals',
          'reject_proposals',
          'get_task',
          'delete_tasks',
          'aggregate_tasks',
        ]),
      );
    });

    test('direct write mode: create_tasks writes directly to DB', () async {
      currentWriteMode = 'direct';

      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 10,
        'method': 'tools/call',
        'params': {
          'name': 'create_tasks',
          'arguments': {
            'title': 'Direct Written Task',
            'description': 'Directly written by AI with API key',
            'priority': 3,
            'tags': ['Urgent', 'Backend'],
            'substeps': ['Step 1', 'Step 2'],
          },
        },
      });

      expect(res['result']['isError'], isFalse);
      final content = res['result']['content'] as List;
      final data =
          jsonDecode(content.first['text'] as String) as Map<String, dynamic>;

      expect(data['ok'], isTrue);
      expect(data['status'], 'created');
      expect(data['requiresConfirmation'], isFalse);
      final taskId = data['taskId'] as String;

      // Verify task exists in repository
      final dbTask = await repository.tasks.getById(taskId);
      expect(dbTask, isNotNull);
      expect(dbTask!.title, 'Direct Written Task');
      expect(dbTask.priority, TaskPriority.high);

      // Verify subtasks
      final children = await repository.tasks.getDirectChildren(
        dbTask.projectId,
        taskId,
      );
      expect(children.length, 2);
    });

    test(
      'proposal mode: create_tasks stages into ProposalRepository and confirms',
      () async {
        currentWriteMode = 'review';

        // 1. Create proposal
        final createRes = await sendRpcRequest({
          'jsonrpc': '2.0',
          'id': 20,
          'method': 'tools/call',
          'params': {
            'name': 'create_tasks',
            'arguments': {'title': 'Proposed Task for Review', 'priority': 2},
          },
        });

        final content = createRes['result']['content'] as List;
        final createData =
            jsonDecode(content.first['text'] as String) as Map<String, dynamic>;
        expect(createData['status'], 'pending');
        expect(createData['requiresConfirmation'], isTrue);
        final proposalId = createData['proposalId'] as String;

        // 2. List proposals
        final listRes = await sendRpcRequest({
          'jsonrpc': '2.0',
          'id': 21,
          'method': 'tools/call',
          'params': {
            'name': 'list_proposals',
            'arguments': {'status': 'pending'},
          },
        });
        final listData =
            jsonDecode(
                  (listRes['result']['content'] as List).first['text']
                      as String,
                )
                as Map<String, dynamic>;
        expect(listData['count'], greaterThanOrEqualTo(1));

        // 3. Confirm proposal
        final confirmRes = await sendRpcRequest({
          'jsonrpc': '2.0',
          'id': 22,
          'method': 'tools/call',
          'params': {
            'name': 'confirm_proposals',
            'arguments': {
              'proposalIds': [proposalId],
            },
          },
        });
        final confirmData =
            jsonDecode(
                  (confirmRes['result']['content'] as List).first['text']
                      as String,
                )
                as Map<String, dynamic>;
        expect(confirmData['summary']['succeeded'], 1);
        final createdTaskId = confirmData['results'][0]['taskId'] as String;

        final taskInDb = await repository.tasks.getById(createdTaskId);
        expect(taskInDb, isNotNull);
        expect(taskInDb!.title, 'Proposed Task for Review');
      },
    );

    test('create_tasks_bulk supports dryRun and batch creation', () async {
      currentWriteMode = 'direct';

      // 1. Dry run
      final dryRes = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 30,
        'method': 'tools/call',
        'params': {
          'name': 'create_tasks_bulk',
          'arguments': {
            'dryRun': true,
            'tasks': [
              {'title': 'Bulk Task 1'},
              {'title': 'Bulk Task 2'},
              {'title': ''}, // invalid
            ],
          },
        },
      });
      final dryData =
          jsonDecode(
                (dryRes['result']['content'] as List).first['text'] as String,
              )
              as Map<String, dynamic>;
      expect(dryData['dryRun'], isTrue);
      expect(dryData['summary']['valid'], 2);
      expect(dryData['summary']['invalid'], 1);

      // 2. Actual execution
      final execRes = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 31,
        'method': 'tools/call',
        'params': {
          'name': 'create_tasks_bulk',
          'arguments': {
            'tasks': [
              {'title': 'Bulk Task A'},
              {'title': 'Bulk Task B'},
            ],
          },
        },
      });
      final execData =
          jsonDecode(
                (execRes['result']['content'] as List).first['text'] as String,
              )
              as Map<String, dynamic>;
      expect(execData['summary']['succeeded'], 2);
    });

    test('get_task retrieves deep hierarchy and tags', () async {
      final task = await repository.createTask(
        projectId: 'inbox',
        title: 'Deep Task',
        description: 'With details',
      );
      await repository.createTask(
        projectId: 'inbox',
        parentId: task.id,
        title: 'Substep 1',
      );

      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 40,
        'method': 'tools/call',
        'params': {
          'name': 'get_task',
          'arguments': {'taskId': task.id},
        },
      });

      final data =
          jsonDecode((res['result']['content'] as List).first['text'] as String)
              as Map<String, dynamic>;
      expect(data['task']['title'], 'Deep Task');
      expect(data['task']['subtasks'], hasLength(1));
    });

    test('delete_tasks deletes task directly', () async {
      currentWriteMode = 'direct';
      final task = await repository.createTask(
        projectId: 'inbox',
        title: 'Task To Delete',
      );

      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 50,
        'method': 'tools/call',
        'params': {
          'name': 'delete_tasks',
          'arguments': {
            'taskIds': [task.id],
          },
        },
      });

      final data =
          jsonDecode((res['result']['content'] as List).first['text'] as String)
              as Map<String, dynamic>;
      expect(data['summary']['succeeded'], 1);

      final check = await repository.tasks.getActiveById(task.id);
      expect(check, isNull);
    });

    test('aggregate_tasks groups by priority', () async {
      await repository.createTask(
        projectId: 'inbox',
        title: 'High 1',
        priority: TaskPriority.high,
      );
      await repository.createTask(
        projectId: 'inbox',
        title: 'High 2',
        priority: TaskPriority.high,
      );
      await repository.createTask(
        projectId: 'inbox',
        title: 'Low 1',
        priority: TaskPriority.low,
      );

      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 60,
        'method': 'tools/call',
        'params': {
          'name': 'aggregate_tasks',
          'arguments': {'groupBy': 'priority'},
        },
      });

      final data =
          jsonDecode((res['result']['content'] as List).first['text'] as String)
              as Map<String, dynamic>;
      expect(data['total'], 3);
      expect(data['groupBy'], 'priority');
      final buckets = data['buckets'] as List;
      expect(buckets.any((b) => b['key'] == 'high' && b['count'] == 2), isTrue);
    });

    test('query_tasks supports field projection', () async {
      await repository.createTask(
        projectId: 'inbox',
        title: 'Field Projected Task',
        description: 'Long description that should not be returned',
      );

      final res = await sendRpcRequest({
        'jsonrpc': '2.0',
        'id': 70,
        'method': 'tools/call',
        'params': {
          'name': 'query_tasks',
          'arguments': {
            'fields': ['id', 'title', 'status'],
          },
        },
      });

      final data =
          jsonDecode((res['result']['content'] as List).first['text'] as String)
              as Map<String, dynamic>;
      final tasks = data['tasks'] as List;
      expect(tasks, isNotEmpty);
      final item = tasks.first as Map<String, dynamic>;
      expect(item.containsKey('title'), isTrue);
      expect(item.containsKey('status'), isTrue);
      expect(item.containsKey('description'), isFalse);
    });
  });
}
