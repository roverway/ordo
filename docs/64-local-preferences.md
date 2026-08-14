# 64 — 本地偏好统一持久化（Local Preferences Unification）（定稿）

> 状态：**定稿（决策已确认 2026-08-14）**
> 相关文档：`40-data-model.md`（§2.5）、`10-requirements.md`（FR-SET-01/02）、`20-tech-stack.md`、`70-milestones.md`（M8）

## 1. 背景与问题

当前设备本地偏好存在**双机制并存且文档与实现不符**：

| 偏好 | 当前实现 | 文档声称（40-data-model §2.5） |
|---|---|---|
| 主题模式 `theme_mode` | SharedPreferences | settings 表 |
| 语言 `locale` | SharedPreferences | settings 表 |
| 文件夹展开 `folder_expanded_<id>` | settings 表 | settings 表 |
| 隐藏已完成任务 | **会话级（内存，重启丢失）** | — |
| 同步设置/墓碑/设备号 | settings 表 | settings 表 |

目标：**统一到 Drift `settings` 表**（设备本地、不参与同步），修复文档与实现的分歧，并把「隐藏已完成任务」从会话级改为持久化。

## 2. 决策（已确认）

| 决策 | 选择 |
|---|---|
| 范围 | **全面统一**：主题/语言/隐藏已完成全部迁至 settings 表；文件夹展开已在 settings 表，不动 |
| 存储介质 | **统一到 settings 表（含 SharedPreferences 一次性迁移）** |
| 设置页入口 | **不加**（保持任务页三点菜单切换，仅状态持久化） |
| 依赖 | **保留 shared_preferences 为仅迁移用途**（§3.5；一次性迁移需读取旧值，迁移完成后不再读写，后续版本可移除） |

## 3. 设计

### 3.1 同步缓存层（核心）

Drift 读是异步的，但 `themeModeProvider`/`localeProvider` 需在首帧同步可用（避免主题闪烁）。
方案：**启动时预载 settings 表到内存同步缓存**，providers 同步读缓存、写时穿透到 SettingsDao。

新增 `lib/features/settings/settings_providers.dart`：

```dart
/// 设备本地偏好缓存：settings 表在内存的同步镜像。
/// main() 启动时 seed 预载（含 SharedPreferences 一次性迁移），providers 同步读、
/// 写时穿透到 SettingsDao（异步）。
///
/// 注入时序（main）：容器创建时 override 空实例 → 读 repo → `attach(repo.settings)`
/// → `seed(getAll())`。测试用不 attach 的纯内存实例（写不落库）。
class AppSettingsCache {
  SettingsDao? _dao;
  final Map<String, String> _values = {};
  void attach(SettingsDao dao) => _dao = dao;
  String? get(String key) => _values[key];
  void seed(Map<String, String> values) => _values.addAll(values);
  Future<void> set(String key, String value) async {
    _values[key] = value;
    await _dao?.set(key, value);
  }
}

/// 全局缓存 Provider：main() 注入；测试经 override 提供内存实例。
final appSettingsCacheProvider = Provider<AppSettingsCache>((ref) {
  throw StateError('appSettingsCacheProvider 必须在 main() 中通过 override 注入');
});
```

### 3.2 Providers 改写

- `themeModeProvider` / `localeProvider`：`build()` 改读 `appSettingsCacheProvider`（同步），`setXxx` 改 `await cache.set(...)` 后更新 state。**外部 API 不变**（`app.dart`/设置页消费方零改动）。
- `hideCompletedTasksProvider`（`lib/features/tasks/task_providers.dart`）：由 `Notifier<bool> build()=>false` 改为读缓存 key `hide_completed`（'1'/'0'，默认 false 显示全部）；`toggle()` 穿透写缓存。消费方（task_tree/task_list_page）watch 方式不变。
- `folderExpandProvider`：已在 settings 表（AsyncNotifier），**不动**。

### 3.3 main.dart 启动链路

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(
    overrides: [appSettingsCacheProvider.overrideWithValue(AppSettingsCache(repo.settings))],
  );
  final repo = container.read(todoRepositoryProvider);
  // 一次性迁移：SharedPreferences → settings 表（theme_mode/locale）。
  await migrateLegacyPrefs(container, repo);
  // 预载 settings 表 → 缓存（迁移结果已并入）。
  final cache = container.read(appSettingsCacheProvider);
  cache.seed(await repo.settings.getAll());
  ...（同步接线/启动同步不变）
}
```

`migrateLegacyPrefs`：读 SharedPreferences，若 settings 表无 `theme_mode`/`locale` 且 SharedPreferences 有值 → 写入 settings 表（幂等，仅当缺失才迁移）。

### 3.4 测试改造（影响面最大）

现有 10 个测试文件用 `sharedPreferencesProvider.overrideWithValue(prefs)` + `SharedPreferences.setMockInitialValues({})`。
统一改为：

```dart
// 替代原 prefs 注入：内存缓存实例（不触发 DAO 写）。
final cache = AppSettingsCache(SettingsDao(NativeDatabase.memory()));
appSettingsCacheProvider.overrideWithValue(cache)
```

- `AppSettingsCache` 提供**纯内存构造**（如 `AppSettingsCache.inMemory()`，DAO 用内存 DB 或可空——测试仅读/写 Map，不落库），避免测试开真实 DB。
- 各测试 helper（`_pumpXxx`）改一处注入即可；删除 SharedPreferences mock。
- 新增 hideCompletedTasksProvider 持久化测试：设置后重建容器 → 值保留。
- 新增迁移测试：SharedPreferences 有值 + settings 表缺失 → 迁移后 settings 表有值。

### 3.5 依赖处理（保留 shared_preferences 为迁移用途）

- **`shared_preferences` 保留**（fix-1 裁决）：`migrateLegacyPrefs` 是运行时一次性迁移逻辑，必须读取旧值，包必须存在于主依赖；迁移测试也需 mock。迁移完成后应用不再读写该包，**后续版本可移除**（pubspec 附注释说明）。
- 不再新增任何依赖。

## 4. 文件清单

| 文件 | 变更 |
|---|---|
| `lib/features/settings/settings_providers.dart` | 删 sharedPreferencesProvider；新增 AppSettingsCache + appSettingsCacheProvider；themeMode/locale 改写 |
| `lib/features/tasks/task_providers.dart` | hideCompletedTasksProvider 持久化 |
| `lib/main.dart` | 缓存注入 + 一次性迁移 + 预载 |
| `pubspec.yaml` | 保留 shared_preferences（仅迁移用途，附注释） |
| 10 个测试文件 | prefs 注入 → cache 注入 |
| 新增测试 | 持久化回归 + 迁移测试 |

## 5. 文档同步

- `40-data-model.md` §2.5：确认「主题/语言/隐藏已完成/文件夹展开」均存 settings 表（文档已符合，补 hide_completed 说明）。
- `10-requirements.md`：FR-SET-01/02 持久化介质说明（settings 表）。
- `20-tech-stack.md`：依赖表更新为「shared_preferences 保留（仅迁移用途，后续可移除）」。.
- `70-milestones.md`：新增 M8。

## 6. 验证

- `flutter analyze` 0 error；`flutter test` 全绿；`dart format`。
- 重点回归：主题/语言切换即时生效且重启保留；隐藏已完成重启保留；文件夹展开持久化不受影响。

## 7. 里程碑

新增 **M8 — 本地偏好统一持久化**。DoD：三偏好统一到 settings 表、shared_preferences 转仅迁移用途（保留）、一次性迁移、测试全绿、文档同步。
