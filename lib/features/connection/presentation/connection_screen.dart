import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('机器人展位管理'),
        leading: Builder(
          builder: (context) {
            final hasActive = ref.watch(connectionProvider).activeId != null;
            if (!hasActive) return const SizedBox.shrink();
            return BackButton(onPressed: () => context.pop());
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('还没有添加任何展位'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('添加展位'),
                    onPressed: () => _showEditDialog(context, null),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.connections.length,
              itemBuilder: (context, i) {
                final conn = state.connections[i];
                final isActive = conn.id == state.activeId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? Colors.cyan : Colors.grey,
                      child: Icon(
                        isActive ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(conn.name),
                    subtitle: Text(conn.baseUrl),
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
                          const Chip(
                            label: Text('活跃'),
                            backgroundColor: Colors.cyan,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: '编辑',
                          onPressed: () => _showEditDialog(context, conn),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.red,
                          tooltip: '删除',
                          onPressed: () =>
                              _confirmDelete(context, conn.id, conn.name),
                        ),
                      ],
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
      builder: (_) => AlertDialog(
        title: const Text('删除展位'),
        content: Text('确认删除「$name」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(connectionProvider.notifier).delete(id);
              Navigator.of(context).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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

class _EditConnectionDialogState
    extends ConsumerState<_EditConnectionDialog> {
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
        text: widget.existing?.baseUrl ?? 'http://');
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
      title: Text(_isEdit ? '编辑展位' : '添加展位'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '展位名称'),
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
                decoration: const InputDecoration(
                  labelText: 'API Token',
                ),
                obscureText: true,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入 Token' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
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
