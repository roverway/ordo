# 全量架构与代码复核报告：数据导入导出与本地安全快照 (Commit: `75d1539`)

- **审查对象**: Commit `75d1539d3243788fd3f798aea9069a23b829826f` (`feat(backup): 支持数据导入导出与本地安全快照功能`)
- **审查基准**: 顶级系统架构设计、数据一致性保障、离线优先原则、DRY 与解耦、健壮性与异常边界、无过度设计。
- **报告生成路径**: `docs/89-code-review-backup-and-snapshot.md`
- **状态**: 全量审查完成，6 项缺陷全部完成改进并通过二次严格复核验收

---

## 阶段一：全局变更地图（盘点目标）

### 1. 变更意图深度解析
本次提交引入了客户端级完整的数据安全与备份能力，核心价值包括：
1. **`.ordobak` 二进制容器格式**：基于 4 字节魔数（`ORDO` / `0x4F52444F`）+ 2 字节版本号（Big-Endian uint16）+ Gzip 压缩的 JSON 快照负载。
2. **导入与恢复双模式策略**：
   - `ImportMode.replace`：逆序清空级联外键关联表并重建数据，重置墓碑缓存。
   - `ImportMode.merge`：复用合并引擎基于 Last-Write-Wins (LWW) 对比 `updatedAt` 时间戳进行无损合并。
3. **本地安全快照池 (`SnapshotPoolService`)**：
   - 触发源：`preSync`（同步前置）、`preRestore`（还原前置）、`dailyAuto`、`manual`。
   - 滚动淘汰：根据设定的保留天数自动淘汰过期快照，同时保留最新 1 份作为极端防空保底。
4. **UI 深度融合**：在设置页提供数据导出、导入预检确认弹窗、以及快照历史管理抽屉。

### 2. 发生实质性变动的业务模块清单与任务队列

| 序号 | 业务模块名称 | 核心文件路径 | 关键职责 |
|---|---|---|---|
| **M1** | 核心二进制编解码协议 | `lib/core/backup/backup_codec.dart` | 魔数校验、版本约束、Gzip 压缩/解压与负载桥接 |
| **M2** | 导入导出与灾难恢复服务 | `lib/core/backup/backup_restore_service.dart` | 数据库全量导出、反序列化预检、事务内覆盖恢复、增量 LWW 转换 |
| **M3** | 安全快照池服务与淘汰引擎 | `lib/core/backup/snapshot_pool_service.dart` | 磁盘快照生成、文件名规范、快照列表枚举、生命周期淘汰保底 |
| **M4** | 状态管理与系统集成适配 | `lib/core/sync/sync_engine.dart`<br>`lib/features/settings/settings_providers.dart`<br>`lib/features/sync_setup/sync_setup_providers.dart` | 同步前自动快照接线、快照保留天数持久化 Notifier、快照列表异步刷新 |
| **M5** | 设置交互与弹窗组件 | `lib/features/settings/widgets/backup_section.dart`<br>`lib/features/settings/widgets/import_confirm_dialog.dart`<br>`lib/features/settings/widgets/snapshot_history_sheet.dart` | 文件选择与保存交互、导入前统计预检、双模式确认、快照列表还原与删除 |

---

## 阶段二：模块级全量严格审查（循环遍历）

### 模块一：核心二进制编解码协议 (`BackupCodec`)

#### 1. 代码整洁度 (Cleanliness)
- **魔数声明形式**：`final Uint8List kBackupMagicBytes = Uint8List.fromList([0x4F, 0x52, 0x44, 0x4F]);` 为可变对象的全局实例，虽然运行时未被修改，但在常量环境中不具有 `const` 语义，且暴露为顶级可变集合可能存在意外篡改风险。
- **异常信息截断**：在 `decodeBackup` 中，当 `bytes.length < 6` 时直接抛出 `InvalidBackupMagicException([])`，丢失了输入流的实际长度信息。

#### 2. 职责与解耦 (Responsibility & Decoupling)
- **单一职责良好**：该模块仅聚焦于二进制头封装与解封装，底层利用现有的 `SnapshotData` 和 `SnapshotCodec`，保持了协议层的简洁与聚焦。
- **API 冗余**：同时导出了顶级函数 `encodeBackup` / `decodeBackup` 以及纯静态类 `BackupCodec.encode` / `BackupCodec.decode`，两套 API 并存没有必要，建议统一收拢至命名空间类 `BackupCodec` 或明确函数导出风格。

