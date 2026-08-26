# AGENTS.md — AI 开发代理工作指引

本文件是**所有 AI 开发代理（agent）进入本仓库的第一入口**。任何代理在动手改代码之前，必须先阅读本文件并遵循其中的规则。

## 1. 必读文档（按顺序）

开发前必须通读以下文档，理解全貌后再动手：

| 顺序 | 文档 | 内容 |
|---|---|---|
| 0 | `CLAUDE.md` | Agents规范 |
| 1 | `docs/00-project-brief.md` | 项目概述、范围、非目标、关键决策 |
| 2 | `docs/10-requirements.md` | 功能需求（FR-xxx）、非功能需求（NFR）、验收标准 |
| 3 | `docs/20-tech-stack.md` | 技术选型、版本锁定、包职责 |
| 4 | `docs/30-architecture.md` | 分层架构、目录结构、路由、状态管理、适配规则 |
| 5 | `docs/40-data-model.md` | 数据模型、字段、枚举、校验规则、迁移策略 |
| 6 | `docs/50-ui-ux.md` | 设计令牌、屏幕规格、交互规格 |
| 7 | `docs/60-sync-design.md` | 同步协议、合并算法、错误处理 |
| 8 | `docs/70-milestones.md` | 里程碑 M0–M5 与验收标准（DoD） |

## 2. 常用命令

```bash
flutter pub get                              # 拉取依赖
dart run build_runner build --delete-conflicting-outputs   # Drift 代码生成（改表后必跑）
flutter gen-l10n                             # 改 ARB 文件后生成 l10n
flutter analyze                              # 静态检查（提交前必须 0 error）
dart format .                                # 格式化
flutter test                                 # 跑全部测试
flutter run -d windows                       # Windows 运行
flutter run -d <android-device-id>           # Android 运行（flutter devices 查看）
flutter build apk --release --split-per-abi  # 按abi分包构建apk: build/app/outputs/flutter-apk/
flutter build linux --release                # 产出 build/linux/x64/release/bundle/
flutter build windows --release              # 产出 build\windows\x64\runner\Release\
```

## 2.5 本机网络代理

本机有一个本地代理可用：**`127.0.0.1:10808`**（HTTP/SOCKS 由客户端自定）。直连 Google/GitHub/pub.dev 较慢或超时，遇到下载超时/网络失败时启用代理：

```bash
# 当前 shell 临时启用（推荐，用完即止）
export https_proxy=http://127.0.0.1:10808
export http_proxy=http://127.0.0.1:10808

# 或写入 ~/.bashrc 常驻（已写入注释示例，按需取消注释）
# Flutter/Dart 工具链会自动读取上述环境变量
```

> **⚠️ 构建前必做**：`flutter build` / `flutter run` / `pub get` 前，先在当前 shell 导出上面的 `http_proxy` / `https_proxy`（即执行上方两行 export）。原因：Gradle daemon 的**环境变量快照**在启动时固化，不含后续 export 的代理变量；Gradle 自身的依赖下载走 `~/.gradle/gradle.properties` 的 `systemProp.*` 代理，但 **Flutter 工具侧**（engine 产物下载、pub、AOT 相关网络请求）只认 `http_proxy`/`https_proxy` 环境变量。不导出时，任何未缓存的产物直连 `dl.google.com` / `download.flutter.io` 会静默卡死（典型症状：`flutter build apk --release` 长时间停在 `Running Gradle task 'assembleRelease'...` 无任何输出）。

注意：sdkmanager 等 Java 工具不读 `http_proxy` 环境变量，需用 `JAVA_OPTS`：
```bash
export JAVA_OPTS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=10808 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=10808"
```

Gradle 依赖下载已在本机 `~/.gradle/gradle.properties` 配置代理（`systemProp.*.proxyHost`），对 Android 构建持久生效，无需每次设置。若代理失效，删掉该文件即可回退直连。

> **⚠️ dl.google.com 必须直连（重要）**：本机 hiddify 代理（`127.0.0.1:10808`）到 `dl.google.com` 的路由是坏的（Connection reset / 超时），而该域名直连实测 0.5s 内可达。已在 `~/.gradle/gradle.properties` 的 `nonProxyHosts` 中加入 `dl.google.com` 强制直连。**若重建该文件或改代理配置，务必保留此例外**——否则 Gradle 下载 google() maven 依赖会无限重试，构建假死在 `Running Gradle task 'assembleRelease'`（症状：任务无输出、CPU 低、build/ 下无新产物；可用 `./gradlew :app:assembleRelease --info` 看到 `Connection reset ... Retrying` 刷屏）。

> **⚠️ `flutter test` 前必须 unset 代理**：测试框架的 VM-service 走 `http://127.0.0.1:<port>`，若 shell 里 export 了 `http_proxy`/`https_proxy`，该本地连接会被劫持到代理 → 所有测试文件加载失败（`HttpException: Connection closed before full header was received`）。测试不需网络，运行 `flutter test` 前执行 `unset http_proxy https_proxy`。

