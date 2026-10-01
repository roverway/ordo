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
git config core.hooksPath .githooks          # 初始化版本化 Git Hooks（新环境仅需执行一次）
flutter pub get                              # 拉取依赖
dart run build_runner build --delete-conflicting-outputs   # Drift 代码生成（改表后必跑）
flutter gen-l10n                             # 改 ARB 文件后生成 l10n
bash tool/verify.sh                          # 运行全量质量与令牌守卫流水线
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
