import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import 'settings_providers.dart';

/// 知序 Ordo 用户使用手册页面
///
/// 具备能力：
/// 1. 原生 Markdown 轻量化 AST 解析（分段、标题、强调、列表、表格、代码块、引用与 GitHub 样式 Callout 警告卡片）；
/// 2. 响应式布局自适应：
///    - 宽屏（>= 900dp）：左侧固定宽度（280dp）展开目录树（Table of Contents），右侧正文平滑定位；
///    - 窄屏（< 900dp）：正文全屏阅读，底部悬浮目录按钮唤起 Draggable 目录抽屉；
/// 3. 本地化联动：默认跟随应用系统语言（zh / en），标题栏提供即时「中 / EN」切换；
/// 4. 实时搜索过滤与关键字黄色高亮展示；
/// 5. 零外部三方排版依赖，100% 契合应用设计令牌（AppTokens）与动态深浅主题。
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
          for (final item in _tocItems) {
            _sectionKeys[item.id] = GlobalKey();
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

  void _scrollToSection(String sectionId) {
    final key = _sectionKeys[sectionId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
      setState(() {
        _activeSectionId = sectionId;
      });
    }
  }

  void _showTocBottomSheet(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
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
                          style: theme.textTheme.titleMedium?.copyWith(
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
                      itemCount: _tocItems.length,
                      itemBuilder: (ctx, index) {
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentLang = _getEffectiveLanguage();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.manualSearchHint,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                style: const TextStyle(fontSize: 15),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim();
                  });
                },
              )
            : Text(
                l10n.settingsHelp,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? '关闭搜索' : '搜索内容',
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
          // 中英文快速切换胶囊组件
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageBadge(
                    label: '中',
                    isActive: currentLang == 'zh',
                    onTap: () => _onLanguageChanged('zh'),
                  ),
                  _LanguageBadge(
                    label: 'EN',
                    isActive: currentLang == 'en',
                    onTap: () => _onLanguageChanged('en'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(context),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = MediaQuery.of(context).size.width >= 900;
          if (isWide ||
              _isLoading ||
              _errorMessage != null ||
              _tocItems.isEmpty) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _showTocBottomSheet(context),
            icon: const Icon(Icons.list_alt_rounded, size: 20),
            label: Text(l10n.manualTOC),
            elevation: 3,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.manualLoading,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                l10n.manualLoadFailed,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadManual,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 900;

    final filteredBlocks = _searchQuery.isEmpty
        ? _blocks
        : _blocks.where((b) => b.matchesQuery(_searchQuery)).toList();

    Widget contentList = ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 40 : 20, vertical: 24),
      itemCount: filteredBlocks.length,
      itemBuilder: (context, index) {
        final block = filteredBlocks[index];
        GlobalKey? secKey;
        if (block is _HeadingBlock) {
          secKey = _sectionKeys[block.anchorId];
        }
        return _BlockWidget(
          block: block,
          sectionKey: secKey,
          searchQuery: _searchQuery,
        );
      },
    );

    if (!isWide) {
      return contentList;
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
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                      Text(
                        l10n.manualTOC,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
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
              child: contentList,
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
          blocks.add(
            _HeadingBlock(level: level, title: title, anchorId: anchorId),
          );
          if (level <= 3) {
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
          final raw = lines[index].trim().substring(1).trim();
          calloutLines.add(raw);
          index++;
        }
        final fullCalloutText = calloutLines.join('\n');
        blocks.add(_parseCallout(fullCalloutText));
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
        if (tableLines.length >= 2) {
          final table = _parseTable(tableLines);
          if (table != null) {
            blocks.add(table);
            continue;
          }
        }
      }

      // 代码块 (``` ... ```)
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        index++;
        final codeLines = <String>[];
        while (index < lines.length && !lines[index].trim().startsWith('```')) {
          codeLines.add(lines[index]);
          index++;
        }
        if (index < lines.length) {
          index++;
        } // 跳过闭合 ```
        blocks.add(_CodeBlock(language: lang, code: codeLines.join('\n')));
        continue;
      }

      // 列表项 (- 或 * 或 1. )
      if (trimmed.startsWith('- ') ||
          trimmed.startsWith('* ') ||
          RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        final listItems = <String>[];
        bool isOrdered = RegExp(r'^\d+\.\s').hasMatch(trimmed);

        while (index < lines.length) {
          final curTrimmed = lines[index].trim();
          if (curTrimmed.isEmpty) break;
          if (curTrimmed.startsWith('- ') || curTrimmed.startsWith('* ')) {
            listItems.add(curTrimmed.substring(2).trim());
            index++;
          } else if (RegExp(r'^\d+\.\s').hasMatch(curTrimmed)) {
            final dotIdx = curTrimmed.indexOf('. ');
            listItems.add(curTrimmed.substring(dotIdx + 2).trim());
            index++;
          } else {
            break;
          }
        }
        blocks.add(_ListBlock(items: listItems, isOrdered: isOrdered));
        continue;
      }

      // 普通段落（累积直到遇到空行、标题、表格、代码块等）
      final paragraphLines = <String>[];
      while (index < lines.length) {
        final cur = lines[index].trim();
        if (cur.isEmpty ||
            cur.startsWith('#') ||
            cur.startsWith('>') ||
            cur.startsWith('```') ||
            cur.startsWith('|') ||
            cur.startsWith('- ') ||
            cur.startsWith('* ') ||
            RegExp(r'^\d+\.\s').hasMatch(cur) ||
            cur == '---' ||
            cur == '***') {
          break;
        }
        paragraphLines.add(cur);
        index++;
      }
      if (paragraphLines.isNotEmpty) {
        blocks.add(_ParagraphBlock(text: paragraphLines.join(' ')));
      } else {
        // 安全保护：确保 index 一定推进，防止死循环
        if (index < lines.length) {
          final singleLine = lines[index].trim();
          if (singleLine.isNotEmpty) {
            blocks.add(_ParagraphBlock(text: singleLine));
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

    return _CalloutBlock(type: type, content: cleanText);
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

    return _TableBlock(headers: headers, rows: rows);
  }
}

// -------------------------------------------------------------
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
    required this.anchorId,
  });
  final int level;
  final String title;
  final String anchorId;

  @override
  bool matchesQuery(String query) =>
      title.toLowerCase().contains(query.toLowerCase());
}

