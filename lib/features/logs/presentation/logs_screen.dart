import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logs_provider.dart';
import '../../../shared/domain/app_models.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(logsProvider);
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
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
                    icon: const Icon(Icons.cleaning_services_outlined),
                    tooltip: '清理旧日志',
                    onPressed: () => _confirmCleanup(context),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _SearchBar(controller: _searchController),
              Expanded(child: _FileList(state: state, isWide: true)),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _ContentView(state: state),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, LogsState state) {
    return Column(
      children: [
        _SearchBar(controller: _searchController),
        Expanded(child: _FileList(state: state, isWide: false)),
      ],
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
            child: const Text('清理', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
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
          border: const OutlineInputBorder(),
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
      return const Center(
        child: Text('暂无日志文件', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, i) {
        final file = files[i];
        final isSelected = state.selected == file.name;
        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          leading: const Icon(Icons.description_outlined),
          title: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            '${_formatSize(file.size)}  ${_formatDate(file.modifiedTime)}',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: Colors.red,
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
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, LogFileInfo file) {
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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
      return const Center(
        child: Text('选择左侧文件以查看内容', style: TextStyle(color: Colors.grey)),
      );
    }

    if (state.contentLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final content = state.content ?? '';
    return _ScrollableLogContent(content: content, filename: state.selected!);
  }
}

class _ScrollableLogContent extends StatefulWidget {
  final String content;
  final String filename;

  const _ScrollableLogContent({required this.content, required this.filename});

  @override
  State<_ScrollableLogContent> createState() => _ScrollableLogContentState();
}

class _ScrollableLogContentState extends State<_ScrollableLogContent> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(_ScrollableLogContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.filename != widget.filename) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.description_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.filename,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.content.isEmpty ? '(空文件)' : widget.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogDetailPage extends ConsumerWidget {
  final String filename;

  const _LogDetailPage({required this.filename});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(logsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(filename)),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误: $e')),
        data: (state) {
          if (state.contentLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = state.content ?? '';
          return _ScrollableLogContent(content: content, filename: filename);
        },
      ),
    );
  }
}
