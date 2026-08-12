// 同步引擎编排层（docs/60-sync-design.md §5/§6/§11/§12，docs/30-architecture §6.2）。
//
// 职责：
// - 触发统一入口 run()（串行防重入）+ runAfterEdit()（编辑防抖，可关）；
// - 读取配置（settings 非敏感项 + SecureStore 凭据）与设备 ID（首次生成持久化）；
// - 首次同步四分支（§5）：本地空+远端有 → 下载应用；本地有+远端空 → 上传；
//   都有 → 读改写（§6）；schemaVersion 不匹配 → 拒绝；
// - 时钟偏差检测（§11）：|remote.exportedAt - now| > 5min → 用户确认，否则中止；
// - 应用合并（§4/D1）：deleted=true → 本地硬删 + 墓碑保留进本地墓碑集合；
//   其余 → upsert；task_tags 按合并结果全量重建；
// - 上传优化（§10.3）：内容 hash 与上次上传一致则跳过 upload（仍记成功）；
// - 读改写（§6）：upload 前比对 lastModified，变化则重新 download+merge，最多 2 次；
// - 错误处理（§12）：分类 → SyncState.error + SyncResult（retryable 标注），
//   指数退避由触发层（sync_triggers.dart）调度；
// - 安全（§13）：日志不输出密钥/完整 URL（仅 host）。
//
// 分层约束（docs/30-architecture §1）：本类只依赖 Repository 与 RemoteStore
// 抽象，不依赖 UI；Repository 层不 import lib/core/sync/，双方经
// TodoRepository.exportAll()/applyMerged()/墓碑方法交换纯 DB 数据类型。

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import '../db/database.dart' show Project, Tag, Task;
import '../db/repositories/todo_repository.dart';
import '../db/tables.dart' show TaskPriority, TaskStatus;
import '../security/secure_store.dart';
import '../utils/uuid.dart';
import 'content_hash.dart';
import 'merge_engine.dart';
import 'remote_store.dart';
import 'remote_store_factory.dart';
import 'snapshot.dart';
import 'snapshot_codec.dart';
import 'sync_config.dart';
import 'sync_exceptions.dart';

/// 同步状态机（docs/30-architecture §3：SyncState Notifier 暴露）。
enum SyncStateStatus { idle, syncing, success, error }

/// 同步错误码（结构化错误分类，docs/60-sync-design.md §12）。
///
/// UI 依据 errorCode 映射 ARB 文案；引擎/异常层**不得 import l10n**
/// （docs/30-architecture §1 分层），故用错误码而非本地化字符串传递错误。
enum SyncErrorCode {
  /// 防重入：同步进行中，本次触发已跳过（非错误）。
  skippedRunning,

  /// 时钟偏差被拒（§11）。
  clockSkew,

  /// 认证失败（401，凭据错误）。
  auth,

  /// 网络失败/超时。
  network,

  /// 远端其他 HTTP 错误。
  remote,

  /// 本地同步配置无效。
  config,

  /// 远端 schemaVersion 不兼容。
  schemaMismatch,

  /// 远端快照损坏/解析失败。
  snapshotCorrupt,

  /// 未预期异常（兜底）。
  unknown,
}

/// 同步状态（不可变，UI/Provider 订阅 onStateChanged）。
class SyncState {
  const SyncState({
    required this.status,
    this.lastSyncedAt,
    this.errorMessage,
    this.errorCode,
  });

  static const SyncState idle = SyncState(status: SyncStateStatus.idle);

  final SyncStateStatus status;

  /// 上次成功同步时间（UTC 毫秒）。
  final int? lastSyncedAt;

  /// 错误描述（**仅供日志/调试，UI 不得直接展示**；不包含密钥/完整 URL，
  /// UI 展示请用 [errorCode] 映射 ARB 文案）。
  final String? errorMessage;

  /// 结构化错误码（UI 据此映射 ARB 文案；null = 非错误态）。
  final SyncErrorCode? errorCode;
}