class _ParagraphBlock extends _ManualBlock {
  const _ParagraphBlock({required this.text});
  final String text;

  @override
  bool matchesQuery(String query) =>
      text.toLowerCase().contains(query.toLowerCase());
}

enum _CalloutType { note, tip, important, warning, quote }

class _CalloutBlock extends _ManualBlock {
  const _CalloutBlock({required this.type, required this.content});
  final _CalloutType type;
  final String content;

  @override
  bool matchesQuery(String query) =>
      content.toLowerCase().contains(query.toLowerCase());
}

class _ListBlock extends _ManualBlock {
  const _ListBlock({required this.items, required this.isOrdered});
  final List<String> items;
  final bool isOrdered;

  @override
  bool matchesQuery(String query) =>
      items.any((it) => it.toLowerCase().contains(query.toLowerCase()));
}

class _TableBlock extends _ManualBlock {
  const _TableBlock({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;

  @override
  bool matchesQuery(String query) {
    final q = query.toLowerCase();
    return headers.any((h) => h.toLowerCase().contains(q)) ||
        rows.any((r) => r.any((c) => c.toLowerCase().contains(q)));
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
  const _TocItem({required this.id, required this.title, required this.level});
  final String id;
  final String title;
  final int level;
}

class _ParsedManual {
  _ParsedManual({required this.blocks, required this.tocItems});
  final List<_ManualBlock> blocks;
  final List<_TocItem> tocItems;
}

// -------------------------------------------------------------
// UI 子组件
// -------------------------------------------------------------

/// 语言切换徽章
class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({
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
            fontSize: 12,
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

/// 目录列表项
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
              ? colorScheme.primary.withValues(alpha: 0.1)
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
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

/// 单个 Markdown 块渲染器
class _BlockWidget extends StatelessWidget {
  const _BlockWidget({
    required this.block,
    this.sectionKey,
    required this.searchQuery,
  });

  final _ManualBlock block;
  final GlobalKey? sectionKey;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final widget = _buildContent(context);
    if (sectionKey != null) {
      return Container(key: sectionKey, child: widget);
    }
    return widget;
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (block is _HeadingBlock) {
      final b = block as _HeadingBlock;
      final double topMargin = switch (b.level) {
        1 => 28.0,
        2 => 24.0,
        3 => 18.0,
        _ => 14.0,
      };
      final double fontSize = switch (b.level) {
        1 => 22.0,
        2 => 18.0,
        3 => 15.5,
        _ => 14.0,
      };
      return Padding(
        padding: EdgeInsets.only(top: topMargin, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHighlightText(
              b.title,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.2,
              ),
              searchQuery: searchQuery,
              context: context,
            ),
            if (b.level == 1)
              Container(
                margin: const EdgeInsets.only(top: 6),
                height: 3,
                width: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(1.5),
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
        child: _buildHighlightText(
          b.text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.65,
            color: colorScheme.onSurface.withValues(alpha: 0.92),
          ),
          searchQuery: searchQuery,
          context: context,
        ),
      );
    }

    if (block is _CalloutBlock) {
      final b = block as _CalloutBlock;
      final (color, icon, label) = switch (b.type) {
        _CalloutType.note => (
          Colors.blue,
          Icons.info_outline_rounded,
          '提示 Note',
        ),
        _CalloutType.tip => (
          Colors.teal,
          Icons.lightbulb_outline_rounded,
          '建议 Tip',
        ),
        _CalloutType.important => (
          Colors.purple,
          Icons.star_outline_rounded,
          '重要 Important',
        ),
        _CalloutType.warning => (
          Colors.orange,
          Icons.warning_amber_rounded,
          '警告 Warning',
        ),
        _CalloutType.quote => (
          colorScheme.primary,
          Icons.format_quote_rounded,
          null,
        ),
      };

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            _buildHighlightText(
              b.content,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                fontStyle: b.type == _CalloutType.quote
                    ? FontStyle.italic
                    : FontStyle.normal,
                color: colorScheme.onSurface,
              ),
              searchQuery: searchQuery,
              context: context,
            ),
          ],
        ),
      );
    }

    if (block is _ListBlock) {
      final b = block as _ListBlock;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(b.items.length, (idx) {
            final text = b.items[idx];
            final prefix = b.isOrdered ? '${idx + 1}. ' : '• ';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prefix,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  Expanded(
                    child: _buildHighlightText(
                      text,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: colorScheme.onSurface,
                      ),
                      searchQuery: searchQuery,
                      context: context,
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
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            columns: b.headers
                .map(
                  (h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
            rows: b.rows
                .map(
                  (r) => DataRow(
                    cells: r
                        .map(
                          (cell) => DataCell(
                            _buildHighlightText(
                              cell,
                              style: const TextStyle(fontSize: 13),
                              searchQuery: searchQuery,
                              context: context,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      );
    }

    if (block is _CodeBlock) {
      final b = block as _CodeBlock;
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        width: double.infinity,
        child: SelectableText(
          b.code,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      );
    }

    if (block is _DividerBlock) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Divider(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// 高亮文本构建
  Widget _buildHighlightText(
    String text, {
    required TextStyle style,
    required String searchQuery,
    required BuildContext context,
  }) {
    if (searchQuery.isEmpty) {
      return Text(text, style: style);
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();
    final spans = <InlineSpan>[];

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              text.substring(index, index + searchQuery.length),
              style: style.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      );

      start = index + searchQuery.length;
    }

    return RichText(text: TextSpan(children: spans));
  }
}
