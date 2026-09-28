import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Markdown AST 解析结果模型
class MarkdownParsedDocument {
  const MarkdownParsedDocument({
    required this.blocks,
    this.tocItems = const [],
  });

  final List<MarkdownBlock> blocks;
  final List<MarkdownTocItem> tocItems;
}

/// 目录项模型
class MarkdownTocItem {
  const MarkdownTocItem({
    required this.id,
    required this.title,
    required this.level,
  });

  final String id;
  final String title;
  final int level;
}

/// Markdown AST 块级抽象基类
abstract class MarkdownBlock {
  const MarkdownBlock();
  bool matchesQuery(String query);
}

/// 标题块
class MarkdownHeadingBlock extends MarkdownBlock {
  const MarkdownHeadingBlock({
    required this.level,
    required this.title,
    required this.tokens,
    required this.anchorId,
    required this.slug,
  });

  final int level;
  final String title;
  final List<MarkdownInlineToken> tokens;
  final String anchorId;
  final String slug;

  @override
  bool matchesQuery(String query) =>
      title.toLowerCase().contains(query.toLowerCase());
}

/// 段落块
class MarkdownParagraphBlock extends MarkdownBlock {
  const MarkdownParagraphBlock({required this.text, required this.tokens});

  final String text;
  final List<MarkdownInlineToken> tokens;

  @override
  bool matchesQuery(String query) =>
      text.toLowerCase().contains(query.toLowerCase());
}

/// Callout 提示框类型
enum MarkdownCalloutType { note, tip, important, warning, quote }

/// Callout 提示卡片块
class MarkdownCalloutBlock extends MarkdownBlock {
  const MarkdownCalloutBlock({
    required this.type,
    required this.content,
    required this.tokens,
  });

  final MarkdownCalloutType type;
  final String content;
  final List<MarkdownInlineToken> tokens;

  @override
  bool matchesQuery(String query) =>
      content.toLowerCase().contains(query.toLowerCase());
}

/// 列表项模型
class MarkdownListItem {
  const MarkdownListItem({
    required this.text,
    required this.tokens,
    this.indent = 0,
  });

  final String text;
  final List<MarkdownInlineToken> tokens;
  final int indent;
}

/// 列表块
class MarkdownListBlock extends MarkdownBlock {
  const MarkdownListBlock({required this.items, required this.isOrdered});

  final List<MarkdownListItem> items;
  final bool isOrdered;

  @override
  bool matchesQuery(String query) => items.any(
        (item) => item.text.toLowerCase().contains(query.toLowerCase()),
      );
}

/// 表格块
class MarkdownTableBlock extends MarkdownBlock {
  const MarkdownTableBlock({
    required this.headers,
    required this.headerTokens,
    required this.rows,
    required this.rowTokens,
  });

  final List<String> headers;
  final List<List<MarkdownInlineToken>> headerTokens;
  final List<List<String>> rows;
  final List<List<List<MarkdownInlineToken>>> rowTokens;

  @override
  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    if (headers.any((h) => h.toLowerCase().contains(q))) return true;
    for (final row in rows) {
      if (row.any((cell) => cell.toLowerCase().contains(q))) return true;
    }
    return false;
  }
}

/// 代码块
class MarkdownCodeBlock extends MarkdownBlock {
  const MarkdownCodeBlock({required this.language, required this.code});

  final String language;
  final String code;

  @override
  bool matchesQuery(String query) =>
      code.toLowerCase().contains(query.toLowerCase());
}

/// 分割线块
class MarkdownDividerBlock extends MarkdownBlock {
  const MarkdownDividerBlock();

  @override
  bool matchesQuery(String query) => false;
}

/// 行内 Token 模型
class MarkdownInlineToken {
  const MarkdownInlineToken({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
    this.isCode = false,
    this.isStrikethrough = false,
    this.linkUrl,
  });

  final String text;
  final bool isBold;
  final bool isItalic;
  final bool isCode;
  final bool isStrikethrough;
  final String? linkUrl;
}

