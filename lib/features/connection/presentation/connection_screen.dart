import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import 'connection_provider.dart';
import 'machine_availability_provider.dart';
import 'machine_availability_widgets.dart';
import '../data/device_discovery_repository.dart';
import '../domain/connection_model.dart';
import '../../settings/data/settings_repository.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionProvider);
    final availability = ref.watch(machineAvailabilityProvider);

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
            onPressed: () => _showAddDialog(context),
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
                        onPressed: () => _showAddDialog(context),
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
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MachineCard(
                        connection: conn,
                        isActive: isActive,
                        availability: isActive ? availability : null,
                        switching: state.switchingId == conn.id,
                        connectEnabled:
                            state.switchingId == null ||
                            state.switchingId == conn.id,
                        switchError: state.switchErrorId == conn.id
                            ? state.switchError
                            : null,
                        onConnect: () => ref
                            .read(connectionProvider.notifier)
                            .activate(conn.id),
                        onEdit: () => _showEditDialog(context, conn),
                        onDelete: () =>
                            _confirmDelete(context, conn.id, conn.name),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _AddConnectionDialog());
  }

  void _showEditDialog(BuildContext context, RobotConnection existing) {
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

enum _MachineAction { edit, delete }

class _MachineCard extends StatelessWidget {
  const _MachineCard({
    required this.connection,
    required this.isActive,
    required this.availability,
    required this.switching,
    required this.connectEnabled,
    required this.switchError,
    required this.onConnect,
    required this.onEdit,
    required this.onDelete,
  });

  final RobotConnection connection;
  final bool isActive;
  final MachineAvailabilityState? availability;
  final bool switching;
  final bool connectEnabled;
  final String? switchError;
  final VoidCallback onConnect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final networkLabel = connection.networkKind == ConnectionNetworkKind.ap
        ? '机器人热点'
        : '局域网';
    final networkIcon = connection.networkKind == ConnectionNetworkKind.ap
        ? Icons.wifi_tethering
        : Icons.lan_outlined;
    final accent = isActive ? AppTheme.primaryColor : AppTheme.slate500;

    return ConsoleCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        connection.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isActive ? '当前机器' : '已保存',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.mutedText(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (switching)
                  const StatusPill(
                    label: '检测中',
                    color: AppTheme.warning,
                    icon: Icons.sync_rounded,
                  )
                else if (isActive && availability != null)
                  MachineAvailabilityPill(availability: availability!)
                else
                  TextButton.icon(
                    onPressed: connectEnabled ? onConnect : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: Text(switchError == null ? '连接' : '重试'),
                  ),
                PopupMenuButton<_MachineAction>(
                  tooltip: '更多操作',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    maximumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (action) {
                    switch (action) {
                      case _MachineAction.edit:
                        onEdit();
                      case _MachineAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _MachineAction.edit,
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: _MachineAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppTheme.danger,
                          ),
                          SizedBox(width: 10),
                          Text('删除', style: TextStyle(color: AppTheme.danger)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.subtleFill(context).withValues(alpha: 0.72),
                border: Border.all(color: AppTheme.borderColor(context)),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  Icon(
                    networkIcon,
                    size: 15,
                    color: AppTheme.mutedText(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    networkLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: AppTheme.borderColor(context),
                  ),
                  Expanded(
                    child: Tooltip(
                      message: connection.baseUrl,
                      child: Text(
                        connection.baseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (switchError != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppTheme.danger.withValues(alpha: 0.28),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: AppTheme.danger,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        switchError!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppTheme.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddConnectionDialog extends ConsumerStatefulWidget {
  const _AddConnectionDialog();

  @override
  ConsumerState<_AddConnectionDialog> createState() =>
      _AddConnectionDialogState();
}

class _AddConnectionDialogState extends ConsumerState<_AddConnectionDialog> {
  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8898');
  List<DiscoveredRobot> _devices = const [];
  bool _scanning = false;
  bool _adding = false;
  bool _advanced = false;
  String? _error;
  Timer? _rescanTimer;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _rescanTimer?.cancel();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning) return;
    _rescanTimer?.cancel();
    setState(() {
      _scanning = true;
      _error = null;
    });
    try {
      final devices = await ref
          .read(deviceDiscoveryRepositoryProvider)
          .discover();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) setState(() => _error = '搜索失败：$e');
    } finally {
      if (mounted) {
        setState(() => _scanning = false);
        _rescanTimer = Timer(const Duration(seconds: 2), _scan);
      }
    }
  }

  Future<void> _add(DiscoveredRobot robot) async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref.read(connectionProvider.notifier).addDiscovered(robot);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '添加失败：$e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _addManual() async {
    final host = _normalizeHost(_hostCtrl.text);
    final port = int.tryParse(_portCtrl.text.trim());
    if (host.isEmpty) {
      setState(() => _error = '请输入 IP 地址或主机名');
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = '端口格式不正确');
      return;
    }
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      final robot = await ref
          .read(deviceDiscoveryRepositoryProvider)
          .probe(host: host, port: port);
      await ref.read(connectionProvider.notifier).addDiscovered(robot);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '无法识别该机器：$e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  String _normalizeHost(String value) {
    final raw = value.trim();
    final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
    return uri?.host ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('添加机器')),
          IconButton(
            tooltip: '重新搜索',
            onPressed: _scanning || _adding ? null : _scan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _adding
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        context.push('/provision');
                      },
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('通过蓝牙配置网络'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (_scanning) const LinearProgressIndicator(),
              if (!_scanning && _devices.isEmpty)
                const EmptyState(icon: Icons.radar, label: '未发现附近机器')
              else if (_devices.isNotEmpty)
                ..._devices.map(
                  (robot) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.precision_manufacturing_outlined),
                    title: Text(robot.sn),
                    subtitle: Text(
                      [
                        if (robot.model?.isNotEmpty == true) robot.model!,
                        if (robot.version?.isNotEmpty == true) robot.version!,
                        '${robot.host}:${robot.port}',
                      ].join(' · '),
                    ),
                    trailing: FilledButton(
                      onPressed: _adding ? null : () => _add(robot),
                      child: const Text('添加'),
                    ),
                  ),
                ),
              const Divider(height: 28),
              TextField(
                controller: _hostCtrl,
                enabled: !_adding,
                decoration: const InputDecoration(
                  labelText: 'IP 地址或主机名',
                  hintText: '192.168.1.100',
                ),
              ),
              TextButton.icon(
                onPressed: _adding
                    ? null
                    : () => setState(() => _advanced = !_advanced),
                icon: Icon(_advanced ? Icons.expand_less : Icons.expand_more),
                label: const Text('高级设置'),
              ),
              if (_advanced)
                TextField(
                  controller: _portCtrl,
                  enabled: !_adding,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'API 端口'),
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
          onPressed: _adding ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _adding ? null : _addManual,
          child: _adding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('通过地址添加'),
        ),
      ],
    );
  }
}

class _EditConnectionDialog extends ConsumerStatefulWidget {
  final RobotConnection existing;
  const _EditConnectionDialog({required this.existing});

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
  String _originalToken = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing.name);
    _urlCtrl = TextEditingController(text: widget.existing.baseUrl);
    _tokenCtrl = TextEditingController();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final repo = ref.read(connectionRepositoryProvider);
    final token = await repo.getApiToken(widget.existing.id);
    if (mounted && token != null) {
      _originalToken = token;
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
      final token = _tokenCtrl.text.trim();
      if (token.isNotEmpty &&
          (token != _originalToken || url != widget.existing.baseUrl)) {
        await SettingsRepository().verifyToken(url, token);
      }
      final notifier = ref.read(connectionProvider.notifier);
      await notifier.update(
        id: widget.existing.id,
        name: _nameCtrl.text.trim(),
        baseUrl: url,
        apiToken: token,
      );
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
      title: const Text('编辑机器'),
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
                decoration: const InputDecoration(labelText: 'API Token（可选）'),
                obscureText: true,
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
