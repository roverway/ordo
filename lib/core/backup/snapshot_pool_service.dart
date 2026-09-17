import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';
import 'package:todo/core/db/daos/settings_dao.dart';

import 'backup_restore_service.dart';

/// 快照触发来源。
enum SnapshotTriggerType {
  /// 每日首次自动保护快照
  dailyAuto('daily', '每日自动快照'),

  /// 同步前自动快照（防网络覆盖/冲突）
  preSync('presync', '同步前快照'),

  /// 导入/还原前保护快照（防误操作覆盖）
  preRestore('prerestore', '还原前快照'),

  /// 用户在快照管理中心手动创建
  manual('manual', '手动创建快照');

  const SnapshotTriggerType(this.code, this.label);
  final String code;
  final String label;

  static SnapshotTriggerType fromCode(String code) {
    for (final type in SnapshotTriggerType.values) {
      if (type.code == code) return type;
    }
    return SnapshotTriggerType.manual;
  }
}

/// 本地快照元数据条目。
class LocalSnapshotInfo {
  const LocalSnapshotInfo({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.triggerType,
    required this.sizeBytes,
    required this.taskCount,
    required this.projectCount,
    required this.tagCount,
    required this.folderCount,
    required this.customViewCount,
  });

  /// 快照文件完整绝对路径。
  final String filePath;

  /// 文件名，例如 `snap_20260910_143000_presync.ordobak`。
  final String fileName;

  /// 快照生成时间。
  final DateTime createdAt;

  /// 触发类型。
  final SnapshotTriggerType triggerType;

  /// 文件字节大小。
  final int sizeBytes;

  final int taskCount;
  final int projectCount;
  final int tagCount;
  final int folderCount;
  final int customViewCount;
}

/// 默认快照保留天数（7 天）。
const int kDefaultBackupRetentionDays = 7;

/// 快照保留天数在 settings 表中的 key。
const String kSettingBackupRetentionDays = 'backup_retention_days';

/// 本地快照池管理服务。
class SnapshotPoolService {
  SnapshotPoolService({
    required BackupRestoreService backupService,
    required SettingsDao settings,
    Future<Directory> Function()? getDirectory,
    Future<void> Function(int days)? onRetentionDaysChanged,
  }) : _backupService = backupService,
       _settings = settings,
       _getDirectory = getDirectory ?? _defaultDirectoryGetter,
       _onRetentionDaysChanged = onRetentionDaysChanged;

  final BackupRestoreService _backupService;
  final SettingsDao _settings;
  final Future<Directory> Function() _getDirectory;
  final Future<void> Function(int days)? _onRetentionDaysChanged;

  /// 缓存本地快照元数据，避免列表遍历时反复进行文件读取、Gzip 解压缩与 JSON 反序列化。
  final Map<String, ({int size, int modifiedMs, LocalSnapshotInfo info})>
  _snapshotCache = {};

  static Future<Directory> _defaultDirectoryGetter() async {
    final supportDir = await getApplicationSupportDirectory();
    final snapshotDir = Directory('${supportDir.path}/ordo_snapshots');
    if (!await snapshotDir.exists()) {
      await snapshotDir.create(recursive: true);
    }
    return snapshotDir;
  }

