import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import 'settings_providers.dart';

/// 知序 Ordo 用户使用手册页面
///
/// 具备能力：
/// 1. 原生 Markdown 轻量化 AST 解析与行内格式化（粗体、斜体、代码、超链接锚点跳转）；
/// 2. 响应式布局自适应：
///    - 宽屏（>= 900dp）：左侧固定宽度（280dp）展开目录树（Table of Contents），右侧正文平滑定位；
///    - 窄屏（< 900dp）：正文全屏阅读，底部悬浮目录按钮唤起 Draggable 目录抽屉；
/// 3. 本地化联动：默认跟随应用系统语言（zh / en），标题栏提供即时「中 / EN」切换；
/// 4. 实时搜索过滤与关键字高亮展示；
/// 5. 目录与正文内锚点超链接点击 100% 精准平滑滚动跳转；
/// 6. 零外部第三方排版依赖，100% 契合应用设计令牌（AppTokens）与动态深浅主题。
class UserManualPage extends ConsumerStatefulWidget {
  const UserManualPage({
    super.key,
    this.customContentLoader,
  });

  /// 可选的手册内容加载器（用于单元测试或自定义数据源注入，若为空则从应用 AssetBundle 加载）
  final Future<String> Function(String lang)? customContentLoader;

  @override
  ConsumerState<UserManualPage> createState() => _UserManualPageState();
}