/// 同步结果（SyncEngine.run() 返回值）。
class SyncResult {
  const SyncResult({
    required this.ok,
    this.skipped = false,
    this.retryable = false,
    this.message,
    this.errorCode,
  });

  /// 是否成功完成（含「内容无变化跳过上传」）。
  final bool ok;

  /// 是否被跳过（未启用 / 无凭据 / 防重入，非错误）。
  final bool skipped;

  /// 失败是否可重试（网络/远端其他错误 true；认证/配置/schema 错误 false）。
  final bool retryable;

  /// 错误描述（**仅供日志/调试，UI 不得直接展示**；UI 展示请用
  /// [errorCode] 映射 ARB 文案）。
  final String? message;

  /// 结构化错误码（UI 据此映射 ARB 文案；null = 成功/跳过非错误路径）。
  final SyncErrorCode? errorCode;
}

/// 时钟偏差检测容差（§11：5 分钟）。
const int _kClockSkewToleranceMs = 5 * 60 * 1000;

/// 墓碑保留期（§8：>90 天清理，仅影响墓碑集合）。
const int _kTombstoneRetentionMs = 90 * 24 * 60 * 60 * 1000;

/// 读改写最大重试次数（§6：最多重试 2 次）。
const int _kMaxReadModifyWriteRetries = 2;

/// 时钟偏差被拒（中止本次同步，不 merge 不写库）。
class _ClockSkewRejected implements Exception {
  const _ClockSkewRejected();
}

/// 墓碑条目类型（与 todo_repository.dart 私有常量及快照层约定一致）。
const String _kTombstoneTypeProject = 'project';
const String _kTombstoneTypeTask = 'task';
const String _kTombstoneTypeTag = 'tag';

/// 同步引擎（docs/30-architecture §2 `core/sync/sync_engine.dart`）。
class SyncEngine {
  SyncEngine({
    required TodoRepository repository,
    required SecureStore secureStore,
    required RemoteStoreFactory remoteStoreFactory,
    Future<bool> Function()? confirmClockSkew,
    void Function(SyncState)? onStateChanged,
    DateTime Function()? now,
  }) : _repository = repository,
       _secureStore = secureStore,
       _remoteStoreFactory = remoteStoreFactory,
       _confirmClockSkew = confirmClockSkew,
       _onStateChanged = onStateChanged,
       _now = now ?? DateTime.now;

  final TodoRepository _repository;
  final SecureStore _secureStore;
  final RemoteStoreFactory _remoteStoreFactory;

  /// 时钟偏差确认回调；null 表示 UI 未提供 → 直接拒绝（§11）。
  final Future<bool> Function()? _confirmClockSkew;

  /// 状态回调（UI/Provider 订阅）。
  final void Function(SyncState)? _onStateChanged;

  /// 可注入时钟（测试用稳定时钟；生产用 DateTime.now）。
  final DateTime Function() _now;

  SyncState _state = SyncState.idle;

  /// 当前同步状态。
  SyncState get state => _state;

  bool _running = false;

  Timer? _editDebounceTimer;
  Completer<void>? _pendingEdit;

  /// 编辑防抖时长（§10.2：2s）。
  static const Duration editDebounce = Duration(seconds: 2);

  // ─────────────────────────── 触发入口 ───────────────────────────

  /// 手动/触发统一入口（§6 串行队列）。
  ///
  /// **防重入选择（D3 决策）**：重入时**直接返回**（不等待、不排队）。
  /// 理由：编辑防抖与指数退避已在触发层合并多次调用；等待/排队会引入
  /// 无界延迟与状态叠加的复杂度，直接返回更简单可预期。被丢弃的编辑
  /// 会在下一次触发（手动/编辑/启动）时自然补上。
  Future<SyncResult> run() async {
    if (_running) {
      return const SyncResult(
        ok: false,
        skipped: true,
        errorCode: SyncErrorCode.skippedRunning,
        message: '同步进行中，本次触发已跳过',
      );
    }
    _running = true;
    _setState(const SyncState(status: SyncStateStatus.syncing));
    try {
      return await _run();
    } finally {
      _running = false;
    }
  }

