import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/utils/uuid.dart';
import '../services/ai_task_executor.dart';

enum ProposalStatus {
  pending,
  confirmed,
  rejected,
  expired;

  static ProposalStatus fromString(String val) {
    for (final s in ProposalStatus.values) {
      if (s.name == val) return s;
    }
    return ProposalStatus.pending;
  }
}

class TaskProposal {
  const TaskProposal({
    required this.id,
    required this.type,
    required this.status,
    required this.payload,
    this.idempotencyKey,
    required this.createdAt,
    required this.expiresAt,
    this.processedAt,
    this.isReplayed = false,
  });

  final String id;
  final String type; // 'create' | 'update' | 'delete' | 'bulk_create'
  final ProposalStatus status;
  final Map<String, dynamic> payload;
  final String? idempotencyKey;
  final int createdAt; // epoch ms
  final int expiresAt; // epoch ms
  final int? processedAt; // epoch ms
  final bool isReplayed;

  Map<String, dynamic> toJson() => {
    'proposalId': id,
    'type': type,
    'status': status.name,
    'expiresAt': DateTime.fromMillisecondsSinceEpoch(
      expiresAt,
      isUtc: true,
    ).toIso8601String(),
    'createdAt': DateTime.fromMillisecondsSinceEpoch(
      createdAt,
      isUtc: true,
    ).toIso8601String(),
    if (processedAt != null)
      'processedAt': DateTime.fromMillisecondsSinceEpoch(
        processedAt!,
        isUtc: true,
      ).toIso8601String(),
    if (isReplayed) 'replayed': true,
    'preview': payload,
  };
}

class ProposalRepository {
  ProposalRepository(this._db);

  final AppDatabase _db;
  bool _initialized = false;