class _UserManualPageState extends ConsumerState<UserManualPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedLanguage; // null 表示跟随全局 localeProvider
  bool _isLoading = true;
  String? _errorMessage;

  List<_ManualBlock> _blocks = [];
  List<_TocItem> _tocItems = [];

  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<_HeadingBlock, GlobalKey> _headingKeys = {};
  final Map<GlobalKey, String> _keyToSectionId = {};

  String? _activeSectionId;
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadManual();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _getEffectiveLanguage() {
    if (_selectedLanguage != null) return _selectedLanguage!;
    final appLocale = ref.read(localeProvider);
    return appLocale.languageCode == 'en' ? 'en' : 'zh';
  }

  Future<void> _loadManual() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final lang = _getEffectiveLanguage();
    final assetPath = lang == 'en'
        ? 'assets/docs/user_manual_en.md'
        : 'assets/docs/user_manual_zh.md';

    try {
      final String content;
      if (widget.customContentLoader != null) {
        content = await widget.customContentLoader!(lang);
      } else {
        content = await rootBundle.loadString(assetPath);
      }
      final parsed = _parseMarkdown(content);
      if (mounted) {
        setState(() {
          _blocks = parsed.blocks;
          _tocItems = parsed.tocItems;
          _sectionKeys.clear();
          _headingKeys.clear();
          _keyToSectionId.clear();

          for (final block in _blocks) {
            if (block is _HeadingBlock) {
              final key = GlobalKey();
              _sectionKeys[block.anchorId] = key;
              _headingKeys[block] = key;
              _keyToSectionId[key] = block.anchorId;
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onLanguageChanged(String lang) {
    if (_selectedLanguage == lang) return;
    setState(() {
      _selectedLanguage = lang;
    });
    _loadManual();
  }

  GlobalKey? _resolveSectionKey(String target) {
    String clean = target.trim();
    if (clean.startsWith('#')) {
      clean = clean.substring(1).trim();
    }
    if (clean.isEmpty) return null;

    // 1. 直接通过 sectionId 匹配 (如 sec_1)
    if (_sectionKeys.containsKey(clean)) {
      return _sectionKeys[clean];
    }

    // 2. 通过 slug 精准匹配
    final cleanSlug = _slugify(clean);
    for (final entry in _headingKeys.entries) {
      if (entry.key.slug == cleanSlug || entry.key.slug == clean) {
        return entry.value;
      }
    }

    // 3. 通过标题内容或子集匹配
    for (final entry in _headingKeys.entries) {
      final hSlug = entry.key.slug;
      if (hSlug.contains(cleanSlug) || cleanSlug.contains(hSlug)) {
        return entry.value;
      }
      final hTitleClean = _slugify(entry.key.title);
      if (hTitleClean == cleanSlug || hTitleClean.contains(cleanSlug)) {
        return entry.value;
      }
    }

    return null;
  }

  void _scrollToSection(String sectionIdOrSlug) {
    // 若当前正在搜索状态，退出搜索以便展示全部内容
    if (_isSearching || _searchQuery.isNotEmpty) {
      setState(() {
        _isSearching = false;
        _searchQuery = '';
        _searchController.clear();
      });
    }

    void doScroll() {
      final key = _resolveSectionKey(sectionIdOrSlug);
      final ctx = key?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: AppTokens.motionSlow,
          curve: Curves.easeOutCubic,
          alignment: 0.0,
        );
        final foundId = _keyToSectionId[key];
        if (foundId != null && mounted) {
          setState(() {
            _activeSectionId = foundId;
          });
        }
      }
    }

    doScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
  }

  void _showTocBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppTokens.sheetTopBorderRadius,
      ),
      builder: (ctx) {
        return SafeArea(
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (ctx, scrollController) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.sheetGrabberRadius),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.manualTOC,
                          style: const TextStyle(
                            fontSize: AppTokens.textSubtitleSize,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _tocItems.length,
                      itemBuilder: (context, index) {
                        final item = _tocItems[index];
                        final isSelected = item.id == _activeSectionId;
                        return _TocListTile(
                          item: item,
                          isSelected: isSelected,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _scrollToSection(item.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final currentLang = _getEffectiveLanguage();

    final isWide = AppBreakpoints.isDualPane(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: colorScheme.onSurface, fontSize: AppTokens.textSubtitleSize),
                decoration: InputDecoration(
                  hintText: l10n.manualSearchHint,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: AppTokens.alphaContentMuted),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              )
            : Text(
                l10n.settingsHelp,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? l10n.clear : l10n.manualSearchHint,
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageChip(
                    label: '中',
                    isActive: currentLang == 'zh',
                    onTap: () => _onLanguageChanged('zh'),
                  ),
                  _LanguageChip(
                    label: 'EN',
                    isActive: currentLang == 'en',
                    onTap: () => _onLanguageChanged('en'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: (!isWide && !_isLoading && _errorMessage == null)
          ? FloatingActionButton.extended(
              onPressed: () => _showTocBottomSheet(context),
              icon: const Icon(Icons.toc_rounded),
              label: Text(l10n.manualTOC),
            )
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadManual,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = AppBreakpoints.isDualPane(context);

    final filteredBlocks = _searchQuery.isEmpty
        ? _blocks
        : _blocks.where((b) => b.matchesQuery(_searchQuery)).toList();

    // 正文滚动视图：采用 SingleChildScrollView + Column 挂载全部节点，
    // 杜绝 ListView.builder 懒回收导致屏幕外节点 GlobalKey 无法定位的问题。
    final contentScrollView = SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 20,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...filteredBlocks.map((block) {
            GlobalKey? secKey;
            if (block is _HeadingBlock) {
              secKey = _headingKeys[block] ?? _sectionKeys[block.anchorId];
            }
            return _BlockWidget(
              block: block,
              sectionKey: secKey,
              searchQuery: _searchQuery,
              onLinkTap: _scrollToSection,
            );
          }),
          // 底部追加弹性滚动空隙，确保末尾章节（如 FAQ）能平滑滚动至视口顶端
          const SizedBox(height: 320),
        ],
      ),
    );

    if (!isWide) {
      return contentScrollView;
    }

    // 宽屏模式：左侧常驻目录树 + 右侧居中正文
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: AppTokens.alphaBorderEmphasis),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.manualTOC,
                          style: const TextStyle(
                            fontSize: AppTokens.textSecondarySize,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tocItems.length,
                    itemBuilder: (context, index) {
                      final item = _tocItems[index];
                      final isSelected = item.id == _activeSectionId;
                      return _TocListTile(
                        item: item,
                        isSelected: isSelected,
                        onTap: () => _scrollToSection(item.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: contentScrollView,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Markdown AST 解析器
  // -------------------------------------------------------------
  _ParsedManual _parseMarkdown(String content) {
    final lines = content.split('\n');
    final blocks = <_ManualBlock>[];
    final tocItems = <_TocItem>[];

    int index = 0;
    int sectionCounter = 0;

    while (index < lines.length) {
      final line = lines[index];
      final trimmed = line.trim();

      // 空行跳过
      if (trimmed.isEmpty) {
        index++;
        continue;
      }

      // 分割线 (--- 或 ***)
      if (trimmed == '---' || trimmed == '***') {
        blocks.add(const _DividerBlock());
        index++;
        continue;
      }

      // 标题 (#, ##, ###, ####)
      if (trimmed.startsWith('#')) {
        int level = 0;
        while (level < trimmed.length && trimmed[level] == '#') {
          level++;
        }
        if (level <= 4 && trimmed.length > level && trimmed[level] == ' ') {
          final title = trimmed.substring(level + 1).trim();
          sectionCounter++;
          final anchorId = 'sec_$sectionCounter';
          final slug = _slugify(title);
          final headingBlock = _HeadingBlock(
            level: level,
            title: title,
            tokens: _tokenizeInline(title),
            anchorId: anchorId,
            slug: slug,
          );
          blocks.add(headingBlock);

          // 过滤掉文内“目录”标题本身，避免目录中递归展示“目录”
          final isTocHeading = title.contains('目录') ||
              title.toLowerCase().contains('table of contents');
          if (level <= 3 && !isTocHeading) {
            tocItems.add(_TocItem(id: anchorId, title: title, level: level));
          }
          index++;
          continue;
        }
      }

      // 引用块与提示卡片 (> [!NOTE], > [!TIP], > [!IMPORTANT], > [!WARNING], > Quote)
      if (trimmed.startsWith('>')) {
        final calloutLines = <String>[];
        while (index < lines.length && lines[index].trim().startsWith('>')) {
          final cur = lines[index].trim();
          calloutLines.add(cur.substring(1).trim());
          index++;
        }
        final calloutBlock = _parseCallout(calloutLines.join('\n'));
        blocks.add(calloutBlock);
        continue;
      }

      // 代码块 (```mermaid 或 ```)
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        final codeLines = <String>[];
        index++;
        while (index < lines.length && !lines[index].trim().startsWith('```')) {
          codeLines.add(lines[index]);
          index++;
        }
        if (index < lines.length) index++; // 跳过结束的三反引号
        blocks.add(_CodeBlock(language: lang, code: codeLines.join('\n')));
        continue;
      }

      // 表格 (| col1 | col2 |)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final tableLines = <String>[];
        while (index < lines.length &&
            lines[index].trim().startsWith('|') &&
            lines[index].trim().endsWith('|')) {
          tableLines.add(lines[index].trim());
          index++;
        }
        final tableBlock = _parseTable(tableLines);
        if (tableBlock != null) {
          blocks.add(tableBlock);
        }
        continue;
      }

      // 无序列表与有序列表 (- item, * item, 1. item)
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final isOrdered = RegExp(r'^\d+\.\s').hasMatch(trimmed);
        final listItems = <_ListItem>[];

        while (index < lines.length) {
          final cur = lines[index];
          final curTrimmed = cur.trim();
          if (curTrimmed.isEmpty) break;

          final indent = cur.length - cur.trimLeft().length;

          if (curTrimmed.startsWith('- ') || curTrimmed.startsWith('* ')) {
            final t = curTrimmed.substring(2).trim();
            listItems.add(_ListItem(
              text: t,
              tokens: _tokenizeInline(t),
              indent: indent,
            ));
            index++;
          } else if (RegExp(r'^\d+\.\s').hasMatch(curTrimmed)) {
            final dotIdx = curTrimmed.indexOf('. ');
            final t = curTrimmed.substring(dotIdx + 2).trim();
            listItems.add(_ListItem(
              text: t,
              tokens: _tokenizeInline(t),
              indent: indent,
            ));
            index++;
          } else {
            break;
          }
        }

        blocks.add(_ListBlock(items: listItems, isOrdered: isOrdered));
        continue;
      }

      // 普通段落
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
        blocks.add(_ParagraphBlock(
          text: pText,
          tokens: _tokenizeInline(pText),
        ));
      } else {
        if (index < lines.length) {
          final singleLine = lines[index].trim();
          if (singleLine.isNotEmpty) {
            blocks.add(_ParagraphBlock(
              text: singleLine,
              tokens: _tokenizeInline(singleLine),
            ));
          }
          index++;
        }
      }
    }

    return _ParsedManual(blocks: blocks, tocItems: tocItems);
  }

  _CalloutBlock _parseCallout(String text) {
    _CalloutType type = _CalloutType.quote;
    String cleanText = text;

    if (text.startsWith('[!NOTE]')) {
      type = _CalloutType.note;
      cleanText = text.replaceFirst('[!NOTE]', '').trim();
    } else if (text.startsWith('[!TIP]')) {
      type = _CalloutType.tip;
      cleanText = text.replaceFirst('[!TIP]', '').trim();
    } else if (text.startsWith('[!IMPORTANT]')) {
      type = _CalloutType.important;
      cleanText = text.replaceFirst('[!IMPORTANT]', '').trim();
    } else if (text.startsWith('[!WARNING]') || text.startsWith('[!CAUTION]')) {
      type = _CalloutType.warning;
      cleanText = text
          .replaceFirst('[!WARNING]', '')
          .replaceFirst('[!CAUTION]', '')
          .trim();
    }

    return _CalloutBlock(
      type: type,
      content: cleanText,
      tokens: _tokenizeInline(cleanText),
    );
  }

  _TableBlock? _parseTable(List<String> lines) {
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

    final headerTokens = headers.map(_tokenizeInline).toList();
    final rowTokens = rows.map((r) => r.map(_tokenizeInline).toList()).toList();

    return _TableBlock(
      headers: headers,
      headerTokens: headerTokens,
      rows: rows,
      rowTokens: rowTokens,
    );
  }
}

// -------------------------------------------------------------
// Slug 生成工具
// -------------------------------------------------------------
String _slugify(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r'[\*\`_\[\]\(\)\（\）\.\:\：\,\，\?\？\/\\\#]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .trim();
}

// -------------------------------------------------------------
class _ParsedManual {
  const _ParsedManual({required this.blocks, required this.tocItems});
  final List<_ManualBlock> blocks;
  final List<_TocItem> tocItems;
}

// AST 块定义与数据模型
// -------------------------------------------------------------
abstract class _ManualBlock {
  const _ManualBlock();
  bool matchesQuery(String query);
}

class _HeadingBlock extends _ManualBlock {
  const _HeadingBlock({
    required this.level,
    required this.title,
    required this.tokens,
    required this.anchorId,
    required this.slug,
  });
  final int level;
  final String title;
  final List<_InlineToken> tokens;
  final String anchorId;
  final String slug;

  @override
  bool matchesQuery(String query) =>
      title.toLowerCase().contains(query.toLowerCase());
}

class _ParagraphBlock extends _ManualBlock {
  const _ParagraphBlock({required this.text, required this.tokens});
  final String text;
  final List<_InlineToken> tokens;

  @override
  bool matchesQuery(String query) =>
      text.toLowerCase().contains(query.toLowerCase());
}

enum _CalloutType { note, tip, important, warning, quote }

class _CalloutBlock extends _ManualBlock {
  const _CalloutBlock({
    required this.type,
    required this.content,
    required this.tokens,
  });
  final _CalloutType type;
  final String content;
  final List<_InlineToken> tokens;

  @override
  bool matchesQuery(String query) =>
      content.toLowerCase().contains(query.toLowerCase());
}

class _ListItem {
  const _ListItem({
    required this.text,
    required this.tokens,
    this.indent = 0,
  });
  final String text;
  final List<_InlineToken> tokens;
  final int indent;
}

class _ListBlock extends _ManualBlock {
  const _ListBlock({required this.items, required this.isOrdered});
  final List<_ListItem> items;
  final bool isOrdered;

  @override
  bool matchesQuery(String query) => items.any(
        (item) => item.text.toLowerCase().contains(query.toLowerCase()),
      );
}

class _TableBlock extends _ManualBlock {
  const _TableBlock({
    required this.headers,
    required this.headerTokens,
    required this.rows,
    required this.rowTokens,
  });
  final List<String> headers;
  final List<List<_InlineToken>> headerTokens;
  final List<List<String>> rows;
  final List<List<List<_InlineToken>>> rowTokens;

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

class _CodeBlock extends _ManualBlock {
  const _CodeBlock({required this.language, required this.code});
  final String language;
  final String code;

  @override
  bool matchesQuery(String query) =>
      code.toLowerCase().contains(query.toLowerCase());
}

class _DividerBlock extends _ManualBlock {
  const _DividerBlock();

  @override
  bool matchesQuery(String query) => false;
}

class _TocItem {
  const _TocItem({
    required this.id,
    required this.title,
    required this.level,
  });
  final String id;
  final String title;
  final int level;
}

// -------------------------------------------------------------
// Markdown 行内分词与富文本渲染
// -------------------------------------------------------------
class _InlineToken {
  const _InlineToken({
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

List<_InlineToken> _tokenizeInline(String input) {
  final tokens = <_InlineToken>[];
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
      tokens.add(_InlineToken(text: input.substring(lastIndex, match.start)));
    }
    if (match.group(2) != null) {
      tokens.add(_InlineToken(
        text: match.group(2)!,
        isBold: true,
        isItalic: true,
      ));
    } else if (match.group(4) != null) {
      tokens.add(_InlineToken(text: match.group(4)!, isBold: true));
    } else if (match.group(6) != null) {
      tokens.add(_InlineToken(text: match.group(6)!, isItalic: true));
    } else if (match.group(8) != null) {
      tokens.add(_InlineToken(text: match.group(8)!, isCode: true));
    } else if (match.group(10) != null) {
      tokens.add(_InlineToken(
        text: match.group(10)!,
        linkUrl: match.group(11)!,
      ));
    } else if (match.group(13) != null) {
      tokens.add(_InlineToken(text: match.group(13)!, isStrikethrough: true));
    }
    lastIndex = match.end;
  }
  if (lastIndex < input.length) {
    tokens.add(_InlineToken(text: input.substring(lastIndex)));
  }
  return tokens;
}

class _MarkdownInlineText extends StatelessWidget {
  const _MarkdownInlineText({
    required this.tokens,
    required this.style,
    required this.searchQuery,
    this.onLinkTap,
  });

  final List<_InlineToken> tokens;
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

      // 处理搜索词高亮
      if (searchQuery.isNotEmpty &&
          token.text.toLowerCase().contains(searchQuery.toLowerCase())) {
        final lowerText = token.text.toLowerCase();
        final lowerQuery = searchQuery.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerText.indexOf(lowerQuery, start);
          if (idx < 0) {
            if (start < token.text.length) {
              spans.add(TextSpan(
                text: token.text.substring(start),
                style: tokenStyle,
              ));
            }
            break;
          }
          if (idx > start) {
            spans.add(TextSpan(
              text: token.text.substring(start, idx),
              style: tokenStyle,
            ));
          }
          final matchText = token.text.substring(idx, idx + searchQuery.length);
          spans.add(TextSpan(
            text: matchText,
            style: tokenStyle.copyWith(
              backgroundColor: Colors.amber.withValues(alpha: AppTokens.alphaContentDisabled),
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ));
          start = idx + searchQuery.length;
        }
      } else {
        spans.add(TextSpan(
          text: token.text,
          style: tokenStyle,
        ));
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

  final List<_InlineToken> tokens;
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
          decorationColor: colorScheme.primary.withValues(alpha: AppTokens.alphaContentMuted),
        );
        final r = TapGestureRecognizer()
          ..onTap = () => widget.onLinkTap(token.linkUrl!);
        _recognizers.add(r);
        recognizer = r;
      }

      // 处理搜索词高亮
      if (widget.searchQuery.isNotEmpty &&
          token.text.toLowerCase().contains(widget.searchQuery.toLowerCase())) {
        final lowerText = token.text.toLowerCase();
        final lowerQuery = widget.searchQuery.toLowerCase();
        int start = 0;
        while (true) {
          final idx = lowerText.indexOf(lowerQuery, start);
          if (idx < 0) {
            if (start < token.text.length) {
              spans.add(TextSpan(
                text: token.text.substring(start),
                style: tokenStyle,
                recognizer: recognizer,
              ));
            }
            break;
          }
          if (idx > start) {
            spans.add(TextSpan(
              text: token.text.substring(start, idx),
              style: tokenStyle,
              recognizer: recognizer,
            ));
          }
          final matchText = token.text.substring(
            idx,
            idx + widget.searchQuery.length,
          );
          spans.add(TextSpan(
            text: matchText,
            style: tokenStyle.copyWith(
              backgroundColor: Colors.amber.withValues(alpha: AppTokens.alphaContentDisabled),
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
            recognizer: recognizer,
          ));
          start = idx + widget.searchQuery.length;
        }
      } else {
        spans.add(TextSpan(
          text: token.text,
          style: tokenStyle,
          recognizer: recognizer,
        ));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusChip - 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusChip - 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTokens.textCaptionSize,
            fontWeight: FontWeight.w700,
            color: isActive
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TocListTile extends StatelessWidget {
  const _TocListTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _TocItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLevel1 = item.level == 1;
    final isLevel2 = item.level == 2;

    double leftPadding = 16.0;
    if (isLevel2) leftPadding = 30.0;
    if (item.level >= 3) leftPadding = 44.0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          leftPadding,
          isLevel1 ? 10 : 7,
          16,
          isLevel1 ? 10 : 7,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: AppTokens.alphaTintSoft)
              : Colors.transparent,
          border: isSelected
              ? Border(left: BorderSide(color: colorScheme.primary, width: 3))
              : null,
        ),
        child: Row(
          children: [
            if (isLevel1) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: AppTokens.alphaContentMuted),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: isLevel1 ? 13.5 : (isLevel2 ? 12.5 : 11.5),
                  fontWeight: isLevel1 || isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.primary
                      : (isLevel1
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Markdown 块级渲染组件
// -------------------------------------------------------------
class _BlockWidget extends StatelessWidget {
  const _BlockWidget({
    required this.block,
    this.sectionKey,
    required this.searchQuery,
    this.onLinkTap,
  });

  final _ManualBlock block;
  final GlobalKey? sectionKey;
  final String searchQuery;
  final void Function(String url)? onLinkTap;

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
    final baseStyle = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      fontFamilyFallback: AppTheme.fontFamilyFallback,
    );

    if (block is _HeadingBlock) {
      final b = block as _HeadingBlock;
      final double fontSize;
      final double topMargin;

      switch (b.level) {
        case 1:
          fontSize = 24;
          topMargin = 32;
        case 2:
          fontSize = 20;
          topMargin = 26;
        case 3:
          fontSize = 16.5;
          topMargin = 18;
        default:
          fontSize = 15;
          topMargin = 14;
      }

      return Padding(
        padding: EdgeInsets.only(top: topMargin, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MarkdownInlineText(
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
            if (b.level == 1)
              Container(
                margin: const EdgeInsets.only(top: 6),
                height: 3,
                width: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppTokens.sheetGrabberRadius),
                ),
              ),
          ],
        ),
      );
    }

    if (block is _ParagraphBlock) {
      final b = block as _ParagraphBlock;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _MarkdownInlineText(
          tokens: b.tokens,
          style: baseStyle.copyWith(
            fontSize: AppTokens.textSecondarySize,
            height: 1.65,
            color: colorScheme.onSurface.withValues(alpha: AppTokens.alphaOverlayHeavy),
          ),
          searchQuery: searchQuery,
          onLinkTap: onLinkTap,
        ),
      );
    }

    if (block is _CalloutBlock) {
      final b = block as _CalloutBlock;
      final Color borderColor;
      final Color bgColor;
      final IconData iconData;
      final String calloutTitle;

      switch (b.type) {
        case _CalloutType.note:
          borderColor = Colors.blue;
          bgColor = Colors.blue.withValues(alpha: AppTokens.alphaTintFaint);
          iconData = Icons.info_outline;
          calloutTitle = 'NOTE';
        case _CalloutType.tip:
          borderColor = Colors.teal;
          bgColor = Colors.teal.withValues(alpha: AppTokens.alphaTintFaint);
          iconData = Icons.lightbulb_outline;
          calloutTitle = 'TIP';
        case _CalloutType.important:
          borderColor = Colors.purple;
          bgColor = Colors.purple.withValues(alpha: AppTokens.alphaTintFaint);
          iconData = Icons.priority_high;
          calloutTitle = 'IMPORTANT';
        case _CalloutType.warning:
          borderColor = Colors.amber.shade700;
          bgColor = Colors.amber.withValues(alpha: AppTokens.alphaTintFaint);
          iconData = Icons.warning_amber_rounded;
          calloutTitle = 'WARNING';
        case _CalloutType.quote:
          borderColor = colorScheme.outlineVariant;
          bgColor = colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaBorderEmphasis);
          iconData = Icons.format_quote;
          calloutTitle = '';
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: borderColor.withValues(alpha: AppTokens.alphaBorderEmphasis),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                color: borderColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (calloutTitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(iconData, size: 16, color: borderColor),
                              const SizedBox(width: 6),
                              Text(
                                calloutTitle,
                                style: TextStyle(
                                  fontSize: AppTokens.textCaptionSize,
                                  fontWeight: FontWeight.w800,
                                  color: borderColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      _MarkdownInlineText(
                        tokens: b.tokens,
                        style: baseStyle.copyWith(
                          fontSize: AppTokens.textFootnoteSize,
                          height: 1.6,
                          fontStyle: b.type == _CalloutType.quote
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: colorScheme.onSurface,
                        ),
                        searchQuery: searchQuery,
                        onLinkTap: onLinkTap,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (block is _ListBlock) {
      final b = block as _ListBlock;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(b.items.length, (i) {
            final item = b.items[i];
            return Padding(
              padding: EdgeInsets.only(
                left: item.indent * 10.0 + 4.0,
                top: 3,
                bottom: 3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      b.isOrdered ? '${i + 1}.' : '•',
                      style: TextStyle(
                        fontSize: b.isOrdered ? 13 : 16,
                        height: 1.3,
                        fontWeight:
                            b.isOrdered ? FontWeight.w600 : FontWeight.w900,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MarkdownInlineText(
                      tokens: item.tokens,
                      style: baseStyle.copyWith(
                        fontSize: AppTokens.textSecondarySize,
                        height: 1.55,
                        color: colorScheme.onSurface,
                      ),
                      searchQuery: searchQuery,
                      onLinkTap: onLinkTap,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      );
    }

    if (block is _TableBlock) {
      final b = block as _TableBlock;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: AppTokens.alphaContentMuted),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaContentMuted),
            ),
            columns: List.generate(
              b.headers.length,
              (colIdx) => DataColumn(
                label: _MarkdownInlineText(
                  tokens: b.headerTokens[colIdx],
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                  searchQuery: searchQuery,
                  onLinkTap: onLinkTap,
                ),
              ),
            ),
            rows: List.generate(
              b.rows.length,
              (rowIdx) => DataRow(
                cells: List.generate(
                  b.rows[rowIdx].length,
                  (colIdx) => DataCell(
                    _MarkdownInlineText(
                      tokens: b.rowTokens[rowIdx][colIdx],
                      style: baseStyle.copyWith(
                        fontSize: AppTokens.textFootnoteSize,
                        color: colorScheme.onSurface,
                      ),
                      searchQuery: searchQuery,
                      onLinkTap: onLinkTap,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (block is _CodeBlock) {
      final b = block as _CodeBlock;
      if (b.language.toLowerCase() == 'mermaid') {
        return _MermaidFlowWidget(code: b.code);
      }
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaContentMuted),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: AppTokens.alphaContentDisabled),
          ),
        ),
        width: double.infinity,
        child: SelectableText(
          b.code,
          style: const TextStyle(
            fontFamily: AppTokens.fontMonoFamily,
            fontFamilyFallback: AppTokens.fontMonoFallback,
            fontSize: AppTokens.textCaptionSize,
            height: 1.45,
          ),
        ),
      );
    }

    if (block is _DividerBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(
          color: colorScheme.outlineVariant.withValues(alpha: AppTokens.alphaBorderEmphasis),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
class _MermaidFlowWidget extends StatefulWidget {
  const _MermaidFlowWidget({required this.code});
  final String code;

  @override
  State<_MermaidFlowWidget> createState() => _MermaidFlowWidgetState();
}

class _MermaidFlowWidgetState extends State<_MermaidFlowWidget> {
  bool _showRawCode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEn = widget.code.contains('Subtasks Cluster Status');

    final title = isEn
        ? 'Task State Derivation Flowchart'
        : '子任务集群与父任务状态派生流向图';
    final rootLabel = isEn ? 'Subtasks Cluster Status' : '子任务集群状态';
    final ruleLabel = isEn ? 'Derivation Rules' : '状态联动规则判定';

    final branches = isEn
        ? [
            (
              '🟢 All [Done]',
              'Parent becomes [Done] (100%)',
              Colors.green,
            ),
            (
              '🟡 Any [In Progress] or partial',
              'Parent becomes [In Progress] (shows ring)',
              Colors.amber,
            ),
            (
              '⚪ All [Todo]',
              'Parent stays [Todo] (0%)',
              Colors.blueGrey,
            ),
            (
              '🔴 All [Canceled]',
              'Parent becomes [Canceled]',
              Colors.red,
            ),
          ]
        : [
            (
              '🟢 全部子任务【已完成】',
              '父任务自动变为【已完成】(100%)',
              Colors.green,
            ),
            (
              '🟡 任意子任务【进行中】或【部分完成】',
              '父任务自动变为【进行中】(显示进度环)',
              Colors.amber,
            ),
            (
              '⚪ 全部子任务处于【待办】',
              '父任务保持【待办】(0%)',
              Colors.blueGrey,
            ),
            (
              '🔴 全部子任务均为【已取消】',
              '父任务自动变为【已取消】',
              Colors.red,
            ),
          ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaBorderEmphasis),
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: AppTokens.alphaContentDisabled),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标头与源码切换
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTokens.textFootnoteSize,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showRawCode = !_showRawCode;
                    });
                  },
                  icon: Icon(
                    _showRawCode ? Icons.visibility_off : Icons.code,
                    size: 14,
                  ),
                  label: Text(
                    _showRawCode
                        ? (isEn ? 'Hide Code' : '隐藏源码')
                        : (isEn ? 'View Code' : '查看源码'),
                    style: const TextStyle(fontSize: AppTokens.textCaptionSize),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 核心可视化流程树
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              children: [
                // 顶层根节点
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: AppTokens.alphaContentMuted),
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: AppTokens.alphaContentDisabled),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.dashboard_customize_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rootLabel,
                        style: TextStyle(
                          fontSize: AppTokens.textFootnoteSize,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 18,
                  color: colorScheme.primary.withValues(alpha: AppTokens.alphaScrim),
                ),
                const SizedBox(height: 6),

                // 中间规则判定节点
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: AppTokens.alphaContentMuted),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alt_route_rounded,
                        size: 15,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ruleLabel,
                        style: TextStyle(
                          fontSize: AppTokens.textCaptionSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4 个状态分支卡片
                ...branches.map((b) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border(
                        left: BorderSide(color: b.$3, width: 3.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          b.$1,
                          style: TextStyle(
                            fontSize: AppTokens.textCaptionSize,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b.$2,
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // 源码展开抽屉
          if (_showRawCode) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: AppTokens.alphaContentMuted),
              child: SelectableText(
                widget.code,
                style: const TextStyle(
                  fontFamily: AppTokens.fontMonoFamily,
                  fontFamilyFallback: AppTokens.fontMonoFallback,
                  fontSize: AppTokens.textCaptionSize,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