  /// 编辑防抖入口（§10.2：内部 debounce 2s + autoOnEdit 可关判断）。
  ///
  /// 多次调用合并为一次（Timer 取消重建，旧调用的 Future 立即完成，避免
  /// 调用方挂起）；触发时读取配置，autoOnEdit 关闭或同步未启用则静默跳过。
  Future<void> runAfterEdit() {
    _editDebounceTimer?.cancel();
    _pendingEdit?.complete();
    final completer = Completer<void>();
    _pendingEdit = completer;
    _editDebounceTimer = Timer(editDebounce, () async {
      try {
        final config = await loadSettingsConfig();
        if (config.enabled && config.autoOnEdit) {
          await run();
        }
      } finally {
        if (identical(_pendingEdit, completer)) _pendingEdit = null;
        if (!completer.isCompleted) completer.complete();
      }
    });
    return completer.future;
  }

  /// 读取完整同步配置（settings 非敏感项 + SecureStore 凭据）。
  ///
  /// 凭据缺失时仅返回非敏感项（hasCredentials=false，run() 将跳过）。
  Future<SyncConfig> loadConfig() async {
    final config = await loadSettingsConfig();
    final creds = await _secureStore.readCreds(config.type);
    if (creds == null) return config;
    return config.copyWith(
      serverUrl: creds.serverUrl,
      username: creds.username,
      secret: creds.secret,
      bucket: creds.bucket,
      region: creds.region,
      prefix: creds.prefix,
    );
  }

  /// 读取非敏感同步配置（仅 settings 表，不读安全存储）。
  ///
  /// 供触发层（sync_triggers.dart）判断 autoOnStart/autoOnEdit/wifiOnly 等
  /// 开关，避免每次编辑触发都读安全存储（§13 凭据只在真正同步时读取）。
  Future<SyncConfig> loadSettingsConfig() async {
    return SyncConfig.fromMap(await _repository.settings.getAll());
  }

  // ─────────────────────────── 核心流程 ───────────────────────────

