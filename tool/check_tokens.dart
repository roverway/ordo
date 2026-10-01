// tool/check_tokens.dart
//
// 令牌纪律守卫（Token discipline guard）
// 依据：docs/90-ux-visual-refactor-proposal.md §5「防再漂移机制」
//
// 背景：用于对已达成清零目标的 6 类令牌禁忌进行零容忍断言：
//   - bare-font-size: 禁止裸 fontSize: 数值字面量
//   - bare-color: 禁止 Color(0x...) 裸色值
//   - bare-alpha: 禁止 withValues(alpha: ...) 裸透明度
//   - bare-radius: 禁止 Radius.circular(...) 裸圆角
//   - monospace-font: 禁止硬编码 fontFamily: 'monospace'
//   - bare-duration: 禁止 Duration(milliseconds: ...) 裸动效时长
//
// 当前状态：该 6 项违规在全库已彻底清零，当前以 --strict（零容忍）模式常驻运行，
// 任何新增直接阻断提交与流水线。
//
// 用法：
//   dart run tool/check_tokens.dart                 报告当前违规分布（退出码 0）
//   dart run tool/check_tokens.dart --list          额外列出每条规则的前 5 个样本
//   dart run tool/check_tokens.dart --max N         棘轮模式：总数超过 N 则失败（退出码 1）
//   dart run tool/check_tokens.dart --strict        零容忍模式：任何违规即失败（默认流水线启用，退出码 1）
//
// 计数口径：
//   - 排除 lib/core/theme/（令牌定义本身）与 lib/core/utils/motion.dart（动效入口）
//   - 按出现次数计：同一行出现两次算两处
//
// 本脚本零外部依赖，只用 dart:io。

import 'dart:io';

/// 扫描根目录。
const String _scanRoot = 'lib';

/// 白名单目录：令牌定义本身允许出现裸值。
const List<String> _excludedDirs = <String>[
  'lib/core/theme', // app_tokens.dart / app_theme.dart —— 令牌单一真源
];

/// 白名单文件：动效统一入口，其内部需要定义时长常量。
const List<String> _excludedFiles = <String>['lib/core/utils/motion.dart'];

/// 一条守卫规则。
class _Rule {
  const _Rule(this.id, this.description, this.pattern, this.fix);

  /// 规则标识（报告用）。
  final String id;

  /// 人类可读描述。
  final String description;

  /// 命中模式。
  final RegExp pattern;

  /// 修复指引。
  final String fix;
}

/// 全部规则。与 docs/90 §5 的 banned 模式清单一一对应。
final List<_Rule> _rules = <_Rule>[
  _Rule(
    'bare-font-size',
    '裸字号字面量',
    RegExp(r'fontSize:\s*[0-9]'),
    '改用 AppTokens 的 text*Size 令牌（docs/90 §3.2）',
  ),
  _Rule(
    'bare-color',
    '裸色值字面量',
    RegExp(r'Color\(0x[0-9A-Fa-f]'),
    '改用 AppTokens 色板或 colorScheme（docs/90 §3.7 的禁用灰阶）',
  ),
  _Rule(
    'bare-alpha',
    '裸透明度字面量',
    RegExp(r'withValues\(alpha:\s*0?\.\d'),
    '改用 AppTokens 的 alpha* 语义令牌（docs/90 §3.3）',
  ),
  _Rule(
    'bare-radius',
    '裸圆角字面量',
    RegExp(r'Radius\.circular\(\s*[0-9]'),
    '改用 AppTokens 的 radius* 令牌（docs/90 §3.4）',
  ),
  _Rule(
    'monospace-font',
    "硬编码 fontFamily: 'monospace'",
    RegExp(r""""fontFamily:\s*['"]monospace['"]"""),
    '改用正文字体 + AppTokens.fontTabular，或 AppTokens.fontMonoFamily 栈（docs/90 §3.6）',
  ),
  _Rule(
    'bare-duration',
    '裸动效时长字面量',
    RegExp(r'Duration\(milliseconds:\s*[0-9]'),
    '改用 motion.dart 的 motionFast / motionNormal / motionSlow（docs/90 §2.4）',
  ),
];

/// 命中记录。
class _Hit {
  const _Hit(this.ruleId, this.file, this.line, this.text);

  final String ruleId;
  final String file;
  final int line;
  final String text;
}

