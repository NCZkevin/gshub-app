import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import 'connection_provider.dart';
import '../domain/connection_model.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);

    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(
          title: '机器列表',
          subtitle: 'connection manager',
        ),
        leading: Builder(
          builder: (context) {
            final hasActive = ref.watch(connectionProvider).activeId != null;
            if (!hasActive) return const SizedBox.shrink();
            return BackButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/settings');
                }
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showEditDialog(context, null),
          ),
        ],
      ),
      body: state.connections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConsoleCard(
                  title: '连接管理',
                  icon: Icons.wifi_tethering_error_outlined,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EmptyState(
                        icon: Icons.wifi_off,
                        label: '还没有添加任何机器',
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('添加机器'),
                        onPressed: () => _showEditDialog(context, null),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.connections.length,
              itemBuilder: (context, i) {
                final conn = state.connections[i];
                final isActive = conn.id == state.activeId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ConsoleCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? AppTheme.primaryColor.withValues(alpha: 0.18)
                            : AppTheme.slate500.withValues(alpha: 0.18),
                        child: Icon(
                          isActive ? Icons.wifi : Icons.wifi_off,
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.slate500,
                          size: 20,
                        ),
                      ),
                      title: Text(conn.name),
                      subtitle: Text(
                        conn.baseUrl,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive)
                            TextButton(
                              onPressed: () => ref
                                  .read(connectionProvider.notifier)
                                  .activate(conn.id),
                              child: const Text('连接'),
                            ),
                          if (isActive)
                            const StatusPill(
                              label: 'ACTIVE',
                              color: AppTheme.success,
                            ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: '编辑',
                            onPressed: () => _showEditDialog(context, conn),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: AppTheme.danger,
                            tooltip: '删除',
                            onPressed: () =>
                                _confirmDelete(context, conn.id, conn.name),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showEditDialog(BuildContext context, RobotConnection? existing) {
    showDialog(
      context: context,
      builder: (_) => _EditConnectionDialog(existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除机器'),
        content: Text('确认删除「$name」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(connectionProvider.notifier).delete(id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

class _EditConnectionDialog extends ConsumerStatefulWidget {
  final RobotConnection? existing;
  const _EditConnectionDialog({this.existing});

  @override
  ConsumerState<_EditConnectionDialog> createState() =>
      _EditConnectionDialogState();
}

class _EditConnectionDialogState extends ConsumerState<_EditConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _tokenCtrl;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _urlCtrl = TextEditingController(
      text: widget.existing?.baseUrl ?? 'http://',
    );
    _tokenCtrl = TextEditingController();
    // Pre-fill token for edits
    if (_isEdit) _loadToken();
  }

  Future<void> _loadToken() async {
    final repo = ref.read(connectionRepositoryProvider);
    final token = await repo.getApiToken(widget.existing!.id);
    if (mounted && token != null) {
      _tokenCtrl.text = token;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
      final notifier = ref.read(connectionProvider.notifier);
      if (_isEdit) {
        await notifier.update(
          id: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          baseUrl: url,
          apiToken: _tokenCtrl.text.trim(),
        );
      } else {
        await notifier.add(
          name: _nameCtrl.text.trim(),
          baseUrl: url,
          apiToken: _tokenCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '编辑机器' : '添加机器'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '机器名称'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: 'http://192.168.1.100:8080',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入地址';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasAuthority) return '地址格式不正确';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(labelText: 'API Token'),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入 Token' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppTheme.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }
}
