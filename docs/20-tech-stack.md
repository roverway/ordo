# 20 — 技术选型与版本锁定（Tech Stack）

> 本文档定义技术栈、选型理由、包职责与版本锁定规则。**版本锁定是硬约束**（见 `AGENTS.md` §3-7）。

## 1. 框架选型

| 决策 | 结论 | 理由 |
|---|---|---|
| 框架 | **Flutter 3.x + Dart 3** | 一套代码覆盖 Windows/Linux/Android/iOS；移动优先 UI 与自适应布局是强项；i18n（`flutter_localizations`）与主题（`ThemeData`）内置成熟 |
| 备选 | Compose Multiplatform | 生态较新、桌面/移动支持尚可，但社区与包生态弱于 Flutter，且本项目已确认 Flutter |
| 备选 | Tauri / Web 技术栈 | 桌面优秀但移动端弱，不符合「移动端优先」定位 |

## 2. 核心包清单与职责

| 包 | 职责 | 说明 |
|---|---|---|
| `drift` + `sqlite3_flutter_libs` | 本地数据库 | SQLite 关系型存储；流式查询；版本化迁移；`build_runner` 代码生成 |
| `flutter_riverpod` | 状态管理 | 无 codegen 版本；Provider 组合 + 自动销毁；与 Drift 流配合 |
| `go_router` | 路由 | state-driven 路由；集中路由表；支持深链参数 |
| `flutter_localizations` + `intl` | 国际化 | ARB 文件 + `flutter gen-l10n` 生成 |
| `webdav_client` | WebDAV 同步 | pub.dev 高信誉；PUT/GET/HEAD、认证、目录操作 |
| `minio` | S3 同步 | **3.5.8**（2026-08 选定）：支持自定义 endpoint（AWS/R2/MinIO/Wasabi）、SigV4 库内建、pathStyle 默认 true。替代已调研失败的 `s3_dart`（其 getRequestUrl 会把自定义 endpoint 重写为 `s3.<region>.<endpoint>` 导致 NXDOMAIN，R2/MinIO 不可用） |
| `flutter_secure_storage` | 凭据存储 | Android Keystore / Windows DPAPI；**禁止**明文存 shared_preferences |
| `uuid` | UUID v4 生成 | 所有记录主键 |
| `path_provider` | 应用目录 | 数据库文件位置 |
| `shared_preferences` | 非敏感设置 | 主题/语言/同步开关等非敏感偏好（凭据除外） |
| `dart:io` GZipCodec | gzip 压缩 | 快照压缩（同步）；标准库自带，零第三方依赖，isolate 可用（`archive` 不再引入） |

## 3. UI 风格选型（重要决策）

- **结论**：Material 3 + 自定义设计令牌（Design Tokens），复现 MIUI/HyperOS 视觉语言（squircle 圆角、弹簧动效、Monet 动态色）。
- **不使用 `flutter_miuix` 的原因**：
  1. 原版 `miuix`（`compose-miuix-ui/miuix`）是 **Compose Multiplatform（Kotlin）** 库，与 Flutter 不兼容；
  2. Flutter 移植版 `flutter_miuix` 于 2026-07 才首发，star/下载量极低、个人维护、API 未稳定，长期项目绑定风险高；
  3. HyperOS 风格在 iOS/Windows 上违和，Material 风格平台中立。
- **观望名单**：`flutter_miuix` 列入观望。评估门：star > 100 且 API 稳定（发布 ≥6 个月）后，再评估是否引入。主题层必须做好抽象（`AppTheme` 单一入口），未来可切换而不重构。
- **设计令牌**：全部颜色/圆角/间距/动效定义在 `lib/core/theme/app_tokens.dart`，UI 禁止散落魔法值（见 `50-ui-ux.md` §2）。

## 4. 版本锁定表

> 以下为**基线版本**。M0 脚手架阶段以 `flutter pub add` 实际解析的版本为准并回填本表。**未经用户明确同意，任何代理不得升级依赖**（防版本漂移）。

| 包 | 基线（major 约束） | 备注 |
|---|---|---|
| flutter | 3.38.5 stable | Dart 3.10.4 |
| drift | 2.31.0 | 锁 2.31.0（2.32+ 需 Dart 3.11+）；含 `drift_flutter` 辅助（M1 引入） |
| drift_flutter | 0.2.8 | 与 drift 2.31.0 配套（0.3.x 需 sqlite3 ^3.0.0，冲突） |
| drift_dev | 2.31.0 | dev；与 drift 同版本配套 |
| build_runner | ^2.15.1 | dev；构建需 `--force-jit`（sqlite3 2.x build hook 与 Dart 3.10 AOT 兼容问题） |
| sqlite3 | ^2.9.4 | dev；仅测试用（原生库加载，见 test/helpers/db_test_setup.dart） |
| flutter_riverpod | ^3.3.2 | 无 codegen（M0 已装，注意 3.x API） |
| go_router | ^17.5.0 | M0 已装 |
| flutter_localizations | 随 Flutter | M0 引入 |
| intl | 随 Flutter 锁定 | M0 引入 |
| shared_preferences | ^2.5.5 | M0 已装（非敏感设置） |
| webdav_client | 1.2.2 | M4 引入（2026-08 锁定） |
| minio | 3.5.8 | M4 引入（2026-08 锁定；替代 s3_dart，勿用 3.5.1 撤回版） |
| flutter_secure_storage | 11.0.0 | M4 引入（2026-08 锁定） |
| uuid | ^4.6.0 | M1 已装 |
| path_provider | ^2.1.6 | M1 已装 |

**锁定流程**：M0 用 `flutter pub add <pkg>` 安装 → 记录 `pubspec.lock` → 回填本表 → 后续任何 `pub upgrade` 需用户批准。

## 5. 平台注意点

| 平台 | 注意点 |
|---|---|
| Android | Monet 动态色仅 Android 12+，低版本回退种子色主题；返回键用 `PopScope`；生命周期触发同步 |
| Windows | 窗口最小尺寸；DPI 适配（Flutter 默认）；数据库路径用 `path_provider`；单实例运行（可选） |
| iOS / Linux | 后置；代码无需分叉，仅需平台联调 |

## 6. 开发工具链

- 代码生成：`dart run build_runner build --delete-conflicting-outputs`（Drift）
- l10n 生成：`flutter gen-l10n`
- 静态检查：`flutter analyze`（0 error）
- 格式化：`dart format .`
- 测试：`flutter test`