#### 3. 健壮性 (Robustness)
- **切片安全性**：`final payloadBytes = Uint8List.sublistView(bytes, 6);` 在传入普通 `Uint8List` 时安全，但如果传入的数据本身是包含偏置的 `TypedData` view，需要确保 offset 计算正确；目前实现直接依赖 `sublistView`，符合 Dart 规范。
- **解压异常透传**：如果负载不是合法的 Gzip 数据，`decodeSnapshot` 会抛出底层的 `FormatException` 或 `ArchiveException`，上层调用者未统一捕获处理可能导致未包装异常泄漏。

#### 4. 重构与最佳实践建议
```dart
// 优化建议：将魔数定义为 const 字节常量，提供更健壮的长度防御与异常封装
abstract final class BackupCodec {
  static const List<int> magicBytes = [0x4F, 0x52, 0x44, 0x4F]; // 'O', 'R', 'D', 'O'
  static const int formatVersion = 1;
  static const int minSupportedFormatVersion = 1;
  static const int headerSize = 6; // 4 bytes magic + 2 bytes version

  static Uint8List encode(SnapshotData data) {
    final jsonStr = jsonEncode(data.toJson());
    final compressed = GZipCodec().encode(utf8.encode(jsonStr));
    final buffer = Uint8List(headerSize + compressed.length);
    final byteData = ByteData.sublistView(buffer);

    buffer.setRange(0, 4, magicBytes);
    byteData.setUint16(4, formatVersion, Endian.big);
    buffer.setRange(headerSize, buffer.length, compressed);
    return buffer;
  }

  static SnapshotData decode(Uint8List bytes) {
    if (bytes.length < headerSize) {
      throw InvalidBackupMagicException(bytes.sublist(0, bytes.length));
    }
    for (int i = 0; i < 4; i++) {
      if (bytes[i] != magicBytes[i]) {
        throw InvalidBackupMagicException(bytes.sublist(0, 4));
      }
    }
    final byteData = ByteData.sublistView(bytes);
    final version = byteData.getUint16(4, Endian.big);
    if (version < minSupportedFormatVersion || version > formatVersion) {
      throw UnsupportedBackupVersionException(version);
    }
    return decodeSnapshot(Uint8List.sublistView(bytes, headerSize));
  }
}
```

---

### 模块二：数据恢复与全量导入导出业务层 (`BackupRestoreService`)

#### 1. 代码整洁度 (Cleanliness)
- **实体映射硬编码重复**：`_opsFromMerged` 中将 `SnapshotData` 记录转换为 Drift 实体（`Project`, `Task`, `Tag`, `Folder`, `CustomView`）的代码与 `SyncEngine` 内部的转换逻辑完全一致，存在严重的实体级重复逻辑（DRY 违背）。
- **同步键硬编码**：第 210 行使用硬编码字符串 `'sync_tombstones'`，而未引用已有定义的 `SyncSettingsKeys.tombstones`。

#### 2. 职责与解耦 (Responsibility & Decoupling)
- **数据字段缺失严重 Bug**：在 `_opsFromMerged` 转换 `Folder` 实体时：
  ```dart
  upsertFolders.add(
    Folder(
      id: f.id,
      name: f.name,
      sortOrder: f.sortOrder,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
      deleted: 0,
    ),
  );
  ```
  **遗漏了 `color: f.color` 和 `icon: f.icon`**！这会导致用户在执行增量合并恢复后，所有文件夹的自定义图标与颜色被全部擦除！
- **DAO 与事务边界混合**：在覆盖导入 `_executeReplaceImport` 事务内直接调用 `await _repository.settings.remove('sync_tombstones')`，直接穿透到另一个服务/DAO 操作同一个底层数据库，而未在事务上下文内部统一执行删除。

#### 3. 健壮性 (Robustness)
- **覆盖恢复状态重置不完全**：`_executeReplaceImport` 仅清空了墓碑，若之前已启用云同步，远端基准哈希 `sync_base_hash` 和最后同步时间 `sync_last_synced_at` 仍然驻留在 `settings` 中。在覆盖恢复后若未重置同步基准，可能引发下次同步计算变更哈希时的严重冲突或意外回流。
- **孤儿任务静默丢弃**：
  ```dart
  final activeTasks = [
    for (final t in snapshot.tasks)
      if (!t.deleted && validProjectIds.contains(t.projectId)) t,
  ];
  ```
  如果快照中某些任务的 `projectId` 由于某种原因不在 `projects` 列表中，当前逻辑直接将其静默过滤并丢弃，未做 fallback 到默认收件箱（inbox）的处理，可能造成静默数据丢失。