/// Slug 工具函数
String markdownSlugify(String input) {
  return input
      .toLowerCase()
      .replaceAll(
        RegExp(r'[\*\`_\[\]\(\)（）\.\:\：\,\，\?\？\/\#]'),
        '',
      )
      .replaceAll(RegExp(r'\s+'), '-')
      .trim();
}

/// 行内 Token 词法切分器
List<MarkdownInlineToken> tokenizeMarkdownInline(String input) {
  final tokens = <MarkdownInlineToken>[];
  final regex = RegExp(
    r'(\*{3}(.+?)\*{3})|'
    r'(\*{2}(.+?)\*{2})|'
    r'(\*(.+?)\*)|'
    r'(`([^`]+)`)|'
    r'(\[([^\]]+)\]\(([^)]+)\))|'
    r'(~~(.+?)~~)',
  );

  int lastIndex = 0;
  for (final match in regex.allMatches(input)) {
    if (match.start > lastIndex) {
      tokens.add(
        MarkdownInlineToken(text: input.substring(lastIndex, match.start)),
      );
    }
    if (match.group(2) != null) {
      tokens.add(
        MarkdownInlineToken(
          text: match.group(2)!,
          isBold: true,
          isItalic: true,
        ),
      );
    } else if (match.group(4) != null) {
      tokens.add(
        MarkdownInlineToken(text: match.group(4)!, isBold: true),
      );
    } else if (match.group(6) != null) {
      tokens.add(
        MarkdownInlineToken(text: match.group(6)!, isItalic: true),
      );
    } else if (match.group(8) != null) {
      tokens.add(
        MarkdownInlineToken(text: match.group(8)!, isCode: true),
      );
    } else if (match.group(10) != null) {
      tokens.add(
        MarkdownInlineToken(
          text: match.group(10)!,
          linkUrl: match.group(11)!,
        ),
      );
    } else if (match.group(13) != null) {
      tokens.add(
        MarkdownInlineToken(
          text: match.group(13)!,
          isStrikethrough: true,
        ),
      );
    }
    lastIndex = match.end;
  }
  if (lastIndex < input.length) {
    tokens.add(MarkdownInlineToken(text: input.substring(lastIndex)));
  }
  return tokens;
}

/// 解析 Callout
MarkdownCalloutBlock parseMarkdownCallout(String text) {
  MarkdownCalloutType type = MarkdownCalloutType.quote;
  String cleanText = text;

  if (text.startsWith('[!NOTE]')) {
    type = MarkdownCalloutType.note;
    cleanText = text.replaceFirst('[!NOTE]', '').trim();
  } else if (text.startsWith('[!TIP]')) {
    type = MarkdownCalloutType.tip;
    cleanText = text.replaceFirst('[!TIP]', '').trim();
  } else if (text.startsWith('[!IMPORTANT]')) {
    type = MarkdownCalloutType.important;
    cleanText = text.replaceFirst('[!IMPORTANT]', '').trim();
  } else if (text.startsWith('[!WARNING]') || text.startsWith('[!CAUTION]')) {
    type = MarkdownCalloutType.warning;
    cleanText = text
        .replaceFirst('[!WARNING]', '')
        .replaceFirst('[!CAUTION]', '')
        .trim();
  }

  return MarkdownCalloutBlock(
    type: type,
    content: cleanText,
    tokens: tokenizeMarkdownInline(cleanText),
  );
}

/// 解析 Markdown 表格
MarkdownTableBlock? parseMarkdownTable(List<String> lines) {
  if (lines.length < 2) return null;

  List<String> extractRow(String line) {
    final parts = line.split('|');
    if (parts.length < 3) return [];
    return parts.sublist(1, parts.length - 1).map((c) => c.trim()).toList();
  }

  final headers = extractRow(lines[0]);
  if (headers.isEmpty) return null;

  final rows = <List<String>>[];
  for (int i = 2; i < lines.length; i++) {
    final row = extractRow(lines[i]);
    if (row.isNotEmpty) {
      rows.add(row);
    }
  }

  final headerTokens = headers.map(tokenizeMarkdownInline).toList();
  final rowTokens =
      rows.map((r) => r.map(tokenizeMarkdownInline).toList()).toList();

  return MarkdownTableBlock(
    headers: headers,
    headerTokens: headerTokens,
    rows: rows,
    rowTokens: rowTokens,
  );
}

