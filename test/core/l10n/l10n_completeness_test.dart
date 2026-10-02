import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/l10n/app_localizations.dart';

void main() {
  group('双语国际化 (i18n) 完整性与质量门禁测试', () {
    late Map<String, dynamic> zhMap;
    late Map<String, dynamic> enMap;

    setUpAll(() {
      final zhFile = File('lib/core/l10n/app_zh.arb');
      final enFile = File('lib/core/l10n/app_en.arb');

      expect(zhFile.existsSync(), isTrue, reason: 'app_zh.arb 必须存在');
      expect(enFile.existsSync(), isTrue, reason: 'app_en.arb 必须存在');

      zhMap = jsonDecode(zhFile.readAsStringSync()) as Map<String, dynamic>;
      enMap = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('支持的 Locale 包含 zh 与 en', () {
      final languageCodes = AppLocalizations.supportedLocales
          .map((l) => l.languageCode)
          .toSet();
      expect(languageCodes, containsAll(['zh', 'en']));
    });

    test('中英文 ARB 文件键集合 100% 严格对称对齐（零缺失翻译键）', () {
      final zhKeys = zhMap.keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys = enMap.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInEn = zhKeys.difference(enKeys);
      final missingInZh = enKeys.difference(zhKeys);

      expect(missingInEn, isEmpty, reason: '英文 ARB 缺少以下翻译键: $missingInEn');
      expect(missingInZh, isEmpty, reason: '中文 ARB 缺少以下模板键: $missingInZh');
    });

    test('双语所有翻译内容不可为空或仅包含空白', () {
      final zhKeys = zhMap.keys.where((k) => !k.startsWith('@'));
      for (final key in zhKeys) {
        final zhVal = zhMap[key]?.toString().trim() ?? '';
        final enVal = enMap[key]?.toString().trim() ?? '';

        expect(zhVal.isNotEmpty, isTrue, reason: 'zh [$key] 翻译不可为空');
        expect(enVal.isNotEmpty, isTrue, reason: 'en [$key] 翻译不可为空');
      }
    });

    test('中英文模板变量占位符 {variable} 完全一致', () {
      final placeholderRegex = RegExp(r'\{([a-zA-Z0-9_]+)\}');
      final zhKeys = zhMap.keys.where((k) => !k.startsWith('@'));

      for (final key in zhKeys) {
        final zhVal = zhMap[key]?.toString() ?? '';
        final enVal = enMap[key]?.toString() ?? '';

        final zhPlaceholders = placeholderRegex
            .allMatches(zhVal)
            .map((m) => m.group(1))
            .toSet();
        final enPlaceholders = placeholderRegex
            .allMatches(enVal)
            .map((m) => m.group(1))
            .toSet();

        expect(
          enPlaceholders,
          equals(zhPlaceholders),
          reason:
              '键 [$key] 的变量占位符不匹配: zh=$zhPlaceholders vs en=$enPlaceholders',
        );
      }
    });

    test('英文 ARB 中严禁意外残留中文字符（除语言切换自身名称白名单外）', () {
      final zhPattern = RegExp(r'[\u4e00-\u9fa5]');
      const whitelist = {'languageZh', 'aboutBrandZhTitle'};

      final leakedKeys = <String, String>{};
      final enKeys = enMap.keys.where((k) => !k.startsWith('@'));

      for (final key in enKeys) {
        if (whitelist.contains(key)) continue;
        final enVal = enMap[key]?.toString() ?? '';
        if (zhPattern.hasMatch(enVal)) {
          leakedKeys[key] = enVal;
        }
      }

      expect(leakedKeys, isEmpty, reason: '英文 ARB 文件中发现意外中文字符: $leakedKeys');
    });
  });
}
