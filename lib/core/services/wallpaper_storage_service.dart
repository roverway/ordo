import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 本地壁纸文件存储与管理服务。
class WallpaperStorageService {
  WallpaperStorageService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  /// 获取壁纸存储专属目录。
  Future<Directory> getWallpaperDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final wallpaperDir = Directory('${appDir.path}/wallpapers');
    if (!await wallpaperDir.exists()) {
      await wallpaperDir.create(recursive: true);
    }
    return wallpaperDir;
  }

  /// 唤起系统文件选择器，选取图片并安全拷贝至沙箱目录。
  ///
  /// 返回拷贝后的持久化绝对文件路径；若用户取消或失败则返回 null。
  Future<String?> pickAndSaveCustomWallpaper() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (file == null) {
        return null;
      }

      final sourcePath = file.path;
      if (sourcePath != null && sourcePath.isNotEmpty) {
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          final dir = await getWallpaperDirectory();
          final extension = sourcePath.contains('.')
              ? sourcePath.split('.').last.toLowerCase()
              : (file.extension ?? 'png');
          final fileName = 'custom_wp_${_uuid.v4()}.$extension';
          final targetPath = '${dir.path}/$fileName';

          await sourceFile.copy(targetPath);
          return targetPath;
        }
      }

      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        final dir = await getWallpaperDirectory();
        final extension = file.extension ?? 'png';
        final fileName = 'custom_wp_${_uuid.v4()}.$extension';
        final targetPath = '${dir.path}/$fileName';

        await File(targetPath).writeAsBytes(bytes);
        return targetPath;
      }

      return null;
    } catch (e) {
      debugPrint('pickAndSaveCustomWallpaper 失败: $e');
      return null;
    }
  }

  /// 安全删除指定的本地自定义壁纸文件（如果存在）。
  Future<void> deleteWallpaperFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('deleteWallpaperFile 失败: $e');
    }
  }
}
