import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import 'logs_provider.dart';
import '../../../shared/domain/app_models.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _searchController = TextEditingController();
  Timer? _autoRefreshTimer;
  int? _autoRefreshSeconds;

  static const _autoRefreshOptions = [10, 30, 60, 300];

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(logsProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(title: '日志', subtitle: 'system trace'),
        actions: [
          asyncState.maybeWhen(
            data: (state) => state.loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新列表',
                    onPressed: () =>
                        ref.read(logsProvider.notifier).refreshList(),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: '清理旧日志',
            onPressed: () => _confirmCleanup(context),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
              const SizedBox(height: 12),
              Text('加载失败: $e'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(logsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (isWide) {
            return _buildWideLayout(context, state);
          }
          return _buildNarrowLayout(context, state);
        },
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, LogsState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 300,
            child: ConsoleCard(
              title: '日志文件',
              icon: Icons.folder_copy_outlined,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SearchBar(controller: _searchController),
                  Expanded(child: _FileList(state: state, isWide: true)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ConsoleCard(
              title: state.selected ?? '选择日志文件',
              icon: Icons.terminal_outlined,
              trailing: state.selected == null
                  ? null
                  : _ViewerHeaderActions(
                      loading: state.contentLoading,
                      autoRefreshSeconds: _autoRefreshSeconds,
                      autoRefreshOptions: _autoRefreshOptions,
                      onAutoRefreshChanged: (seconds) {
                        setState(() => _autoRefreshSeconds = seconds);
                        _syncAutoRefresh();
                      },
                      onRefresh: () =>
                          ref.read(logsProvider.notifier).refreshSelected(),
                      onClose: () {
                        setState(() => _autoRefreshSeconds = null);
                        _autoRefreshTimer?.cancel();
                        ref.read(logsProvider.notifier).clearSelection();
                      },
                    ),
              padding: EdgeInsets.zero,
              child: _ContentView(state: state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context, LogsState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox.expand(
        child: ConsoleCard(
          title: '日志文件',
          icon: Icons.folder_copy_outlined,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SearchBar(controller: _searchController),
              Expanded(child: _FileList(state: state, isWide: false)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmCleanup(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清理日志'),
        content: const Text('确认清理所有旧日志文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(logsProvider.notifier).cleanup();
            },
            child: const Text('清理', style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }

  void _syncAutoRefresh() {
    _autoRefreshTimer?.cancel();
    final seconds = _autoRefreshSeconds;
    final selected = ref.read(logsProvider).valueOrNull?.selected;
    if (seconds == null || selected == null) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => ref.read(logsProvider.notifier).refreshSelected(),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  final TextEditingController controller;

  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: '搜索日志文件...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    ref.read(logsProvider.notifier).setSearch('');
                  },
                )
              : null,
          isDense: true,
        ),
        onChanged: (v) => ref.read(logsProvider.notifier).setSearch(v),
      ),
    );
  }
}

class _FileList extends ConsumerWidget {
  final LogsState state;
  final bool isWide;

  const _FileList({required this.state, required this.isWide});

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = state.filteredFiles;

    if (files.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        label: '暂无日志文件',
      );
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final isSelected = state.selected == file.name;
        final backgroundColor = isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.12)
            : AppTheme.subtleFill(context).withValues(alpha: 0.44);
        final borderColor = isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.42)
            : AppTheme.borderColor(context);

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Material(
            color: backgroundColor,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: borderColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.description_outlined,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.mutedText(context),
              ),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
              subtitle: Text(
                '${_formatSize(file.size)}  ${_formatDate(file.modifiedTime)}',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppTheme.danger,
                tooltip: '删除',
                onPressed: () => _confirmDelete(context, ref, file),
              ),
              onTap: () {
                if (isWide) {
                  ref.read(logsProvider.notifier).selectFile(file.name);
                } else {
                  ref.read(logsProvider.notifier).selectFile(file.name);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _LogDetailPage(filename: file.name),
                    ),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, LogFileInfo file) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除日志'),
        content: Text('确认删除「${file.name}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(logsProvider.notifier).deleteFile(file.name);
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _ContentView extends ConsumerWidget {
  final LogsState state;

  const _ContentView({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.selected == null) {
      return const EmptyState(
        icon: Icons.terminal_outlined,
        label: '选择左侧文件以查看内容',
      );
    }

    if (state.contentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = state.content ?? '';
    return _LogViewer(content: content, filename: state.selected!);
  }
}

class _ViewerHeaderActions extends StatelessWidget {
  final bool loading;
  final int? autoRefreshSeconds;
  final List<int> autoRefreshOptions;
  final ValueChanged<int?> onAutoRefreshChanged;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  const _ViewerHeaderActions({
    required this.loading,
    required this.autoRefreshSeconds,
    required this.autoRefreshOptions,
    required this.onAutoRefreshChanged,
    required this.onRefresh,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: autoRefreshSeconds,
            hint: const Text('自动刷新', style: TextStyle(fontSize: 12)),
            isDense: true,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('关闭', style: TextStyle(fontSize: 12)),
              ),
              ...autoRefreshOptions.map(
                (seconds) => DropdownMenuItem<int?>(
                  value: seconds,
                  child: Text(
                    seconds >= 60 ? '${seconds ~/ 60}m' : '${seconds}s',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
            onChanged: onAutoRefreshChanged,
          ),
        ),
        IconButton(
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          tooltip: '刷新日志',
          onPressed: loading ? null : onRefresh,
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: '关闭',
          onPressed: onClose,
        ),
      ],
    );
  }
}

enum _LogLevel { error, warn, info, debugLevel, other }

enum _LogFilter { all, error, warn, info, debugLevel }

class _LogViewer extends StatefulWidget {
  final String content;
  final String filename;

  const _LogViewer({required this.content, required this.filename});

  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogLine {
  final String text;
  final int index;
  final _LogLevel level;

  const _LogLine({
    required this.text,
    required this.index,
    required this.level,
  });
}

class _LogViewerState extends State<_LogViewer> {
  final _scrollController = ScrollController();
  final _contentSearchController = TextEditingController();
  String? _cachedContent;
  List<_LogLine> _cachedLines = const [];
  _LogFilter _levelFilter = _LogFilter.all;
  String _searchQuery = '';
  int _matchIndex = 0;
  bool _followMode = false;
  double _fontSize = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void didUpdateWidget(_LogViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.filename != widget.filename) {
      _matchIndex = 0;
      if (_followMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _contentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _buildLines(widget.content);
    final filtered = _filterLines(lines);
    final matches = _matchingLinePositions(filtered);
    final clampedMatch = matches.isEmpty
        ? 0
        : _matchIndex.clamp(0, matches.length - 1).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ViewerToolbar(
          searchController: _contentSearchController,
          searchQuery: _searchQuery,
          matchCount: matches.length,
          matchIndex: clampedMatch,
          levelFilter: _levelFilter,
          followMode: _followMode,
          fontSize: _fontSize,
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value;
              _matchIndex = 0;
            });
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToCurrentMatch(),
            );
          },
          onPreviousMatch: matches.isEmpty
              ? null
              : () {
                  setState(
                    () => _matchIndex = (_matchIndex - 1)
                        .clamp(0, matches.length - 1)
                        .toInt(),
                  );
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToCurrentMatch(),
                  );
                },
          onNextMatch: matches.isEmpty
              ? null
              : () {
                  setState(
                    () => _matchIndex = (_matchIndex + 1)
                        .clamp(0, matches.length - 1)
                        .toInt(),
                  );
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToCurrentMatch(),
                  );
                },
          onFilterChanged: (filter) {
            setState(() {
              _levelFilter = filter;
              _matchIndex = 0;
            });
          },
          onFollowChanged: (value) {
            setState(() => _followMode = value);
            if (value) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _scrollToBottom(),
              );
            }
          },
          onFontSizeChanged: (size) => setState(() => _fontSize = size),
          onCopy: () => _copyContent(context),
        ),
        Divider(height: 1, color: AppTheme.borderColor(context)),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF020617)),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (!_followMode ||
                    notification.metrics.axis != Axis.vertical) {
                  return false;
                }
                final distance =
                    notification.metrics.maxScrollExtent -
                    notification.metrics.pixels;
                if (distance > 40) setState(() => _followMode = false);
                return false;
              },
              child: filtered.isEmpty
                  ? _EmptyLogMessage(
                      label: widget.content.isEmpty ? '(空文件)' : '无匹配日志行',
                      fontSize: _fontSize,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      scrollCacheExtent: const ScrollCacheExtent.pixels(900),
                      itemCount: filtered.length,
                      itemBuilder: (context, row) => _LogLineRow(
                        line: filtered[row],
                        rowIndex: row,
                        fontSize: _fontSize,
                        searchQuery: _searchQuery,
                        isCurrentMatch:
                            matches.isNotEmpty && matches[clampedMatch] == row,
                      ),
                    ),
            ),
          ),
        ),
        _ViewerStatusBar(
          totalLines: lines.length,
          filteredLines: filtered.length,
          matchCount: matches.length,
          levelFilter: _levelFilter,
          followMode: _followMode,
        ),
      ],
    );
  }

  List<_LogLine> _buildLines(String content) {
    if (_cachedContent == content) return _cachedLines;
    if (content.isEmpty) {
      _cachedContent = content;
      _cachedLines = const [];
      return _cachedLines;
    }
    final split = content.split('\n');
    _cachedContent = content;
    _cachedLines = [
      for (var i = 0; i < split.length; i++)
        _LogLine(text: split[i], index: i, level: _levelFor(split[i])),
    ];
    return _cachedLines;
  }

  List<_LogLine> _filterLines(List<_LogLine> lines) {
    if (_levelFilter == _LogFilter.all) return lines;
    return lines.where((line) => line.level == _levelForFilter()).toList();
  }

  List<int> _matchingLinePositions(List<_LogLine> lines) {
    if (_searchQuery.isEmpty) return const [];
    final query = _searchQuery.toLowerCase();
    return [
      for (var i = 0; i < lines.length; i++)
        if (lines[i].text.toLowerCase().contains(query)) i,
    ];
  }

  _LogLevel _levelForFilter() {
    return switch (_levelFilter) {
      _LogFilter.error => _LogLevel.error,
      _LogFilter.warn => _LogLevel.warn,
      _LogFilter.info => _LogLevel.info,
      _LogFilter.debugLevel => _LogLevel.debugLevel,
      _LogFilter.all => _LogLevel.other,
    };
  }

  _LogLevel _levelFor(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('ERROR') || upper.contains('FATAL')) {
      return _LogLevel.error;
    }
    if (upper.contains('WARN')) return _LogLevel.warn;
    if (upper.contains('INFO')) return _LogLevel.info;
    if (upper.contains('DEBUG')) return _LogLevel.debugLevel;
    return _LogLevel.other;
  }

  void _scrollToCurrentMatch() {
    final filtered = _filterLines(_buildLines(widget.content));
    final matches = _matchingLinePositions(filtered);
    if (!_scrollController.hasClients || matches.isEmpty) return;
    final target = matches[_matchIndex.clamp(0, matches.length - 1).toInt()];
    final offset = (target * _estimatedRowHeight) - 120;
    _scrollController.animateTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  double get _estimatedRowHeight => (_fontSize * 1.45) + 4;

  Future<void> _copyContent(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('日志内容已复制')));
  }
}