  Future<SyncResult> _run() async {
    try {
      final config = await loadConfig();
      if (!config.enabled || !config.hasCredentials) {
        _setState(SyncState.idle);
        return const SyncResult(ok: false, skipped: true);
      }

      final deviceId = await _ensureDeviceId();
      final store = _remoteStoreFactory.create(config);
      final nowMs = _now().toUtc().millisecondsSinceEpoch;

      // §8 墓碑清理：>90 天的墓碑从集合移除（快照压缩语义，可选后台任务）。
      await _repository.pruneTombstones(nowMs - _kTombstoneRetentionMs);

      final remoteExists = await store.exists();
      final data = await _repository.exportAll();
      final tombstones = await _repository.readTombstones();
      final localEmpty =
          data.projects.isEmpty &&
          data.tasks.isEmpty &&
          data.tags.isEmpty &&
          tombstones.isEmpty;

      if (!remoteExists) {
        // 分支 B（§5）：本地有 + 远端空 → 上传（两端都空也走此路径，
        // 上传空快照无害）；或竞态下远端被删，退化为上传。
        final payload = encodeSnapshot(
          _buildExportSnapshot(data, tombstones, deviceId),
        );
        await _uploadIfChanged(store, payload);
        return await _finishSuccess();
      }

      if (localEmpty) {
        // 分支 A（§5）：本地空 + 远端有 → 下载 → 校验（schema/时钟）→ 应用。
        // 本地无贡献，不上传。
        final bytes = await store.download();
        if (bytes == null) {
          // 竞态：远端刚被删且本地空 → 无事可做，仍记成功。
          return await _finishSuccess();
        }
        final remote = await _decodeAndVerify(bytes);
        final merged = merge(
          SnapshotData(
            schemaVersion: kSnapshotSchemaVersion,
            deviceId: deviceId,
            exportedAt: nowMs,
          ),
          remote,
          localDeviceId: deviceId,
          remoteDeviceId: remote.deviceId,
        );
        await _applyMerged(merged);
        return await _finishSuccess();
      }

      // 分支 C（§5/§6）：都有 → 读改写（download → merge → apply →
      // 重新导出 → upload，upload 前比对 lastModified，变化则重试 ≤2 次）。
      await _syncReadModifyWrite(store, deviceId);
      return await _finishSuccess();
    } on _ClockSkewRejected {
      // §11：时钟偏差被拒 → 中止本次同步（不 merge 不写库），错误态。
      const message = '时钟偏差，请校准后重试'; // 仅日志，UI 用 errorCode 映射。
      _setState(
        const SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.clockSkew,
          errorMessage: message,
        ),
      );
      return const SyncResult(
        ok: false,
        retryable: false,
        errorCode: SyncErrorCode.clockSkew,
        message: message,
      );
    } on SyncAuthException catch (e) {
      // §12：认证失败 → 提示检查凭据，不重试。
      _setState(
        SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.auth,
          errorMessage: e.message,
        ),
      );
      return SyncResult(
        ok: false,
        retryable: false,
        errorCode: SyncErrorCode.auth,
        message: e.message,
      );
    } on SyncNetworkException catch (e) {
      // §12：网络失败/超时 → 可重试（指数退避由触发层调度）。
      _setState(
        SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.network,
          errorMessage: e.message,
        ),
      );
      return SyncResult(
        ok: false,
        retryable: true,
        errorCode: SyncErrorCode.network,
        message: e.message,
      );
    } on SyncRemoteException catch (e) {
      // §12：远端其他 HTTP 错误 → 展示错误，可重试。
      _setState(
        SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.remote,
          errorMessage: e.message,
        ),
      );
      return SyncResult(
        ok: false,
        retryable: true,
        errorCode: SyncErrorCode.remote,
        message: e.message,
      );
    } on SyncConfigException catch (e) {
      // 本地配置无效 → 提示修正配置，不重试。
      _setState(
        SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.config,
          errorMessage: e.message,
        ),
      );
      return SyncResult(
        ok: false,
        retryable: false,
        errorCode: SyncErrorCode.config,
        message: e.message,
      );
    } on SnapshotSchemaException {
      // §5/§12：schemaVersion 不匹配 → 拒绝同步并警告「请升级应用」，
      // 不覆盖远端、不破坏本地。
      const message = '远端数据版本不兼容，请升级应用'; // 仅日志。
      _setState(
        const SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.schemaMismatch,
          errorMessage: message,
        ),
      );
      return const SyncResult(
        ok: false,
        retryable: false,
        errorCode: SyncErrorCode.schemaMismatch,
        message: message,
      );
    } on FormatException {
      // §12：快照损坏/解析失败 → 保留远端原文件、不覆盖，报错可重试。
      const message = '远端数据异常'; // 仅日志。
      _setState(
        const SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.snapshotCorrupt,
          errorMessage: message,
        ),
      );
      return const SyncResult(
        ok: false,
        retryable: true,
        errorCode: SyncErrorCode.snapshotCorrupt,
        message: message,
      );
    } catch (e) {
      // 兜底：未预期异常 → 不破坏本地库，不重试（避免死循环）。
      debugPrint('sync: 未预期异常 ${e.runtimeType}');
      const message = '同步失败'; // 仅日志。
      _setState(
        const SyncState(
          status: SyncStateStatus.error,
          errorCode: SyncErrorCode.unknown,
          errorMessage: message,
        ),
      );
      return const SyncResult(
        ok: false,
        retryable: false,
        errorCode: SyncErrorCode.unknown,
        message: message,
      );
    }
  }

  /// 分支 C 读改写（§6）。
  Future<void> _syncReadModifyWrite(RemoteStore store, String deviceId) async {
    var lastModifiedBefore = await store.lastModified();
    for (var attempt = 0; ; attempt++) {
      final bytes = await store.download();
      if (bytes == null) {
        // 竞态：远端被删除 → 退化为上传本地快照。
        final data = await _repository.exportAll();
        final toms = await _repository.readTombstones();
        final payload = encodeSnapshot(
          _buildExportSnapshot(data, toms, deviceId),
        );
        await _uploadIfChanged(store, payload);
        return;
      }

      final remote = await _decodeAndVerify(bytes);
      final localData = await _repository.exportAll();
      final localToms = await _repository.readTombstones();
      final local = _buildExportSnapshot(localData, localToms, deviceId);
      final merged = merge(
        local,
        remote,
        localDeviceId: deviceId,
        remoteDeviceId: remote.deviceId,
      );
      await _applyMerged(merged);

      // 应用后重新导出（含更新后的墓碑集合），并编码为待上传 payload。
      final data = await _repository.exportAll();
      final toms = await _repository.readTombstones();
      final payload = encodeSnapshot(
        _buildExportSnapshot(data, toms, deviceId),
      );

      if (attempt >= _kMaxReadModifyWriteRetries) {
        // 已重试 2 次仍被修改 → 接受最后读取结果上传（§6 上限）。
        await _uploadIfChanged(store, payload);
        return;
      }
      final lmNow = await store.lastModified();
      if (lmNow == lastModifiedBefore) {
        await _uploadIfChanged(store, payload);
        return;
      }
      // 远端被其他设备修改 → 重新 download + merge 再上传（§6）。
      lastModifiedBefore = lmNow;
    }
  }

  /// 应用合并结果：deleted=true → 硬删 + 墓碑保留进本地集合；其余 → upsert
  /// （D1/D3-6）。task_tags 按合并结果的 tagIds 全量重建（applyMerged 内事务）。
  Future<void> _applyMerged(SnapshotData merged) async {
    final ops = _opsFromMerged(merged);
    await _repository.applyMerged(ops);
    // merge 结果中的墓碑必须保留（要传播给远端），不清理（D1）。
    await _repository.mergeTombstones(_tombstonesFromMerged(merged));
  }

  /// 解码远端快照 + 时钟偏差检测（§11）。
  ///
  /// - schemaVersion 不匹配 / gzip 损坏 / 非法 JSON → 抛
  ///   [SnapshotSchemaException] / [FormatException]（外层按 §12 处理，
  ///   不覆盖远端）；
  /// - 时钟偏差 >5min → 调 confirmClockSkew()；false/null → 抛
  ///   [_ClockSkewRejected] 中止（不 merge 不写库）。
  Future<SnapshotData> _decodeAndVerify(Uint8List bytes) async {
    final remote = decodeSnapshot(bytes);
    final nowMs = _now().toUtc().millisecondsSinceEpoch;
    if ((remote.exportedAt - nowMs).abs() > _kClockSkewToleranceMs) {
      final confirmed = _confirmClockSkew != null && await _confirmClockSkew();
      if (!confirmed) {
        debugPrint('sync: 时钟偏差被拒（远端 exportedAt=${remote.exportedAt}）');
        throw const _ClockSkewRejected();
      }
    }
    return remote;
  }

  /// 上传优化（§10.3）：payload 内容 hash 与 remoteStore.contentHash()
  /// （本进程内最近一次成功上传）一致 → 跳过 upload（仍记成功）。
  Future<void> _uploadIfChanged(RemoteStore store, Uint8List payload) async {
    final hash = fnv1a64Hex(payload);
    final remoteHash = await store.contentHash();
    if (remoteHash != null && remoteHash == hash) {
      debugPrint('sync: 内容无变化，跳过上传');
      return;
    }
    await store.upload(payload);
  }

  /// 成功收尾：写 lastSyncedAt → onStateChanged(success)。
  Future<SyncResult> _finishSuccess() async {
    final nowMs = _now().toUtc().millisecondsSinceEpoch;
    await _repository.settings.set(SyncSettingsKeys.lastSyncedAt, '$nowMs');
    _setState(SyncState(status: SyncStateStatus.success, lastSyncedAt: nowMs));
    return const SyncResult(ok: true);
  }

  // ─────────────────────────── 快照组装/转换 ───────────────────────────

  /// 从 DB 活跃行 + 墓碑集合组装导出快照（D1/D2）。
  ///
  /// - 墓碑条目转成对应类型 `XxxRecord(deleted: true)`（其余字段空/默认值，
  ///   updatedAt 用条目 updatedAt），并入 records 列表；
  /// - 墓碑的 id 若与某活跃行相同（如收件箱重建），该墓碑已过时（活跃行
  ///   updatedAt 更新），跳过并入，避免同 id 同时在快照中出现两份；
  /// - >90 天的墓碑已在 run() 开头 prune。
  SnapshotData _buildExportSnapshot(
    RepositoryExportData data,
    List<TombstoneEntry> tombstones,
    String deviceId,
  ) {
    final nowMs = _now().toUtc().millisecondsSinceEpoch;
    final projects = <ProjectRecord>[
      for (final p in data.projects)
        ProjectRecord(
          id: p.id,
          name: p.name,
          color: p.color,
          description: p.description,
          sortOrder: p.sortOrder,
          createdAt: p.createdAt,
          updatedAt: p.updatedAt,
          deleted: false,
        ),
    ];
    final tasks = <TaskRecord>[
      for (final t in data.tasks)
        TaskRecord(
          id: t.id,
          projectId: t.projectId,
          parentId: t.parentId,
          title: t.title,
          description: t.description,
          notes: t.notes,
          startAt: t.startAt,
          endAt: t.endAt,
          status: t.status.index,
          priority: t.priority.index,
          sortOrder: t.sortOrder,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
          deleted: false,
          tagIds: data.taskTagIds[t.id] ?? const [],
        ),
    ];
    final tags = <TagRecord>[
      for (final t in data.tags)
        TagRecord(
          id: t.id,
          name: t.name,
          color: t.color,
          sortOrder: t.sortOrder,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
          deleted: false,
        ),
    ];

    final aliveProjectIds = {for (final p in projects) p.id};
    final aliveTaskIds = {for (final t in tasks) t.id};
    final aliveTagIds = {for (final t in tags) t.id};
    for (final tomb in tombstones) {
      switch (tomb.type) {
        case _kTombstoneTypeProject:
          if (aliveProjectIds.contains(tomb.id)) continue;
          projects.add(
            ProjectRecord(
              id: tomb.id,
              name: '',
              color: 0,
              sortOrder: 0,
              createdAt: tomb.updatedAt,
              updatedAt: tomb.updatedAt,
              deleted: true,
            ),
          );
        case _kTombstoneTypeTask:
          if (aliveTaskIds.contains(tomb.id)) continue;
          tasks.add(
            TaskRecord(
              id: tomb.id,
              projectId: '',
              title: '',
              sortOrder: 0,
              createdAt: tomb.updatedAt,
              updatedAt: tomb.updatedAt,
              deleted: true,
            ),
          );
        case _kTombstoneTypeTag:
          if (aliveTagIds.contains(tomb.id)) continue;
          tags.add(
            TagRecord(
              id: tomb.id,
              name: '',
              color: 0,
              sortOrder: 0,
              createdAt: tomb.updatedAt,
              updatedAt: tomb.updatedAt,
              deleted: true,
            ),
          );
      }
    }

    return SnapshotData(
      schemaVersion: kSnapshotSchemaVersion,
      deviceId: deviceId,
      exportedAt: nowMs,
      projects: projects,
      tasks: tasks,
      tags: tags,
    );
  }

  /// 合并结果 → MergedApplyOperation（deleted → hardDelete；其余 → upsert）。
  MergedApplyOperation _opsFromMerged(SnapshotData merged) {
    final upsertProjects = <Project>[];
    final upsertTasks = <Task>[];
    final upsertTags = <Tag>[];
    final hardDeleteProjectIds = <String>[];
    final hardDeleteTaskIds = <String>[];
    final hardDeleteTagIds = <String>[];
    final taskTagLinks = <String, List<String>>{};
    for (final p in merged.projects) {
      if (p.deleted) {
        hardDeleteProjectIds.add(p.id);
      } else {
        upsertProjects.add(_projectFromRecord(p));
      }
    }
    for (final t in merged.tasks) {
      if (t.deleted) {
        hardDeleteTaskIds.add(t.id);
      } else {
        upsertTasks.add(_taskFromRecord(t));
        taskTagLinks[t.id] = t.tagIds;
      }
    }
    for (final t in merged.tags) {
      if (t.deleted) {
        hardDeleteTagIds.add(t.id);
      } else {
        upsertTags.add(_tagFromRecord(t));
      }
    }
    return MergedApplyOperation(
      upsertProjects: upsertProjects,
      upsertTasks: upsertTasks,
      upsertTags: upsertTags,
      hardDeleteProjectIds: hardDeleteProjectIds,
      hardDeleteTaskIds: hardDeleteTaskIds,
      hardDeleteTagIds: hardDeleteTagIds,
      taskTagLinks: taskTagLinks,
    );
  }

  /// 合并结果中 deleted=true 的记录 → 墓碑条目（保留进本地墓碑集合，D1）。
  List<TombstoneEntry> _tombstonesFromMerged(SnapshotData merged) => [
    for (final p in merged.projects)
      if (p.deleted)
        TombstoneEntry(
          type: _kTombstoneTypeProject,
          id: p.id,
          updatedAt: p.updatedAt,
        ),
    for (final t in merged.tasks)
      if (t.deleted)
        TombstoneEntry(
          type: _kTombstoneTypeTask,
          id: t.id,
          updatedAt: t.updatedAt,
        ),
    for (final t in merged.tags)
      if (t.deleted)
        TombstoneEntry(
          type: _kTombstoneTypeTag,
          id: t.id,
          updatedAt: t.updatedAt,
        ),
  ];

  Project _projectFromRecord(ProjectRecord r) => Project(
    id: r.id,
    name: r.name,
    color: r.color,
    description: r.description,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deleted: 0,
  );

  Task _taskFromRecord(TaskRecord r) => Task(
    id: r.id,
    projectId: r.projectId,
    parentId: r.parentId,
    title: r.title,
    description: r.description,
    notes: r.notes,
    startAt: r.startAt,
    endAt: r.endAt,
    status: _taskStatusFromIndex(r.status),
    priority: _taskPriorityFromIndex(r.priority),
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deleted: 0,
  );

  Tag _tagFromRecord(TagRecord r) => Tag(
    id: r.id,
    name: r.name,
    color: r.color,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    deleted: 0,
  );

  /// 快照 status 枚举 index（0–3）→ DB 枚举（越界回退 todo，与 converter 一致）。
  TaskStatus _taskStatusFromIndex(int v) {
    if (v < 0 || v >= TaskStatus.values.length) return TaskStatus.todo;
    return TaskStatus.values[v];
  }

  /// 快照 priority 枚举 index（0–3）→ DB 枚举（越界回退 none，与 converter 一致）。
  TaskPriority _taskPriorityFromIndex(int v) {
    if (v < 0 || v >= TaskPriority.values.length) return TaskPriority.none;
    return TaskPriority.values[v];
  }

  // ─────────────────────────── 基础设施 ───────────────────────────

  /// 设备 ID：settings `sync_device_id`，首次生成 UUID v4 并持久化（§5）。
  Future<String> _ensureDeviceId() async {
    final existing = await _repository.settings.get(SyncSettingsKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = newUuid();
    await _repository.settings.set(SyncSettingsKeys.deviceId, id);
    return id;
  }

  void _setState(SyncState state) {
    _state = state;
    _onStateChanged?.call(state);
  }

  /// 释放内部 Timer（应用生命周期内可调用；编辑防抖入口终止）。
  void dispose() {
    _editDebounceTimer?.cancel();
    _editDebounceTimer = null;
    _pendingEdit?.complete();
    _pendingEdit = null;
  }
}