void main(List<String> args) {
  final bool listSamples = args.contains('--list');
  final bool strict = args.contains('--strict');
  final int? max = _parseMax(args);

  final Directory root = Directory(_scanRoot);
  if (!root.existsSync()) {
    stderr.writeln('[check_tokens] 找不到目录 $_scanRoot，请在仓库根目录运行。');
    exit(2);
  }

  final List<_Hit> hits = <_Hit>[];
  int scannedFiles = 0;

  for (final FileSystemEntity entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;

    final String path = _normalize(entity.path);
    if (_isExcluded(path)) continue;
    scannedFiles++;

    final List<String> lines;
    try {
      lines = entity.readAsLinesSync();
    } on FileSystemException {
      continue;
    }

    for (int i = 0; i < lines.length; i++) {
      final String raw = lines[i];
      if (_isCommentLine(raw)) continue; // 注释里的示例不算违规

      for (final _Rule rule in _rules) {
        // 按出现次数计（与 docs/90 附录 B 的 `grep -o` 口径一致）：
        // 同一行命中两次就记两处。改成 hasMatch 会得到「行数」，两者仅 bare-color 不同。
        for (final RegExpMatch _ in rule.pattern.allMatches(raw)) {
          hits.add(_Hit(rule.id, path, i + 1, raw.trim()));
        }
      }
    }
  }

  _printReport(hits, scannedFiles, listSamples);

  if (strict && hits.isNotEmpty) {
    stderr.writeln('\n[check_tokens] --strict：发现 ${hits.length} 处违规，失败。');
    exit(1);
  }
  if (max != null && hits.length > max) {
    stderr.writeln(
      '\n[check_tokens] 棘轮失败：当前 ${hits.length} 处 > 预算上限 $max 处。'
      '\n               新增了令牌违规，请改用 AppTokens 令牌（docs/90 §5）。',
    );
    exit(1);
  }
  if (max != null) {
    stdout.writeln(
      '\n棘轮：${hits.length} / $max 处'
      '（余量 ${max - hits.length}）。完成迁移后请下调 --max。',
    );
  }
}

/// 解析 `--max <n>` / `--max=<n>`。
int? _parseMax(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    final String a = args[i];
    if (a == '--max' && i + 1 < args.length) {
      return int.tryParse(args[i + 1]);
    }
    if (a.startsWith('--max=')) {
      return int.tryParse(a.substring('--max='.length));
    }
  }
  return null;
}

/// 统一为 `lib/...` 正斜杠形式，便于与白名单比较。
String _normalize(String path) => path.replaceAll(r'\', '/');

/// 是否位于白名单。
bool _isExcluded(String path) {
  for (final String dir in _excludedDirs) {
    if (path.startsWith('$dir/')) return true;
  }
  return _excludedFiles.contains(path);
}

/// 是否为纯注释行（避免把文档里的示例当成违规）。
bool _isCommentLine(String line) {
  final String t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

/// 打印报告。
void _printReport(List<_Hit> hits, int scannedFiles, bool listSamples) {
  stdout.writeln('令牌纪律守卫 — 扫描 $_scanRoot/**/*.dart');
  stdout.writeln(
    '（已排除 ${_excludedDirs.join('、')} 与 ${_excludedFiles.length} 个白名单文件）',
  );
  stdout.writeln('扫描文件数：$scannedFiles');
  stdout.writeln('');

  const String idHeader = '规则';
  stdout.writeln('${_pad(idHeader, 18)}${_pad('命中', 8)}说明');
  stdout.writeln('${'-' * 18}${'-' * 8}${'-' * 40}');

  final Map<String, int> byRule = <String, int>{};
  for (final _Hit h in hits) {
    byRule[h.ruleId] = (byRule[h.ruleId] ?? 0) + 1;
  }

  for (final _Rule rule in _rules) {
    final int count = byRule[rule.id] ?? 0;
    final String mark = count == 0 ? 'OK' : 'FAIL';
    stdout.writeln(
      '${_pad(rule.id, 18)}${_pad('$count', 8)}$mark  ${rule.description}',
    );
    if (count > 0) {
      stdout.writeln('${' ' * 26}→ ${rule.fix}');
    }
  }

  stdout.writeln('');
  stdout.writeln('合计违规：${hits.length} 处');
  stdout.writeln('（口径：出现次数，已排除 lib/core/theme 与 motion.dart）');

  if (listSamples && hits.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln('样本（每规则最多 5 条）：');
    final Map<String, List<_Hit>> grouped = <String, List<_Hit>>{};
    for (final _Hit h in hits) {
      grouped.putIfAbsent(h.ruleId, () => <_Hit>[]).add(h);
    }
    for (final _Rule rule in _rules) {
      final List<_Hit>? group = grouped[rule.id];
      if (group == null) continue;
      stdout.writeln('  [${rule.id}]');
      for (final _Hit h in group.take(5)) {
        stdout.writeln('    ${h.file}:${h.line}  ${_truncate(h.text, 72)}');
      }
    }
  }
}

/// 右侧补空格（中文字符按 2 列计，够用即可）。
String _pad(String s, int width) {
  int visual = 0;
  for (final int rune in s.runes) {
    visual += rune > 0x2E80 ? 2 : 1;
  }
  final int fill = width - visual;
  return fill > 0 ? s + ' ' * fill : '$s ';
}

/// 截断过长行。
String _truncate(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max)}…';