class _ViewerToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final int matchCount;
  final int matchIndex;
  final _LogFilter levelFilter;
  final bool followMode;
  final double fontSize;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onPreviousMatch;
  final VoidCallback? onNextMatch;
  final ValueChanged<_LogFilter> onFilterChanged;
  final ValueChanged<bool> onFollowChanged;
  final ValueChanged<double> onFontSizeChanged;
  final VoidCallback onCopy;

  const _ViewerToolbar({
    required this.searchController,
    required this.searchQuery,
    required this.matchCount,
    required this.matchIndex,
    required this.levelFilter,
    required this.followMode,
    required this.fontSize,
    required this.onSearchChanged,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onFilterChanged,
    required this.onFollowChanged,
    required this.onFontSizeChanged,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final matchLabel = searchQuery.isEmpty
        ? ''
        : matchCount == 0
        ? '无匹配'
        : '${matchIndex + 1}/$matchCount';

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: '搜索内容...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              onChanged: onSearchChanged,
            ),
          ),
          if (searchQuery.isNotEmpty) ...[
            SizedBox(
              width: 52,
              child: Text(
                matchLabel,
                style: TextStyle(
                  color: AppTheme.mutedText(context),
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              tooltip: '上一个匹配',
              onPressed: onPreviousMatch,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              tooltip: '下一个匹配',
              onPressed: onNextMatch,
            ),
          ],
          SegmentedButton<_LogFilter>(
            segments: const [
              ButtonSegment(value: _LogFilter.all, label: Text('ALL')),
              ButtonSegment(value: _LogFilter.error, label: Text('ERROR')),
              ButtonSegment(value: _LogFilter.warn, label: Text('WARN')),
              ButtonSegment(value: _LogFilter.info, label: Text('INFO')),
              ButtonSegment(value: _LogFilter.debugLevel, label: Text('DEBUG')),
            ],
            selected: {levelFilter},
            showSelectedIcon: false,
            onSelectionChanged: (value) => onFilterChanged(value.first),
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 18),
            tooltip: '缩小字体',
            onPressed: () => onFontSizeChanged((fontSize - 1).clamp(9, 20)),
          ),
          SizedBox(
            width: 28,
            child: Text(
              fontSize.round().toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 18),
            tooltip: '放大字体',
            onPressed: () => onFontSizeChanged((fontSize + 1).clamp(9, 20)),
          ),
          FilterChip(
            label: const Text('跟随'),
            selected: followMode,
            onSelected: onFollowChanged,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: '复制日志内容',
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

class _EmptyLogMessage extends StatelessWidget {
  final String label;
  final double fontSize;

  const _EmptyLogMessage({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: AppTheme.slate400,
          fontFamily: 'monospace',
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _LogLineRow extends StatelessWidget {
  final _LogLine line;
  final int rowIndex;
  final double fontSize;
  final String searchQuery;
  final bool isCurrentMatch;

  const _LogLineRow({
    required this.line,
    required this.rowIndex,
    required this.fontSize,
    required this.searchQuery,
    required this.isCurrentMatch,
  });

  @override
  Widget build(BuildContext context) {
    final lineNumberFontSize = (fontSize - 2).clamp(9, 11).toDouble();
    final levelColor = switch (line.level) {
      _LogLevel.error => AppTheme.danger,
      _LogLevel.warn => AppTheme.warning,
      _LogLevel.info => AppTheme.success,
      _LogLevel.debugLevel => const Color(0xFF38BDF8),
      _LogLevel.other => const Color(0xFFCBD5E1),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: rowIndex.isEven
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.025),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Padding(
              padding: const EdgeInsets.only(right: 6, top: 2),
              child: Text(
                '${line.index + 1}',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontFamily: 'monospace',
                  fontSize: lineNumberFontSize,
                  height: 1.45,
                ),
              ),
            ),
          ),
          Container(width: 1, color: const Color(0xFF1E293B)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
              child: SelectableText.rich(
                TextSpan(
                  children: _highlightSpans(
                    line.text,
                    searchQuery,
                    isCurrentMatch,
                    levelColor,
                  ),
                ),
                style: TextStyle(
                  color: levelColor,
                  fontFamily: 'monospace',
                  fontSize: fontSize,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightSpans(
    String text,
    String query,
    bool current,
    Color baseColor,
  ) {
    if (query.isEmpty) {
      return [TextSpan(text: text.isEmpty ? ' ' : text)];
    }

    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;
    var position = lower.indexOf(q);
    var firstMatch = true;

    while (position >= 0) {
      if (position > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, position)));
      }
      final active = current && firstMatch;
      spans.add(
        TextSpan(
          text: text.substring(position, position + q.length),
          style: TextStyle(
            color: Colors.black,
            backgroundColor: active
                ? const Color(0xFFFB923C)
                : const Color(0xFFFDE047),
          ),
        ),
      );
      cursor = position + q.length;
      position = lower.indexOf(q, cursor);
      firstMatch = false;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    if (spans.isEmpty) {
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(color: baseColor),
        ),
      );
    }
    return spans;
  }
}

class _ViewerStatusBar extends StatelessWidget {
  final int totalLines;
  final int filteredLines;
  final int matchCount;
  final _LogFilter levelFilter;
  final bool followMode;

  const _ViewerStatusBar({
    required this.totalLines,
    required this.filteredLines,
    required this.matchCount,
    required this.levelFilter,
    required this.followMode,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      '共 $totalLines 行',
      if (levelFilter != _LogFilter.all) '过滤后 $filteredLines 行',
      if (matchCount > 0) '$matchCount 处匹配',
      if (followMode) '跟随中',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.borderColor(context))),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final item in items)
            Text(
              item,
              style: TextStyle(
                color: item == '跟随中'
                    ? AppTheme.primaryColor
                    : AppTheme.mutedText(context),
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

class _LogDetailPage extends ConsumerStatefulWidget {
  final String filename;

  const _LogDetailPage({required this.filename});

  @override
  ConsumerState<_LogDetailPage> createState() => _LogDetailPageState();
}

class _LogDetailPageState extends ConsumerState<_LogDetailPage> {
  Timer? _autoRefreshTimer;
  int? _autoRefreshSeconds;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(logsProvider);
    final loading = asyncState.valueOrNull?.contentLoading ?? false;

    return ConsoleScaffold(
      appBar: AppBar(
        title: ConsoleAppBarTitle(
          title: widget.filename,
          subtitle: 'log detail',
        ),
        actions: [
          _ViewerHeaderActions(
            loading: loading,
            autoRefreshSeconds: _autoRefreshSeconds,
            autoRefreshOptions: const [10, 30, 60, 300],
            onAutoRefreshChanged: (seconds) {
              setState(() => _autoRefreshSeconds = seconds);
              _syncAutoRefresh();
            },
            onRefresh: () => ref.read(logsProvider.notifier).refreshSelected(),
            onClose: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (state) {
          if (state.contentLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = state.content ?? '';
          return _LogViewer(content: content, filename: widget.filename);
        },
      ),
    );
  }

  void _syncAutoRefresh() {
    _autoRefreshTimer?.cancel();
    final seconds = _autoRefreshSeconds;
    if (seconds == null) return;

    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => ref.read(logsProvider.notifier).refreshSelected(),
    );
  }
}