/// 全局通用的轻量 Markdown AST 解析器
MarkdownParsedDocument parseMarkdownDocument(String content) {
  final lines = content.split('\n');
  final blocks = <MarkdownBlock>[];
  final tocItems = <MarkdownTocItem>[];

  int index = 0;
  int sectionCounter = 0;

  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      index++;
      continue;
    }

    if (trimmed == '---' || trimmed == '***') {
      blocks.add(const MarkdownDividerBlock());
      index++;
      continue;
    }

    if (trimmed.startsWith('#')) {
      int level = 0;
      while (level < trimmed.length && trimmed[level] == '#') {
        level++;
      }
      if (level <= 4 && trimmed.length > level && trimmed[level] == ' ') {
        final title = trimmed.substring(level + 1).trim();
        sectionCounter++;
        final anchorId = 'sec_$sectionCounter';
        final slug = markdownSlugify(title);
        final headingBlock = MarkdownHeadingBlock(
          level: level,
          title: title,
          tokens: tokenizeMarkdownInline(title),
          anchorId: anchorId,
          slug: slug,
        );
        blocks.add(headingBlock);

        final isTocHeading = title.contains('目录') ||
            title.toLowerCase().contains('table of contents');
        if (level <= 3 && !isTocHeading) {
          tocItems.add(
            MarkdownTocItem(id: anchorId, title: title, level: level),
          );
        }
        index++;
        continue;
      }
    }

    if (trimmed.startsWith('>')) {
      final calloutLines = <String>[];
      while (index < lines.length && lines[index].trim().startsWith('>')) {
        final cur = lines[index].trim();
        calloutLines.add(cur.substring(1).trim());
        index++;
      }
      final calloutBlock = parseMarkdownCallout(calloutLines.join('\n'));
      blocks.add(calloutBlock);
      continue;
    }

    if (trimmed.startsWith('```')) {
      final lang = trimmed.substring(3).trim();
      final codeLines = <String>[];
      index++;
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        codeLines.add(lines[index]);
        index++;
      }
      if (index < lines.length) index++;
      blocks.add(MarkdownCodeBlock(language: lang, code: codeLines.join('\n')));
      continue;
    }

    if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
      final tableLines = <String>[];
      while (index < lines.length &&
          lines[index].trim().startsWith('|') &&
          lines[index].trim().endsWith('|')) {
        tableLines.add(lines[index].trim());
        index++;
      }
      final tableBlock = parseMarkdownTable(tableLines);
      if (tableBlock != null) {
        blocks.add(tableBlock);
      }
      continue;
    }

    if (trimmed.startsWith('- ') ||
        trimmed.startsWith('* ') ||
        RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
      final isOrdered = RegExp(r'^\d+\.\s').hasMatch(trimmed);
      final listItems = <MarkdownListItem>[];

      while (index < lines.length) {
        final cur = lines[index];
        final curTrimmed = cur.trim();
        if (curTrimmed.isEmpty) break;

        final indent = cur.length - cur.trimLeft().length;

        if (curTrimmed.startsWith('- ') || curTrimmed.startsWith('* ')) {
          final t = curTrimmed.substring(2).trim();
          listItems.add(
            MarkdownListItem(
              text: t,
              tokens: tokenizeMarkdownInline(t),
              indent: indent,
            ),
          );
          index++;
        } else if (RegExp(r'^\d+\.\s').hasMatch(curTrimmed)) {
          final dotIdx = curTrimmed.indexOf('. ');
          final t = curTrimmed.substring(dotIdx + 2).trim();
          listItems.add(
            MarkdownListItem(
              text: t,
              tokens: tokenizeMarkdownInline(t),
              indent: indent,
            ),
          );
          index++;
        } else {
          break;
        }
      }

      blocks.add(MarkdownListBlock(items: listItems, isOrdered: isOrdered));
      continue;
    }

    final paragraphLines = <String>[];
    while (index < lines.length) {
      final cur = lines[index];
      final curTrimmed = cur.trim();
      if (curTrimmed.isEmpty ||
          curTrimmed.startsWith('#') ||
          curTrimmed.startsWith('>') ||
          curTrimmed.startsWith('```') ||
          (curTrimmed.startsWith('|') && curTrimmed.endsWith('|')) ||
          curTrimmed.startsWith('- ') ||
          curTrimmed.startsWith('* ') ||
          RegExp(r'^\d+\.\s').hasMatch(curTrimmed) ||
          curTrimmed == '---' ||
          curTrimmed == '***') {
        break;
      }
      paragraphLines.add(curTrimmed);
      index++;
    }

    if (paragraphLines.isNotEmpty) {
      final pText = paragraphLines.join(' ');
      blocks.add(
        MarkdownParagraphBlock(
          text: pText,
          tokens: tokenizeMarkdownInline(pText),
        ),
      );
    } else {
      if (index < lines.length) {
        final singleLine = lines[index].trim();
        if (singleLine.isNotEmpty) {
          blocks.add(
            MarkdownParagraphBlock(
              text: singleLine,
              tokens: tokenizeMarkdownInline(singleLine),
            ),
          );
        }
        index++;
      }
    }
  }

  return MarkdownParsedDocument(blocks: blocks, tocItems: tocItems);
}