**Gradle 发行版下载**（wrapper 阶段）不走 `gradle.properties`，若全新环境遇到卡在 `gradle-x.x-all.zip.part 0B`，改用国内镜像预下载：
```bash
curl -s -o ~/.gradle/wrapper/dists/gradle-8.14-all/<hash>/gradle-8.14-all.zip \
  "https://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip"
# <hash> 见 wrapper 缓存目录名（如 c2qonpi39x1mddn7hk5gh9iqj）
```

## 2.6 Linux 开发环境

环境变量已在 `~/.bashrc` 配置（`JAVA_HOME` / `ANDROID_HOME` / `ANDROID_SDK_ROOT` / `PATH`）：

| 组件 | 路径 |
|---|---|
| Flutter SDK (Linux) | `/mnt/Data/Personal/04_others/My_Development/FlutterSDK-Linux/flutter` |
| JDK 17 (Temurin) | `/mnt/Data/Personal/04_others/My_Development/JDK-Linux/jdk-17.0.20+8` |
| Android SDK (Linux) | `/mnt/Data/Personal/04_others/My_Development/AndroidSDK-Linux` |

注意：**Linux 环境只能构建 Android 与 Linux 桌面目标**，无法构建 Windows 桌面（Flutter 不支持 Linux→Windows 交叉编译）。若 shell 里 `flutter` 命令不可用，先执行 `source ~/.bashrc`。

## 2.7 Windows 开发环境

Windows 环境相关工具及 SDK 路径说明：

- **Shell**: 系统自带 PowerShell
- **Git**: 通过 Scoop 安装
- **SDK 目录**:

| 组件 | 路径 |
|---|---|
| Flutter SDK | `D:\Personal\04_others\My_Development\FlutterSDK` |
| JDK | `D:\Personal\04_others\My_Development\JDK` |
| Android SDK | `D:\Personal\04_others\My_Development\AndroidSDK` |

- **PowerShell 临时代理设置**（网络超时/需要代理时使用）：
  ```powershell
  $env:http_proxy="http://127.0.0.1:10808"
  $env:https_proxy="http://127.0.0.1:10808"
  # 跑 flutter test 前需清除代理
  Remove-Item env:http_proxy, env:https_proxy
  ```

注意：在 Windows 环境下可构建 Windows 桌面应用与 Android 目标。

## 3. 硬性约束（违反即返工）

1. **层级上限**：任务最多 3 级（项目 > 任务 > 子任务 > 孙任务）。所有写入/移动必须做深度校验（见 `40-data-model.md` §5）。
2. **派生状态**：有子任务的任务，其状态/完成度**由子任务派生计算**，禁止存冗余状态字段，禁止允许用户手动修改有子任务任务的状态。
3. **同步字段**：`projects` / `tasks` / `tags` 三张表每一行必须有 `id`(UUID) / `updatedAt`(UTC 毫秒) / `deleted`(墓碑) 三个字段，任何新增表若参与同步也必须带这三个字段。
4. **时间存储**：所有时间一律存 **UTC 毫秒整数**（`DateTime.millisecondsSinceEpoch`），只在 UI 层按本地时区格式化。禁止存字符串时间。
5. **v1 范围外**：不做提醒通知、不做重复任务、不做多用户登录、不做多端同时编辑。不要擅自实现。
6. **凭据安全**：同步服务器地址/账号/密钥必须存 `flutter_secure_storage`，禁止明文存 `shared_preferences`，禁止写进日志。
7. **版本锁定**：`pubspec.yaml` 中依赖版本按 `20-tech-stack.md` §4 锁定，**未经用户明确同意不得升级任何依赖**（防版本漂移）。
8. **i18n**：所有用户可见文案必须走 ARB（`lib/core/l10n/`），禁止硬编码中文/英文字符串。改 ARB 后运行 `flutter gen-l10n`。
9. **主题**：所有颜色/圆角/间距/动效必须使用设计令牌（`50-ui-ux.md` §2），禁止散落魔法值。
10. **删除语义**：删除 = 本地硬删 + 快照墓碑；级联删除规则见 `40-data-model.md` §7。

## 4. 代码规范

- 目录结构遵循 `30-architecture.md` §3 的 `lib/` 布局，按 feature 组织。
- 状态管理用 Riverpod（`flutter_riverpod`，无 codegen 版本），禁止引入其他状态管理库。
- 路由用 `go_router`，路由表集中在 `lib/router.dart`。
- 数据库访问只通过 DAO/Repository 层，UI 层禁止直接拼 SQL。
- 提交前：`flutter analyze` 0 error + `flutter test` 全绿 + `dart format`。
- 新增/修改表结构后：更新 `40-data-model.md` 对应字段表，并写迁移步骤，禁止直接改旧表结构。

## 5. 里程碑状态

当前所处里程碑见 `docs/70-milestones.md`。每个里程碑有明确的 DoD（完成定义），代理完成某里程碑后必须按 DoD 逐条自检，并在交付说明中列出自检结果。
