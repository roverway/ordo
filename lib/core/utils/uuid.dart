import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// 生成 UUID v4（docs/30-architecture.md §2 `core/utils/uuid.dart`）。
///
/// 所有记录主键使用 UUID v4（20-tech-stack.md §4）。
String newUuid() => _uuid.v4();