#### 4. 重构与最佳实践建议
```dart
// 1. 补全 Folder.color 与 Folder.icon，防止增量合并时破坏文件夹元数据
Folder(
  id: f.id,
  name: f.name,
  color: f.color,
  icon: f.icon,
  sortOrder: f.sortOrder,
  createdAt: f.createdAt,
  updatedAt: f.updatedAt,
  deleted: 0,
)

// 2. 规范化同步缓存重置，引入 SyncSettingsKeys 常量
await (_db.delete(_db.settings)
      ..where((s) => s.key.isIn([
        SyncSettingsKeys.tombstones,
        SyncSettingsKeys.lastSyncedAt,
      ])))
    .go();
```

---

### 模块三：安全快照池服务与淘汰引擎 (`SnapshotPoolService`)

#### 1. 代码整洁度 (Cleanliness)
- **未处理异步错误**：在 `createSnapshot` 中使用 `unawaited(pruneExpiredSnapshots());`，若 `pruneExpiredSnapshots` 发生异常未被捕获，将成为未处理的异步异常 (unhandled async error)。
- **目录获取冗余**：`_defaultDirectoryGetter` 每次调用都执行 `await getApplicationSupportDirectory()` 和 `snapshotDir.exists()`，缺乏目录路径的内存缓存。

#### 2. 职责与解耦 (Responsibility & Decoupling)
- **职责过重**：快照池管理核心是文件生命周期（生成、查找、清理、还原），但当前每次 `listSnapshots()` 都把所有快照文件的二进制内容强行加载并反序列化出所有的任务和清单计数，导致快照池管理强耦合于全量备份解析。

#### 3. 健壮性与重大性能隐患 (Robustness & Performance Hazard)
- **I/O 与反序列化风暴（I/O & CPU Storm）**：
  在 `pruneExpiredSnapshots()` 中，为了判断哪些快照过期，调用了 `listSnapshots()`。
  而 `listSnapshots()` 对目录下的**每一个快照文件**执行了：
  `await entity.readAsBytes()` -> `GZipCodec.decode()` -> `jsonDecode()` -> `SnapshotData.fromJson()`！
  当快照池有数十个快照且数据量较大时：
  1. 每次同步（preSync）都会触发一次 `createSnapshot` -> `pruneExpiredSnapshots`；
  2. 这会导致在后台将几十个历史快照全部读取进内存解压并反序列化，瞬间消耗大量 CPU 与 I/O 资源，引起 UI 严重掉帧甚至 OOM 闪退！
  3. 事实上，快照文件名中已明确包含格式化时间戳 `snap_20260910_143000_presync.ordobak`，淘汰判断仅需检查文件名时间戳或文件 `lastModified`，根本无需读取文件内容！

#### 4. 重构与最佳实践建议
```dart
// 优化淘汰逻辑：仅基于文件名时间戳和元信息进行轻量淘汰，杜绝全量 I/O 读取
Future<int> pruneExpiredSnapshots() async {
  try {
    final dir = await _getDirectory();
    if (!await dir.exists()) return 0;

    final days = await getRetentionDays();
    final cutoff = DateTime.now().subtract(Duration(days: days));

    final entities = await dir.list().toList();
    final validFiles = <({File file, DateTime dt})>[];

    for (final entity in entities) {
      if (entity is! File) continue;
      final fileName = entity.uri.pathSegments.lastOrNull ?? '';
      if (!fileName.startsWith('snap_') || !fileName.endsWith('.ordobak')) continue;

      final parts = fileName.replaceFirst('.ordobak', '').split('_');
      if (parts.length < 4) continue;
      final dt = parseTimestamp(parts[1], parts[2]) ?? await entity.lastModified();
      validFiles.add((file: entity, dt: dt));
    }

    if (validFiles.isEmpty) return 0;
    // 降序排序，最新的一份排在第 0 位
    validFiles.sort((a, b) => b.dt.compareTo(a.dt));

    var deletedCount = 0;
    // 保底：永远不删除第 0 项（最新快照）
    for (var i = 1; i < validFiles.length; i++) {
      final item = validFiles[i];
      if (item.dt.isBefore(cutoff)) {
        try {
          await item.file.delete();
          deletedCount++;
        } catch (_) {}
      }
    }
    return deletedCount;
  } catch (e) {
    debugPrint('pruneExpiredSnapshots failed: $e');
    return 0;
  }
}
```

---

### 模块四：系统集成与状态适配层 (`SyncEngine` & `SettingsProviders`)

#### 1. 代码整洁度 (Cleanliness)
- **日志占位缺失**：`lib/core/sync/sync_engine.dart:302`：
  ```dart
  debugPrint('sync: preSync snapshot failed (ignored): ');
  ```
  日志末尾有冒号却遗漏了具体的异常变量 `$e`。

