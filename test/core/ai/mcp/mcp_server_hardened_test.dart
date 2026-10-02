import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/mcp/mcp_server.dart';
import 'package:ordo/core/ai/proposals/proposal_repository.dart';
import 'package:ordo/core/ai/tools/ai_tool.dart';
import 'package:ordo/core/ai/tools/ai_tool_registry.dart';
import 'package:ordo/core/ai/tools/impl/daily_briefing_tool.dart';
import 'package:ordo/core/ai/tools/impl/manage_tags_tool.dart';
import 'package:ordo/core/ai/tools/impl/query_tasks_tool.dart';
import 'package:ordo/core/ai/tools/impl/create_tasks_tool.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:drift/drift.dart' as drift;

import '../../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repository;
  late ProposalRepository proposalRepository;
  late AiToolRegistry registry;
  late McpServer server;
  late HttpClient httpClient;
  late int serverPort;

  String currentWriteMode = 'review';

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    proposalRepository = ProposalRepository(db);
    await repository.ensureInboxProject('收件箱');

    currentWriteMode = 'review';
    registry = AiToolRegistry.standard();

    server = McpServer(
      registry: registry,
      apiKeyProvider: () => null,
      isAuthEnabledProvider: () => false,
      contextProvider: () => AiToolContext(
        repository: repository,
        proposalRepository: proposalRepository,
        writeMode: currentWriteMode,
        nowUtcMs: DateTime.utc(2026, 10, 2, 12, 0).millisecondsSinceEpoch,
      ),
    );

    serverPort = await server.start(port: 0);
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close(force: true);
    await server.stop();
    await db.close();
  });

  Future<Map<String, dynamic>> postRpc(Map<String, dynamic> rpc) async {
    final req = await httpClient.post('127.0.0.1', serverPort, '/mcp');
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode(rpc));
    final resp = await req.close();
    final body = await utf8.decoder.bind(resp).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  group('P0 Remediation Tests: Protocol & Guardrails', () {
    test('Protocol negotiation defaults to supported version', () async {
      final res = await postRpc({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2099-01-01',
          'capabilities': {},
          'clientInfo': {'name': 'test-client', 'version': '1.0'},
        },
      });

      expect(res['result'] != null, isTrue);
      expect(res['result']['protocolVersion'], '2024-11-05');
    });

    test(
      'tools/call with non-string name returns -32602 instead of internal crash',
      () async {
        final res = await postRpc({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/call',
          'params': {
            'name': 12345, // invalid type
            'arguments': {},
          },
        });

        expect(res['error'] != null, isTrue);
        expect(res['error']['code'], -32602);
      },
    );

    test(
      'Unknown query_tasks parameter returns INVALID_ARGUMENT fail-fast',
      () async {
        final tool = const QueryTasksTool();
        final ctx = AiToolContext(
          repository: repository,
          proposalRepository: proposalRepository,
        );

        final res = await tool.execute({'nonExistentFilter': 'value'}, ctx);

        expect(res.success, isFalse);
        expect(res.errorCode, 'INVALID_ARGUMENT');
        expect(res.error, contains('Unknown parameter'));
      },
    );

    test('Invalid dateScope enum returns INVALID_ARGUMENT fail-fast', () async {
      final tool = const QueryTasksTool();
      final ctx = AiToolContext(
        repository: repository,
        proposalRepository: proposalRepository,
      );

      final res = await tool.execute({'dateScope': 'bogusScope'}, ctx);

      expect(res.success, isFalse);
      expect(res.errorCode, 'INVALID_ARGUMENT');
    });

    test(
      'Server-enforced review mode strictly ignores client mode direct',
      () async {
        final tool = const CreateTasksTool();
        final ctx = AiToolContext(
          repository: repository,
          proposalRepository: proposalRepository,
          writeMode: 'review',
        );

        final res = await tool.execute({
          'title': 'Test Review Task',
          'mode': 'direct', // Client attempts bypass
        }, ctx);

        expect(res.success, isTrue);
        final data = res.data as Map<String, dynamic>;
        expect(data['status'], 'pending');
        expect(data['writeMode'], 'review');
        expect(data['proposalId'] != null, isTrue);

        // Verify task was NOT inserted into db
        final tasks = await db.select(db.tasks).get();
        expect(
          tasks.where((t) => t.title == 'Test Review Task').isEmpty,
          isTrue,
        );
      },
    );

    test(
      'Direct write rejects invalid calendar date like 2026-02-30',
      () async {
        final tool = const CreateTasksTool();
        final ctx = AiToolContext(
          repository: repository,
          proposalRepository: proposalRepository,
          writeMode: 'direct',
        );

        final res = await tool.execute({
          'title': 'Test Invalid Date Task',
          'dueDate': '2026-02-30', // Impossible date
        }, ctx);

        expect(res.success, isFalse);
        expect(res.errorCode, 'UNPARSEABLE_DATE');
      },
    );

    test(
      'Direct write idempotency key prevents duplicate insertions',
      () async {
        final tool = const CreateTasksTool();
        final ctx = AiToolContext(
          repository: repository,
          proposalRepository: proposalRepository,
          writeMode: 'direct',
        );

        final res1 = await tool.execute({
          'title': 'Idempotent Task',
          'idempotencyKey': 'key-abc-123',
        }, ctx);
        expect(res1.success, isTrue);
        expect((res1.data as Map)['status'], 'created');

        // Second call with same key
        final res2 = await tool.execute({
          'title': 'Idempotent Task',
          'idempotencyKey': 'key-abc-123',
        }, ctx);
        expect(res2.success, isTrue);
        final data2 = res2.data as Map<String, dynamic>;
        expect(data2['idempotentReplay'], isTrue);

        final tasks = await db.select(db.tasks).get();
        expect(tasks.where((t) => t.title == 'Idempotent Task').length, 1);
      },
    );
  });

  group('New High-Leverage Tools', () {
    test(
      'DailyBriefingTool aggregates statistics across statuses and horizons',
      () async {
        final nowMs = DateTime.utc(2026, 10, 2, 12, 0).millisecondsSinceEpoch;

        // Seed 1 overdue task, 1 today task
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'task-overdue',
            projectId: 'inbox',
            title: 'Overdue Task',
            sortOrder: 0,
            status: TaskStatus.todo,
            endAt: drift.Value(nowMs - 86400000),
            createdAt: nowMs - 100000,
            updatedAt: nowMs - 100000,
          ),
        );
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'task-today',
            projectId: 'inbox',
            title: 'Today Task',
            sortOrder: 1,
            status: TaskStatus.todo,
            endAt: drift.Value(nowMs + 3600000),
            createdAt: nowMs - 50000,
            updatedAt: nowMs - 50000,
          ),
        );

        final tool = const DailyBriefingTool();
        final ctx = AiToolContext(
          repository: repository,
          proposalRepository: proposalRepository,
          nowUtcMs: nowMs,
        );

        final res = await tool.execute({}, ctx);
        expect(res.success, isTrue);
        final data = res.data as Map<String, dynamic>;

        expect(data['summary'] != null, isTrue);
        expect(data['summary']['overdueCount'], 1);
        expect(data['summary']['dueTodayCount'], 1);
        expect((data['overdue'] as List).length, 1);
        expect((data['dueToday'] as List).length, 1);
      },
    );

    test('ManageTagsTool lists, creates, and deletes tags', () async {
      final tool = const ManageTagsTool();
      final ctx = AiToolContext(
        repository: repository,
        proposalRepository: proposalRepository,
      );

      // 1. Create tag
      final createRes = await tool.execute({
        'action': 'create',
        'name': 'Sprint-42',
        'color': '#FF5500',
      }, ctx);
      expect(createRes.success, isTrue);
      final tagData = createRes.data as Map<String, dynamic>;
      expect(tagData['tag']['name'], 'Sprint-42');
      final tagId = tagData['tag']['id'] as String;

      // 2. List tags
      final listRes = await tool.execute({'action': 'list'}, ctx);
      expect(listRes.success, isTrue);
      final listData = listRes.data as Map<String, dynamic>;
      expect(
        (listData['tags'] as List).any((t) => t['name'] == 'Sprint-42'),
        isTrue,
      );

      // 3. Delete tag
      final delRes = await tool.execute({'action': 'delete', 'id': tagId}, ctx);
      expect(delRes.success, isTrue);

      // 4. Verify tag gone
      final listRes2 = await tool.execute({'action': 'list'}, ctx);
      final listData2 = listRes2.data as Map<String, dynamic>;
      expect((listData2['tags'] as List).any((t) => t['id'] == tagId), isFalse);
    });
  });
}