/// 通用 Markdown 渲染视图，支持段落、各级标题、列表、提示框 (Callouts)、代码块及表格。
class MarkdownContentView extends StatelessWidget {
  const MarkdownContentView({
    super.key,
    this.content,
    this.parsedDocument,
    this.searchQuery = '',
    this.onLinkTap,
    this.headingKeys,
    this.sectionKeys,
    this.compact = false,
  }) : assert(
          content != null || parsedDocument != null,
          'Either content or parsedDocument must be provided',
        );

  final String? content;
  final MarkdownParsedDocument? parsedDocument;
  final String searchQuery;
  final void Function(String url)? onLinkTap;
  final Map<MarkdownHeadingBlock, GlobalKey>? headingKeys;
  final Map<String, GlobalKey>? sectionKeys;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final doc = parsedDocument ?? parseMarkdownDocument(content!);
    final blocks = searchQuery.isEmpty
        ? doc.blocks
        : doc.blocks.where((b) => b.matchesQuery(searchQuery)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((block) {
        GlobalKey? secKey;
        if (block is MarkdownHeadingBlock) {
          secKey = headingKeys?[block] ?? sectionKeys?[block.anchorId];
        }
        return MarkdownBlockWidget(
          block: block,
          sectionKey: secKey,
          searchQuery: searchQuery,
          onLinkTap: onLinkTap,
          compact: compact,
        );
      }).toList(),
    );
  }
}

/// Markdown 块级渲染组件
class MarkdownBlockWidget extends StatelessWidget {
  const MarkdownBlockWidget({
    super.key,
    required this.block,
    this.sectionKey,
    this.searchQuery = '',
    this.onLinkTap,
    this.compact = false,
  });

  final MarkdownBlock block;
  final GlobalKey? sectionKey;
  final String searchQuery;
  final void Function(String url)? onLinkTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    final child = sectionKey != null
        ? KeyedSubtree(key: sectionKey, child: content)
        : content;
    return RepaintBoundary(child: child);
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(fontFamilyFallback: AppTheme.fontFamilyFallback);