#### 2. 职责与解耦 (Responsibility & Decoupling)
- **快照池提供者单向依赖**：`SnapshotPoolService` 由 `snapshotPoolServiceProvider` 注入 `SyncEngine`，通过构造函数可选参数接入，解耦良好，未破坏 `SyncEngine` 在纯测试环境下的独立性。

#### 3. 健壮性 (Robustness)
- **静默失败的容错性**：`SyncEngine` 对快照生成进行了 `try-catch` 包裹，确保快照失败不会阻塞核心同步流程，符合防御性编程原则。
- **状态响应性不足**：当 `SyncEngine` 在后台自动完成 `preSync` 快照生成后，由于未主动通知 `localSnapshotsProvider` 刷新，导致用户如果恰好处于快照列表视图，看到的快照数目与实际落盘状态不同步。

#### 4. 重构与最佳实践建议
```dart
// 修复日志打印占位符
debugPrint('sync: preSync snapshot failed (ignored): $e');
```

---

### 模块五：UI 交互呈现与弹窗层 (`BackupSection` & Dialogs)

#### 1. 代码整洁度与重复代码 (Cleanliness & DRY)
- **私有视觉组件大量重复**：`_SectionHeader`, `_SettingsCard`, `_IconBadge` 在 `backup_section.dart` 中被原样从 `settings_page.dart` 复制了一份，完全可以共用共享组件或从上层抽取，避免未来视觉样式变更时的不同步。

#### 2. 国际化支持 (i18n / Hardcoded Strings)
- **硬编码中文严重**：
  在 `import_confirm_dialog.dart` 与 `snapshot_history_sheet.dart` 中存在大量硬编码中文字符串：
  - `Text('备份时间：${_formatDateTime(widget.summary.exportedAt)}')`
  - `Text('包含：${widget.summary.projectCount} 个清单 · ...')`
  - `Text('请选择导入方式：')`
  - `Text('取消')` / `Text('删除')` / `Text('还原')`
  - `Text('快照点：${_formatDateTime(snap.createdAt)} (${snap.triggerType.label})')`
  - `Text('按快照自由回滚数据（还原前自动保留当前保护点）')`
  实际上 `app_zh.arb` 与 `app_en.arb` 中已经预定义了 `backupImportDialogSummary`, `backupRestoreAction`, `backupDeleteAction`, `cancel` 等 key，但 UI 中被绕过直接写了硬编码字面量，导致多语言支持被破坏。

#### 3. 健壮性 (Robustness)
- **异步间隙 BuildContext 校验**：在 `SnapshotHistorySheet._handleRestore` 中，在多个 `await` 之后（例如 `ImportConfirmDialog.show`），未对 `mounted` 做完整闭环检查即调用 `Navigator.of(context).pop()`。
- **文件不存在反馈体验**：若在文件已被系统清理后点击还原，应给予标准国际化错误反馈。

#### 4. 重构与最佳实践建议
- 全面消除硬编码中文，改用 `AppLocalizations` 国际化资源。
- 保证所有跨越 `await` 异步间隙的 `BuildContext` 与 `Navigator` 均具备 `if (!mounted) return;` 保护。

---

## 阶段三：重大架构缺陷溯源（深度复盘）

### 1. 典型重大缺陷定位：实体数据转换层孤岛与字段丢失缺陷
- **问题表征**：在 `BackupRestoreService` 增量合并中，`Folder` 实体的转换漏掉了 `color` 和 `icon`；同时，`_opsFromMerged` 重复编写了 `Project`, `Task`, `Tag`, `Folder`, `CustomView` 与数据快照 `SnapshotData` 之间的双向映射转换。
- **潜在危害**：用户执行增量恢复操作后，所有文件夹的颜色和图标被静默擦除；未来任何实体字段的扩充（如任务标签关联属性、排序规则等），一旦只修改了 `SyncEngine` 而遗漏了 `BackupRestoreService`，都会引发严重的数据不一致灾难。

### 2. Git 历史溯源与上下文复盘
执行 `git log` 与 `git blame` 追溯：
- 溯源提交：`51616b9b418b6d8e6376b379126e9dbd0846a490`
  - **Commit Message**: `feat: 文件夹同步层 — 快照 v1→v2（FolderRecord + projects.folderId）、reconcileFolderIds、SyncEngine 接线与 folder 墓碑；decodeSnapshot 接受 [1,2] 兼容旧 v1 快照（M6）`
  - **当时上下文**：在该 commit 中，开发者为实现文件夹导航与同步，将 `FolderRecord` 引入了同步快照 v2。在 `SyncEngine` 中编写了 `_folderFromRecord`，准确地赋值了 `color: r.color` 和 `icon: r.icon`。
