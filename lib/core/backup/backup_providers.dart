import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/db_providers.dart';
import 'backup_restore_service.dart';
import 'snapshot_pool_service.dart';

/// 数据导入导出与灾难恢复服务 Provider。
final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return BackupRestoreService(repo);
});

/// 本地安全快照池管理服务 Provider。
final snapshotPoolServiceProvider = Provider<SnapshotPoolService>((ref) {
  final backupService = ref.watch(backupRestoreServiceProvider);
  final repo = ref.watch(todoRepositoryProvider);
  return SnapshotPoolService(
    backupService: backupService,
    settings: repo.settings,
  );
});