    if (block is MarkdownHeadingBlock) {
      final b = block as MarkdownHeadingBlock;
      final double fontSize;
      final double topMargin;

      switch (b.level) {
        case 1:
          fontSize = compact ? 18 : 24;
          topMargin = compact ? 16 : 32;
        case 2:
          fontSize = compact ? 16 : 20;
          topMargin = compact ? 14 : 26;
        case 3:
          fontSize = compact ? 14.5 : 16.5;
          topMargin = compact ? 10 : 18;
        default:
          fontSize = compact ? 13.5 : 15;
          topMargin = compact ? 8 : 14;
      }

      return Padding(
        padding: EdgeInsets.only(top: topMargin, bottom: compact ? 4 : 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MarkdownInlineTextView(
              tokens: b.tokens,
              style: baseStyle.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
              searchQuery: searchQuery,
              onLinkTap: onLinkTap,
            ),
            if (b.level == 1 && !compact)
              Container(
                margin: const EdgeInsets.only(top: 6),
                height: 3,
                width: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(
                    AppTokens.sheetGrabberRadius,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (block is MarkdownParagraphBlock) {
      final b = block as MarkdownParagraphBlock;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
        child: MarkdownInlineTextView(
          tokens: b.tokens,
          style: baseStyle.copyWith(
            fontSize:
                compact ? AppTokens.textBodySize : AppTokens.textSecondarySize,
            height: compact ? 1.45 : 1.65,
            color: colorScheme.onSurface.withValues(
              alpha: AppTokens.alphaOverlayHeavy,
            ),
          ),
          searchQuery: searchQuery,
          onLinkTap: onLinkTap,
        ),
      );
    }

    if (block is MarkdownDividerBlock) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 16),
        child: Divider(
          color: colorScheme.outlineVariant.withValues(
            alpha: AppTokens.alphaBorderEmphasis,
          ),
          thickness: 1,
        ),
      );
    }

    if (block is MarkdownCalloutBlock) {
      final b = block as MarkdownCalloutBlock;
      Color calloutColor;
      IconData calloutIcon;
      String title;

      switch (b.type) {
        case MarkdownCalloutType.note:
          calloutColor = colorScheme.primary;
          calloutIcon = Icons.info_outline;
          title = 'NOTE';
        case MarkdownCalloutType.tip:
          calloutColor = Colors.teal;
          calloutIcon = Icons.lightbulb_outline;
          title = 'TIP';
        case MarkdownCalloutType.important:
          calloutColor = Colors.deepOrange;
          calloutIcon = Icons.priority_high;
          title = 'IMPORTANT';
        case MarkdownCalloutType.warning:
          calloutColor = Colors.amber.shade800;
          calloutIcon = Icons.warning_amber_rounded;
          title = 'WARNING';
        case MarkdownCalloutType.quote:
          calloutColor = colorScheme.outline;
          calloutIcon = Icons.format_quote;
          title = '';
      }

      return Container(
        margin: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: BoxDecoration(
          color: calloutColor.withValues(alpha: AppTokens.alphaTintFaint),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border(
            left: BorderSide(color: calloutColor, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Row(
                children: [
                  Icon(calloutIcon, size: 16, color: calloutColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTokens.textFootnoteSize,
                      fontWeight: FontWeight.w800,
                      color: calloutColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            MarkdownInlineTextView(
              tokens: b.tokens,
              style: baseStyle.copyWith(
                fontSize: compact
                    ? AppTokens.textBodySize
                    : AppTokens.textSecondarySize,
                height: 1.55,
                color: colorScheme.onSurface,
              ),
              searchQuery: searchQuery,
              onLinkTap: onLinkTap,
            ),
          ],
        ),
      );
    }

    if (block is MarkdownListBlock) {
      final b = block as MarkdownListBlock;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: b.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final bullet = b.isOrdered ? '${idx + 1}.' : '•';
            return Padding(
              padding: EdgeInsets.only(
                left: item.indent * 16.0,
                bottom: compact ? 3 : 5,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: b.isOrdered ? 22 : 14,
                    child: Text(
                      bullet,
                      style: TextStyle(
                        fontSize: compact
                            ? AppTokens.textBodySize
                            : AppTokens.textSecondarySize,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: MarkdownInlineTextView(
                      tokens: item.tokens,
                      style: baseStyle.copyWith(
                        fontSize: compact
                            ? AppTokens.textBodySize
                            : AppTokens.textSecondarySize,
                        height: compact ? 1.4 : 1.55,
                        color: colorScheme.onSurface.withValues(
                          alpha: AppTokens.alphaOverlayHeavy,
                        ),
                      ),
                      searchQuery: searchQuery,
                      onLinkTap: onLinkTap,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      );
    }

    if (block is MarkdownCodeBlock) {
      final b = block as MarkdownCodeBlock;
      return Container(
        margin: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaContentMuted),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(
              alpha: AppTokens.alphaBorderEmphasis,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (b.language.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaCardFrostedLight),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTokens.radiusCard),
                    topRight: Radius.circular(AppTokens.radiusCard),
                  ),
                ),
                child: Text(
                  b.language,
                  style: TextStyle(
                    fontSize: AppTokens.textCaptionSize,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                b.code,
                style: TextStyle(
                  fontFamily: AppTokens.fontMonoFamily,
                  fontFamilyFallback: AppTokens.fontMonoFallback,
                  fontSize: AppTokens.textBodySize,
                  height: 1.45,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (block is MarkdownTableBlock) {
      final b = block as MarkdownTableBlock;
      return Container(
        margin: EdgeInsets.symmetric(vertical: compact ? 6 : 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(
              alpha: AppTokens.alphaBorderEmphasis,
            ),
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder(
              horizontalInside: BorderSide(
                color: colorScheme.outlineVariant.withValues(
                  alpha: AppTokens.alphaBorderEmphasis,
                ),
              ),
              verticalInside: BorderSide(
                color: colorScheme.outlineVariant.withValues(
                  alpha: AppTokens.alphaBorderEmphasis,
                ),
              ),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.6,
                  ),
                ),
                children: b.headerTokens.map((tokens) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: MarkdownInlineTextView(
                      tokens: tokens,
                      style: baseStyle.copyWith(
                        fontSize: compact
                            ? AppTokens.textCaptionSize
                            : AppTokens.textBodySize,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      searchQuery: searchQuery,
                      onLinkTap: onLinkTap,
                    ),
                  );
                }).toList(),
              ),
              ...b.rowTokens.map((rowTokens) {
                return TableRow(
                  children: rowTokens.map((tokens) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      child: MarkdownInlineTextView(
                        tokens: tokens,
                        style: baseStyle.copyWith(
                          fontSize: compact
                              ? AppTokens.textCaptionSize
                              : AppTokens.textBodySize,
                          color: colorScheme.onSurface,
                        ),
                        searchQuery: searchQuery,
                        onLinkTap: onLinkTap,
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// 行内 Markdown 文本渲染组件
class MarkdownInlineTextView extends StatelessWidget {
  const MarkdownInlineTextView({
    super.key,
    required this.tokens,
    required this.style,
    required this.searchQuery,
    this.onLinkTap,
  });

  final List<MarkdownInlineToken> tokens;
  final TextStyle style;
  final String searchQuery;
  final void Function(String url)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final hasLinks = tokens.any((t) => t.linkUrl != null);
    if (hasLinks && onLinkTap != null) {
      return _MarkdownInteractiveInlineText(
        tokens: tokens,
        style: style,
        searchQuery: searchQuery,
        onLinkTap: onLinkTap!,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spans = <InlineSpan>[];

    for (final token in tokens) {
      TextStyle tokenStyle = style;
      if (token.isBold) {
        tokenStyle = tokenStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        );
      }
      if (token.isItalic) {
        tokenStyle = tokenStyle.copyWith(fontStyle: FontStyle.italic);
      }
      if (token.isStrikethrough) {
        tokenStyle = tokenStyle.copyWith(
          decoration: TextDecoration.lineThrough,
        );
      }
      if (token.isCode) {
        tokenStyle = tokenStyle.copyWith(
          fontFamily: AppTokens.fontMonoFamily,
          fontFamilyFallback: AppTokens.fontMonoFallback,
          fontSize: (tokenStyle.fontSize ?? 14.0) * 0.92,
          color: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.8,
          ),
        );
      }

      if (searchQuery.isNotEmpty &&
          token.text.toLowerCase().contains(searchQuery.toLowerCase())) {
        final lowerText = token.text.toLowerCase();
        final lowerQuery = searchQuery.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerText.indexOf(lowerQuery, start);
          if (idx < 0) {
            if (start < token.text.length) {
              spans.add(
                TextSpan(text: token.text.substring(start), style: tokenStyle),
              );
            }
            break;
          }
          if (idx > start) {
            spans.add(
              TextSpan(
                text: token.text.substring(start, idx),
                style: tokenStyle,
              ),
            );
          }
          final matchText = token.text.substring(idx, idx + searchQuery.length);
          spans.add(
            TextSpan(
              text: matchText,
              style: tokenStyle.copyWith(
                backgroundColor: Colors.amber.withValues(
                  alpha: AppTokens.alphaContentDisabled,
                ),
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
          start = idx + searchQuery.length;
        }
      } else {
        spans.add(TextSpan(text: token.text, style: tokenStyle));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class _MarkdownInteractiveInlineText extends StatefulWidget {
  const _MarkdownInteractiveInlineText({
    required this.tokens,
    required this.style,
    required this.searchQuery,
    required this.onLinkTap,
  });

  final List<MarkdownInlineToken> tokens;
  final TextStyle style;
  final String searchQuery;
  final void Function(String url) onLinkTap;

  @override
  State<_MarkdownInteractiveInlineText> createState() =>
      _MarkdownInteractiveInlineTextState();
}

class _MarkdownInteractiveInlineTextState
    extends State<_MarkdownInteractiveInlineText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spans = <InlineSpan>[];

    for (final token in widget.tokens) {
      TextStyle tokenStyle = widget.style;
      if (token.isBold) {
        tokenStyle = tokenStyle.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        );
      }
      if (token.isItalic) {
        tokenStyle = tokenStyle.copyWith(fontStyle: FontStyle.italic);
      }
      if (token.isStrikethrough) {
        tokenStyle = tokenStyle.copyWith(
          decoration: TextDecoration.lineThrough,
        );
      }
      if (token.isCode) {
        tokenStyle = tokenStyle.copyWith(
          fontFamily: AppTokens.fontMonoFamily,
          fontFamilyFallback: AppTokens.fontMonoFallback,
          fontSize: (tokenStyle.fontSize ?? 14.0) * 0.92,
          color: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.8,
          ),
        );
      }

      TapGestureRecognizer? recognizer;
      if (token.linkUrl != null) {
        tokenStyle = tokenStyle.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: colorScheme.primary.withValues(
            alpha: AppTokens.alphaContentMuted,
          ),
        );
        final r = TapGestureRecognizer()
          ..onTap = () => widget.onLinkTap(token.linkUrl!);
        _recognizers.add(r);
        recognizer = r;
      }

      if (widget.searchQuery.isNotEmpty &&
          token.text.toLowerCase().contains(widget.searchQuery.toLowerCase())) {
        final lowerText = token.text.toLowerCase();
        final lowerQuery = widget.searchQuery.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerText.indexOf(lowerQuery, start);
          if (idx < 0) {
            if (start < token.text.length) {
              spans.add(
                TextSpan(
                  text: token.text.substring(start),
                  style: tokenStyle,
                  recognizer: recognizer,
                ),
              );
            }
            break;
          }
          if (idx > start) {
            spans.add(
              TextSpan(
                text: token.text.substring(start, idx),
                style: tokenStyle,
                recognizer: recognizer,
              ),
            );
          }
          final matchText = token.text.substring(
            idx,
            idx + widget.searchQuery.length,
          );
          spans.add(
            TextSpan(
              text: matchText,
              style: tokenStyle.copyWith(
                backgroundColor: Colors.amber.withValues(
                  alpha: AppTokens.alphaContentDisabled,
                ),
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
              recognizer: recognizer,
            ),
          );
          start = idx + widget.searchQuery.length;
        }
      } else {
        spans.add(
          TextSpan(text: token.text, style: tokenStyle, recognizer: recognizer),
        );
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}
