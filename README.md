# 知序 Ordo (Order & Priority)

> **知其轻重，行止有序**  
> 一款跨平台、离线优先、安全可靠的待办与项目管理应用。

---

## 📖 用户使用手册 (User Manual)

知序内置了详尽的中英文用户使用手册，涵盖从初学者快速入门到高级数据同步与备份容灾的完整指南：

- 🇨🇳 **中文使用手册**：[docs/用户使用手册.md](docs/用户使用手册.md)
- 🇬🇧 **User Manual (English)**：[docs/USER_MANUAL.md](docs/USER_MANUAL.md)

### 💡 应用内直接查阅
应用已将手册离线打包在安装包内，支持在中英文间一键切换：
- **查阅路径**：进入底部导航栏「**设置**」页面 -> 点击「**使用帮助**」（快捷阅读带目录索引、实时搜索、高亮显示的完整排版手册）。

---

## ✨ 核心特性

1. **清晰的四态生命周期**：
   - 待办（Todo）→ 进行中（In Progress）→ 已完成（Done）/ 已放弃（Dropped），支持一键激活、完成与重启。
2. **三级结构化任务树**：
   - 项目（Project）→ 任务（Task）→ 子步骤（Sub-step），父任务进度根据子项完成情况自动衍生计算。
3. **多维分类体系**：
   - 收集箱（Inbox）、文件夹分类、独立项目管理以及多标签（Tag）快速过滤。
4. **全景日历与传统历法**：
   - 月视图日程排布、农历、二十四节气与节假日标识，任务按计划截止日直观分布。
5. **安全可靠的云端同步**：
   - 支持 WebDAV 与兼容 S3 协议（如 MinIO、阿里云 OSS、AWS S3 等）对象存储，采用中继合并策略保障离线优先与多端合并。
6. **完备的数据容灾保障**：
   - 本地快照历史池随时一键回滚；支持导出加密/明文 `.ordobak` 备份包与外部恢复。
7. **优雅的设计与交互**：
   - 8 款精美主题（墨黑、皓白、黛蓝、群青、松绿、丹砂、紫棠、琥珀），自适应明暗模式；移动端全手势滑动操作与宽屏侧边抽屉。

---

## 🛠️ 技术栈

- **前端框架**：Flutter (Target: Android, iOS, macOS, Windows, Linux, Web)
- **状态管理**：Riverpod (flutter_riverpod)
- **本地数据库**：Drift (SQLite3 响应式流)
- **路由导航**：GoRouter
- **国际化**：Flutter Gen-l10n (zh / en)
- **安全存储**：flutter_secure_storage

---

## 🚀 开发者指南

### 环境准备
- Flutter SDK (>= 3.7.0)
- Dart SDK (>= 3.7.0)

### 获取依赖与生成代码
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
```

### 运行应用
```bash
flutter run
```

### 代码质量与测试
```bash
flutter analyze
flutter test
```