  static String formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$h$min$s';
  }

  static DateTime? parseTimestamp(String dateStr, String timeStr) {
    if (dateStr.length != 8 || timeStr.length != 6) return null;
    final iso =
        '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}T'
        '${timeStr.substring(0, 2)}:${timeStr.substring(2, 4)}:${timeStr.substring(4, 6)}';
    return DateTime.tryParse(iso);
  }

  /// 获取用户配置的快照保留天数。
  Future<int> getRetentionDays() async {
    final str = await _settings.get(kSettingBackupRetentionDays);
    if (str == null) return kDefaultBackupRetentionDays;
    return int.tryParse(str) ?? kDefaultBackupRetentionDays;
  }

  /// 设置快照保留天数。
  Future<void> setRetentionDays(int days) async {
    await _settings.set(kSettingBackupRetentionDays, days.toString());
    await _onRetentionDaysChanged?.call(days);
  }

  /// 生成一份新的本地快照并落盘，随后触发自动轮询清理过期快照。
  Future<LocalSnapshotInfo> createSnapshot({
    required SnapshotTriggerType trigger,
  }) async {
    final dir = await _getDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final bytes = await _backupService.exportToBytes();
    final summary = _backupService.inspectBackup(bytes);
    final now = DateTime.now();
    final timeStr = formatTimestamp(now);
    final fileName = 'snap_${timeStr}_${trigger.code}.ordobak';
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // 触发轮转清理（后台异步执行，不阻塞快照创建返回）
    unawaited(pruneExpiredSnapshots());

    final info = LocalSnapshotInfo(
      filePath: filePath,
      fileName: fileName,
      createdAt: now,
      triggerType: trigger,
      sizeBytes: bytes.length,
      taskCount: summary.taskCount,
      projectCount: summary.projectCount,
      tagCount: summary.tagCount,
      folderCount: summary.folderCount,
      customViewCount: summary.customViewCount,
    );

    _snapshotCache[filePath] = (
      size: bytes.length,
      modifiedMs: now.millisecondsSinceEpoch,
      info: info,
    );

    return info;
  }

  /// 检索当前快照池内所有有效快照，按时间倒序排列（最新在最前）。
  Future<List<LocalSnapshotInfo>> listSnapshots() async {
    final dir = await _getDirectory();
    if (!await dir.exists()) {
      return const [];
    }

    final entities = await dir.list().toList();
    final result = <LocalSnapshotInfo>[];

    for (final entity in entities) {
      if (entity is! File) continue;
      final fileName = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!fileName.startsWith('snap_') || !fileName.endsWith('.ordobak')) {
        continue;
      }

      // 提取 snap_YYYYMMDD_HHMMSS_trigger.ordobak
      final parts = fileName.replaceFirst('.ordobak', '').split('_');
      if (parts.length < 4) continue;
      final dateStr = parts[1];
      final timeStr = parts[2];
      final triggerCode = parts[3];

      final dt =
          parseTimestamp(dateStr, timeStr) ?? await entity.lastModified();
      final trigger = SnapshotTriggerType.fromCode(triggerCode);

      try {
        final stat = await entity.stat();
        final cached = _snapshotCache[entity.path];
        if (cached != null &&
            cached.size == stat.size &&
            cached.modifiedMs == stat.modified.millisecondsSinceEpoch) {
          result.add(cached.info);
          continue;
        }

        final bytes = await entity.readAsBytes();
        final summary = _backupService.inspectBackup(bytes);
        final info = LocalSnapshotInfo(
          filePath: entity.path,
          fileName: fileName,
          createdAt: dt,
          triggerType: trigger,
          sizeBytes: bytes.length,
          taskCount: summary.taskCount,
          projectCount: summary.projectCount,
          tagCount: summary.tagCount,
          folderCount: summary.folderCount,
          customViewCount: summary.customViewCount,
        );

        _snapshotCache[entity.path] = (
          size: stat.size,
          modifiedMs: stat.modified.millisecondsSinceEpoch,
          info: info,
        );

        result.add(info);
      } catch (_) {
        // 若损坏或非标准文件则跳过
        continue;
      }
    }

    // 按创建时间倒序排（最新的排在最前面）
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// 删除指定快照。
  Future<void> deleteSnapshot(String filePath) async {
    _snapshotCache.remove(filePath);
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 清理过期快照（轻量高效实现：零 I/O 读取文件内容，零 CPU 解压反序列化）。
  ///
  /// 保留策略：
  /// - 遍历所有有效快照文件实体；
  /// - 距离当前时间超过 `retentionDays` 的快照标记为待删除；
  /// - **终极保底防空**：如果删除会导致快照池被彻底清空，始终强行保留最新的 1 份快照。
  Future<int> pruneExpiredSnapshots() async {
    try {
      final dir = await _getDirectory();
      if (!await dir.exists()) return 0;

      final entities = await dir.list().toList();
      final validFiles = <({File file, DateTime createdAt})>[];

      for (final entity in entities) {
        if (entity is! File) continue;
        final fileName = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (!fileName.startsWith('snap_') || !fileName.endsWith('.ordobak')) {
          continue;
        }

        final parts = fileName.replaceFirst('.ordobak', '').split('_');
        if (parts.length < 4) continue;
        final dateStr = parts[1];
        final timeStr = parts[2];

        final dt =
            parseTimestamp(dateStr, timeStr) ?? await entity.lastModified();
        validFiles.add((file: entity, createdAt: dt));
      }

      if (validFiles.isEmpty) return 0;

      // 按时间降序排列，第 0 项是最新的一份
      validFiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final days = await getRetentionDays();
      final cutoff = DateTime.now().subtract(Duration(days: days));

      var deletedCount = 0;
      // 保底策略：第 0 项（最新的一份）绝对保留，从索引 1 开始检查过期
      for (var i = 1; i < validFiles.length; i++) {
        final item = validFiles[i];
        if (item.createdAt.isBefore(cutoff)) {
          try {
            _snapshotCache.remove(item.file.path);
            await item.file.delete();
            deletedCount++;
          } catch (_) {}
        }
      }

      return deletedCount;
    } catch (e) {
      debugPrint('SnapshotPoolService: pruneExpiredSnapshots failed: $e');
      return 0;
    }
  }

  /// 从快照中还原数据。
  ///
  /// 在还原之前，会自动为当前正在运行的数据生成一份 `SnapshotTriggerType.preRestore`
  /// 保护快照，确保任何还原失误均可二次撤回。
  Future<void> restoreFromSnapshot(
    String snapshotFilePath, {
    required ImportMode mode,
  }) async {
    final file = File(snapshotFilePath);
    if (!await file.exists()) {
      throw FileNotFoundException(snapshotFilePath);
    }

    final bytes = await file.readAsBytes();
    await _backupService.importBackup(
      bytes,
      mode: mode,
      onBeforeRestore: () async {
        try {
          await createSnapshot(trigger: SnapshotTriggerType.preRestore);
        } catch (_) {
          // 若当前本地没有任何数据或快照失败，不中断还原
        }
      },
    );
  }
}

class FileNotFoundException implements Exception {
  const FileNotFoundException(this.path);
  final String path;

  @override
  String toString() => 'FileNotFoundException: 快照文件不存在: $path';
}