  /// Ensures the task_proposals table exists.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS task_proposals (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        status TEXT NOT NULL,
        payload TEXT NOT NULL,
        idempotency_key TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        processed_at INTEGER
      );
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_task_proposals_status ON task_proposals(status);
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_task_proposals_idempotency ON task_proposals(idempotency_key);
    ''');
    _initialized = true;
  }

  /// Creates a new proposal or returns an existing one if idempotency key matches.
  Future<TaskProposal> createProposal({
    required String type,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
    Duration ttl = const Duration(hours: 24),
  }) async {
    await ensureInitialized();
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    // Check idempotency
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      final existing = await _db
          .customSelect(
            'SELECT * FROM task_proposals WHERE idempotency_key = ? AND expires_at > ? LIMIT 1',
            variables: [
              Variable.withString(idempotencyKey),
              Variable.withInt(now),
            ],
          )
          .getSingleOrNull();

      if (existing != null) {
        return _mapRowToProposal(existing.data, isReplayed: true);
      }
    }

    final id = 'pp_${newUuid().replaceAll('-', '').substring(0, 16)}';
    final expiresAt = now + ttl.inMilliseconds;
    final payloadJson = jsonEncode(payload);

    await _db.customStatement(
      '''
      INSERT INTO task_proposals (id, type, status, payload, idempotency_key, created_at, expires_at, processed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, NULL)
      ''',
      [
        id,
        type,
        ProposalStatus.pending.name,
        payloadJson,
        idempotencyKey,
        now,
        expiresAt,
      ],
    );

    return TaskProposal(
      id: id,
      type: type,
      status: ProposalStatus.pending,
      payload: payload,
      idempotencyKey: idempotencyKey,
      createdAt: now,
      expiresAt: expiresAt,
    );
  }

  /// Fetches a proposal by ID.
  Future<TaskProposal?> getProposal(String id) async {
    await ensureInitialized();
    final row = await _db
        .customSelect(
          'SELECT * FROM task_proposals WHERE id = ? LIMIT 1',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();

    if (row == null) return null;
    return _mapRowToProposal(row.data);
  }

  /// Lists proposals filtered by status.
  Future<List<TaskProposal>> listProposals({
    String? status,
    int limit = 20,
    String? cursor,
  }) async {
    await ensureInitialized();

    var query = 'SELECT * FROM task_proposals WHERE 1=1';
    final variables = <Variable>[];

    if (status != null && status.isNotEmpty && status != 'all') {
      query += ' AND status = ?';
      variables.add(Variable.withString(status));
    }

    if (cursor != null && cursor.isNotEmpty) {
      final cursorTime = int.tryParse(cursor);
      if (cursorTime != null) {
        query += ' AND created_at < ?';
        variables.add(Variable.withInt(cursorTime));
      }
    }

    query += ' ORDER BY created_at DESC LIMIT ?';
    variables.add(Variable.withInt(limit.clamp(1, 100)));

    final rows = await _db.customSelect(query, variables: variables).get();
    return rows.map((r) => _mapRowToProposal(r.data)).toList();
  }

  /// Confirms a pending proposal and applies it into [repository].
  Future<Map<String, dynamic>> confirmProposal(
    String id,
    TodoRepository repository,
  ) async {
    await ensureInitialized();
    final proposal = await getProposal(id);
    if (proposal == null) {
      throw RepositoryException('Proposal "$id" not found.');
    }

    if (proposal.status != ProposalStatus.pending) {
      throw RepositoryException(
        'Proposal "$id" is already ${proposal.status.name}.',
      );
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (now > proposal.expiresAt) {
      await _db.customStatement(
        'UPDATE task_proposals SET status = ? WHERE id = ?',
        [ProposalStatus.expired.name, id],
      );
      throw RepositoryException('Proposal "$id" has expired.');
    }

    // Apply the proposal based on type
    Map<String, dynamic> resultData = {};
    if (proposal.type == 'create') {
      final task = await AiTaskExecutor.executeCreateTask(
        repository: repository,
        payload: proposal.payload,
      );
      resultData = {'taskId': task.id};
    } else if (proposal.type == 'update') {
      final task = await AiTaskExecutor.executeUpdateTask(
        repository: repository,
        payload: proposal.payload,
      );
      resultData = {'taskId': task.id};
    } else if (proposal.type == 'delete') {
      final rawIds = proposal.payload['taskIds'] as List?;
      final taskIds = rawIds?.map((e) => e.toString()).toList() ?? [];
      for (final tid in taskIds) {
        await repository.deleteTask(tid);
      }
      resultData = {'deletedTaskIds': taskIds};
    } else if (proposal.type == 'bulk_create') {
      final rawTasks = proposal.payload['tasks'] as List?;
      final createdIds = <String>[];
      if (rawTasks != null) {
        for (final item in rawTasks) {
          if (item is Map<String, dynamic>) {
            final t = await AiTaskExecutor.executeCreateTask(
              repository: repository,
              payload: item,
            );
            createdIds.add(t.id);
          }
        }
      }
      resultData = {'taskIds': createdIds};
    }

    await _db.customStatement(
      'UPDATE task_proposals SET status = ?, processed_at = ? WHERE id = ?',
      [ProposalStatus.confirmed.name, now, id],
    );

    return resultData;
  }

  /// Rejects a pending proposal.
  Future<void> rejectProposal(String id) async {
    await ensureInitialized();
    final proposal = await getProposal(id);
    if (proposal == null) {
      throw RepositoryException('Proposal "$id" not found.');
    }

    if (proposal.status != ProposalStatus.pending) {
      throw RepositoryException(
        'Proposal "$id" cannot be rejected because it is ${proposal.status.name}.',
      );
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.customStatement(
      'UPDATE task_proposals SET status = ?, processed_at = ? WHERE id = ?',
      [ProposalStatus.rejected.name, now, id],
    );
  }

  TaskProposal _mapRowToProposal(
    Map<String, dynamic> data, {
    bool isReplayed = false,
  }) {
    Map<String, dynamic> parsedPayload = {};
    try {
      final raw = data['payload'] as String?;
      if (raw != null && raw.isNotEmpty) {
        parsedPayload = jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}

    return TaskProposal(
      id: data['id'] as String,
      type: data['type'] as String,
      status: ProposalStatus.fromString(data['status'] as String),
      payload: parsedPayload,
      idempotencyKey: data['idempotency_key'] as String?,
      createdAt: data['created_at'] as int,
      expiresAt: data['expires_at'] as int,
      processedAt: data['processed_at'] as int?,
      isReplayed: isReplayed,
    );
  }
}
