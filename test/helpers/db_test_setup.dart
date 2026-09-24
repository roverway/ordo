// 测试数据库基建：配置 sqlite3 原生库加载。
//
// 本机 Linux 桌面只有 `libsqlite3.so.0`（版本 3.51.2），sqlite3 包默认查找
// `libsqlite3.so`（无版本号），纯 VM 测试环境（flutter test）下无法自动解析。
// 通过 `open.overrideFor` 显式指向系统库（须在任何数据库打开前调用）。

import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:sqlite3/open.dart';
import 'package:ordo/core/db/database.dart';

/// 配置 sqlite3 使用系统 `libsqlite3.so.0`（幂等，可重复调用）。
void configureTestSqlite3() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
}

/// 打开内存测试数据库（含 sqlite3 加载配置）。
AppDatabase openTestDatabase() {
  configureTestSqlite3();
  return AppDatabase.forTesting();
}