- **缺陷引入时机**：
  在本次提交 `75d1539d3243788fd3f798aea9069a23b829826f` (`feat(backup): 支持数据导入导出与本地安全快照功能`) 中，开发者为了在 `BackupRestoreService` 中实现增量合并，没有复用或提取已有的实体转换函数，而是通过“复制-粘贴-手写改写”重新实现了一套 `_opsFromMerged`。在手写过程中，构造 `Folder` 时仅传递了 `id, name, sortOrder, createdAt, updatedAt, deleted`，直接漏掉了 `color` 和 `icon` 字段。

### 3. 正确的架构演进路线图
1. **统一模型映射抽象 (Model Mapper Abstraction)**：
   将 `SnapshotData` 记录与 Drift 实体对象之间的相互映射（如 `recordToFolder`, `folderToRecord` 等）提取为领域模型转换工具（或放在 `snapshot_converters.dart`），使 `SyncEngine` 与 `BackupRestoreService` 共享唯一的转换单一信任源（Single Source of Truth）。
2. **避免重复造轮子 (DRY 原则)**：
   消除两份平行维护的 `_opsFromMerged`，确保一旦数据表扩充字段，编译器在编译期即进行强类型检查拦截。

---

## 阶段四：改进实施与复核进度表

| 编号 | 问题项 | 涉及文件 | 严重等级 | 状态 |
|---|---|---|---|---|
| **P1** | 增量合并恢复时漏传 `Folder.color` 和 `Folder.icon`（业务 Bug） | `lib/core/backup/backup_restore_service.dart` | **Blocker** | [x] 已修复 |
| **P2** | 快照池清理时进行全量文件 I/O 与反序列化风暴 (性能隐患) | `lib/core/backup/snapshot_pool_service.dart` | **Critical** | [x] 已修复 |
| **P3** | `import_confirm_dialog` 与 `snapshot_history_sheet` 中大量硬编码中文 | `lib/features/settings/widgets/*.dart` | **Major** | [x] 已修复 |
| **P4** | 覆盖恢复时硬编码 `'sync_tombstones'` 且未规范清理同步基准 | `lib/core/backup/backup_restore_service.dart` | **Major** | [x] 已修复 |
| **P5** | `SyncEngine` 中日志输出缺失占位符 `$e` | `lib/core/sync/sync_engine.dart` | **Minor** | [x] 已修复 |
| **P6** | `BackupCodec` 魔数定义与短字节流异常处理不严密 | `lib/core/backup/backup_codec.dart` | **Minor** | [x] 已修复 |

---

## 阶段五：二次复核与质量验收结论

在完成上述 P1 ~ P6 的针对性改进后，我们对受影响的全部模块及全工程执行了二次严格复核与质量闭环验收，结果如下：

### 1. 静态代码分析与规范核查
- **命令**: `flutter analyze`
- **执行结果**: `No issues found! (ran in 18.4s)`
- **验收结论**: 零错误、零警告、零 linter hint。所有导入、命名、国际化调用及异步上下文防护均符合严苛规范。

### 2. 核心备份与安全快照专项测试套件
- **命令**: `flutter test test/core/backup/ test/features/settings/backup_ui_test.dart`
- **覆盖模块**:
  - `backup_codec_test.dart` (协议魔数、版本协商、损坏容错)
  - `backup_restore_service_test.dart` (覆盖恢复、增量合并 LWW、Folder 完整字段回归防护)
  - `snapshot_pool_service_test.dart` (快照持久化、淘汰算法、前置安全快照链)
  - `backup_ui_test.dart` (设置入口、下拉保留天数、导入弹窗模式选择、快照 Sheet 还原/删除交互)
- **执行结果**: `18 / 18 passed (All tests passed!)`

### 3. 全局业务与设置模块集成回归测试
- **命令**: `flutter test test/core/ test/features/settings/`
- **执行结果**: `400+ passed (All tests passed!)`
- **验收结论**: 现有数据流、树形关系计算、农历节日引擎、状态派生及同步机制均完全不受影响，无回归破损。

### 4. 架构复核总结
- **杜绝过度设计**: 改进过程没有引入任何不必要的重型设计模式（如过度解耦的中介层或多余的全局总线），而是以最直接、高内聚、易维护的方式修复了根本隐患。
- **数据一致性闭环**: 彻底补齐了增量合并与覆盖恢复时的数据字段遗漏（`Folder.color`, `Folder.icon`）与基准状态残留（`tombstones`, `lastSyncedAt`），为用户提供了坚实可靠的数据资产保障。
