import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/utils/pgm_parser.dart';
import '../../../core/websocket/ws_connection_manager.dart';
import '../../../features/connection/presentation/connection_provider.dart';
import '../../../shared/domain/app_models.dart';
import '../../../shared/widgets/console_widgets.dart';
import '../../../shared/widgets/joystick_widget.dart';
import '../../../shared/widgets/occupancy_map.dart';
import '../../../shared/widgets/point_cloud_viewer.dart';
import '../../../shared/widgets/video_view_widget.dart';
import 'mapping_provider.dart';

class MappingScreen extends ConsumerStatefulWidget {
  const MappingScreen({super.key});

  @override
  ConsumerState<MappingScreen> createState() => _MappingScreenState();
}

class _MappingScreenState extends ConsumerState<MappingScreen> {
  static const _mapPageSize = 5;

  final _nameController = TextEditingController();
  int _mapPage = 1;
  bool _confirmStop = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(mappingProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final state = ref.read(mappingProvider).valueOrNull;
        if (state?.viewState == MappingViewState.edit) {
          ref.read(mappingProvider.notifier).closeEditor();
        } else if (state?.viewState == MappingViewState.detail) {
          setState(() => _mapPage = 1);
          ref.read(mappingProvider.notifier).backToList();
        }
      },
      child: ConsoleScaffold(
        appBar: AppBar(
          title: const ConsoleAppBarTitle(
            title: '建图管理',
            subtitle: 'mapping workspace',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: () {
                _mapPage = 1;
                ref.read(mappingProvider.notifier).refresh();
              },
            ),
          ],
        ),
        body: asyncState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorView(
            message: '加载失败: $e',
            onRetry: () => ref.read(mappingProvider.notifier).refresh(),
          ),
          data: (state) {
            return switch (state.viewState) {
              MappingViewState.starting => _buildStartingView(state),
              MappingViewState.active => _buildActiveView(state),
              MappingViewState.saving => _buildSavingView(state),
              MappingViewState.detail => _buildDetailView(state),
              MappingViewState.edit => _buildEditView(state),
              MappingViewState.list => _buildListView(state),
            };
          },
        ),
      ),
    );
  }

  Widget _buildListView(MappingState state) {
    final totalPages = (state.maps.length / _mapPageSize).ceil().clamp(1, 9999);
    if (_mapPage > totalPages) _mapPage = totalPages;
    final start = (_mapPage - 1) * _mapPageSize;
    final pagedMaps = state.maps.skip(start).take(_mapPageSize).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.containerRunning) ...[
          _ResumeMappingBanner(
            loading: state.loading,
            onResume: () => ref.read(mappingProvider.notifier).resumeMapping(),
          ),
          const SizedBox(height: 12),
        ],
        ConsoleCard(
          title: '开始建图',
          icon: Icons.add_location_alt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '地图名称',
                  hintText: '请输入地图名称',
                ),
                onSubmitted: (_) => _startMapping(),
              ),
              const SizedBox(height: 12),
              if (state.error != null) ...[
                _InlineError(message: state.error!),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                icon: state.loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('开始建图'),
                onPressed: state.loading ? null : _startMapping,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ConsoleCard(
          title: '已保存地图（共 ${state.maps.length} 个）',
          icon: Icons.map_outlined,
          child: state.maps.isEmpty
              ? const EmptyState(icon: Icons.map_outlined, label: '暂无保存的地图')
              : Column(
                  children: [
                    for (final map in pagedMaps)
                      _MapListItem(
                        map: map,
                        onOpen: () => ref
                            .read(mappingProvider.notifier)
                            .openDetail(map.name),
                        onDownload: () => _downloadArchive(map.name),
                        onDelete: () => _confirmDelete(context, map.name),
                      ),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 8),
                      _Pager(
                        page: _mapPage,
                        totalPages: totalPages,
                        onPrevious: _mapPage <= 1
                            ? null
                            : () => setState(() => _mapPage--),
                        onNext: _mapPage >= totalPages
                            ? null
                            : () => setState(() => _mapPage++),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildStartingView(MappingState state) {
    return _CenteredProgressView(
      icon: Icons.radar_outlined,
      title: '建图容器启动中...',
      subtitle: state.mappingStatus == null
          ? '等待建图状态上报'
          : _statusLabel(state.mappingStatus!.status),
      warning: state.initTimeout ? '初始化时间过长，底层依赖服务可能存在异常' : null,
      action: OutlinedButton.icon(
        icon: state.loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.close),
        label: Text(state.loading ? '取消中...' : '取消建图'),
        onPressed: state.loading
            ? null
            : () => ref.read(mappingProvider.notifier).cancelStarting(),
      ),
    );
  }

  Widget _buildSavingView(MappingState state) {
    return _CenteredProgressView(
      icon: Icons.save_outlined,
      title: '正在保存地图，请稍候...',
      subtitle:
          '地图名称：${state.mapName.isEmpty ? state.mappingStatus?.sceneName ?? '未命名' : state.mapName}',
    );
  }

  Widget _buildActiveView(MappingState state) {
    final status = state.mappingStatus;
    final currentMap = state.mapName.isEmpty
        ? status?.sceneName ?? '未命名'
        : state.mapName;
    final wsManager = ref.watch(wsManagerProvider);
    final activeConnection = ref.watch(activeConnectionProvider);
    final janusWsUrl = _janusWsUrl(activeConnection?.baseUrl);
    final pointCloudWsUrl = _navWsUrl(activeConnection?.baseUrl);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 820;
            final statusCard = _MappingStatusCard(
              currentMap: currentMap,
              status: status,
            );
            final teleop = _MappingTeleopCard(wsManager: wsManager);
            final video = _MappingVideoCard(janusWsUrl: janusWsUrl);
            final pointCloud = _PointCloudCard(wsUrl: pointCloudWsUrl);
            final stopControls = _buildStopControls(state);

            return Column(
              children: [
                stopControls,
                const SizedBox(height: 12),
                statusCard,
                const SizedBox(height: 12),
                pointCloud,
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: video),
                      const SizedBox(width: 12),
                      SizedBox(width: 300, child: teleop),
                    ],
                  )
                else ...[
                  video,
                  const SizedBox(height: 12),
                  teleop,
                ],
              ],
            );
          },
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: state.error!),
        ],
      ],
    );
  }

  Widget _buildStopControls(MappingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_confirmStop) ...[
          _StopConfirmPanel(
            loading: state.loading,
            onCancel: () => setState(() => _confirmStop = false),
            onConfirm: () {
              setState(() => _confirmStop = false);
              ref.read(mappingProvider.notifier).stopMapping();
            },
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.danger.withValues(alpha: 0.16),
            foregroundColor: AppTheme.danger,
          ),
          icon: state.loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.stop_circle_outlined),
          label: const Text('停止建图'),
          onPressed: state.loading
              ? null
              : () => setState(() => _confirmStop = true),
        ),
      ],
    );
  }

  Widget _buildEditView(MappingState state) {
    final name = state.selectedMap;
    final bytes = state.mapPgmBytes;
    if (name == null || bytes == null) return _buildDetailView(state);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('地图详情'),
              onPressed: () => ref.read(mappingProvider.notifier).closeEditor(),
            ),
            const Icon(Icons.chevron_right, size: 16),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PgmEditorCard(
          mapName: name,
          sourceBytes: bytes,
          saving: state.loading,
          error: state.error,
          onCancel: () => ref.read(mappingProvider.notifier).closeEditor(),
          onSave: (editedBytes) =>
              ref.read(mappingProvider.notifier).saveEditedPgm(editedBytes),
        ),
      ],
    );
  }

  Widget _buildDetailView(MappingState state) {
    final name = state.selectedMap;
    if (name == null) return _buildListView(state);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('地图列表'),
              onPressed: () {
                setState(() => _mapPage = 1);
                ref.read(mappingProvider.notifier).backToList();
              },
            ),
            const Icon(Icons.chevron_right, size: 16),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '编辑 PGM',
              onPressed: state.mapPgmBytes == null
                  ? null
                  : () => ref.read(mappingProvider.notifier).openEditor(),
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: '下载 ZIP',
              onPressed: () => _downloadArchive(name),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 420,
          child: ConsoleCard(
            title: '地图预览',
            icon: Icons.grid_on_outlined,
            padding: EdgeInsets.zero,
            child: state.filesLoading
                ? const Center(child: CircularProgressIndicator())
                : state.mapPgmBytes == null
                ? const EmptyState(
                    icon: Icons.image_not_supported,
                    label: '未找到 PGM 文件',
                  )
                : OccupancyMap(pgmBytes: state.mapPgmBytes),
          ),
        ),
        const SizedBox(height: 16),
        ConsoleCard(
          title: '文件列表',
          icon: Icons.folder_copy_outlined,
          child: state.filesLoading
              ? const Center(child: CircularProgressIndicator())
              : state.mapFiles.isEmpty
              ? const EmptyState(icon: Icons.insert_drive_file, label: '暂无文件')
              : Column(
                  children: [
                    if (state.mapResolution != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StatusRow(
                          label: '分辨率',
                          value:
                              '${state.mapResolution!.toStringAsFixed(3)} m/px',
                        ),
                      ),
                    for (final file in state.mapFiles) _MapFileRow(file: file),
                  ],
                ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          _InlineError(message: state.error!),
        ],
      ],
    );
  }

  void _startMapping() {
    ref.read(mappingProvider.notifier).startMapping(_nameController.text);
  }

  Future<void> _downloadArchive(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref
          .read(mappingProvider.notifier)
          .downloadArchive(name);
      messenger.showSnackBar(SnackBar(content: Text('已保存 $name.zip：$path')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('下载失败: $e')));
    }
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除地图'),
        content: Text('确认删除地图「$name」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(mappingProvider.notifier).deleteMap(name);
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  String? _janusWsUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: 8188,
    ).toString();
  }

  String? _navWsUrl(String? baseUrl) {
    if (baseUrl == null || baseUrl.isEmpty) return null;
    final uri = Uri.parse(baseUrl);
    return Uri(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      host: uri.host,
      port: 9089,
    ).toString();
  }
}

class _ResumeMappingBanner extends StatelessWidget {
  final bool loading;
  final VoidCallback onResume;

  const _ResumeMappingBanner({required this.loading, required this.onResume});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: AppTheme.warning),
          const SizedBox(width: 8),
          const Expanded(child: Text('检测到建图任务正在运行')),
          OutlinedButton.icon(
            icon: loading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(loading ? '恢复中...' : '恢复建图'),
            onPressed: loading ? null : onResume,
          ),
        ],
      ),
    );
  }
}

class _MappingStatusCard extends StatelessWidget {
  final String currentMap;
  final MappingStatus? status;

  const _MappingStatusCard({required this.currentMap, required this.status});

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '建图进行中',
      icon: Icons.radar_outlined,
      trailing: StatusPill(
        label: _statusLabel(status?.status ?? 'mapping'),
        color: _statusColor(status?.status ?? 'mapping'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAP: $currentMap',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
            ),
          ),
          const Divider(height: 24),
          _MetricGrid(status: status),
        ],
      ),
    );
  }
}

class _MappingTeleopCard extends StatefulWidget {
  final WsConnectionManager wsManager;

  const _MappingTeleopCard({required this.wsManager});

  @override
  State<_MappingTeleopCard> createState() => _MappingTeleopCardState();
}

class _MappingTeleopCardState extends State<_MappingTeleopCard> {
  static const _maxLinear = 0.75;
  static const _maxAngular = 1.25;

  double _speed = 0.45;
  double _linear = 0;
  double _angular = 0;

  void _move(double x, double y) {
    final linear = -y * _maxLinear * _speed;
    final angular = -x * _maxAngular * _speed;
    setState(() {
      _linear = linear;
      _angular = angular;
    });
    widget.wsManager.sendCmdVel(linear, angular);
  }

  void _stop() {
    setState(() {
      _linear = 0;
      _angular = 0;
    });
    widget.wsManager.sendStop();
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '遥控器',
      icon: Icons.gamepad_outlined,
      child: Column(
        children: [
          JoystickWidget(
            size: 174,
            stickColor: AppTheme.primaryColor,
            baseColor: AppTheme.subtleFill(context).withValues(alpha: 0.9),
            onMove: _move,
            onRelease: _stop,
          ),
          const SizedBox(height: 12),
          _TeleopSlider(
            value: _speed,
            onChanged: (value) => setState(() => _speed = value),
          ),
          const SizedBox(height: 10),
          _VelocityReadout(linear: _linear, angular: _angular),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.stop_rounded),
              label: const Text('急停'),
              onPressed: _stop,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeleopSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _TeleopSlider({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('倍率', style: TextStyle(color: AppTheme.mutedText(context))),
        Expanded(
          child: Slider(
            value: value,
            min: 0.1,
            max: 1,
            divisions: 9,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _VelocityReadout extends StatelessWidget {
  final double linear;
  final double angular;

  const _VelocityReadout({required this.linear, required this.angular});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.72),
        border: Border.all(color: AppTheme.borderColor(context)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'V ${linear.toStringAsFixed(2)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          Text(
            'W ${angular.toStringAsFixed(2)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MappingVideoCard extends StatefulWidget {
  final String? janusWsUrl;

  const _MappingVideoCard({required this.janusWsUrl});

  @override
  State<_MappingVideoCard> createState() => _MappingVideoCardState();
}

class _MappingVideoCardState extends State<_MappingVideoCard> {
  late final JanusVideoController _left;
  late final JanusVideoController _right;
  late final Future<void> _initFuture;
  bool _ready = false;
  bool _playing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = JanusVideoController(streamId: 100);
    _right = JanusVideoController(streamId: 101);
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([_left.initialize(), _right.initialize()]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void didUpdateWidget(covariant _MappingVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.janusWsUrl != widget.janusWsUrl && _playing) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    unawaited(_disposeControllers());
    super.dispose();
  }

  Future<void> _disposeControllers() async {
    try {
      await _initFuture;
    } catch (_) {}
    await Future.wait([_left.dispose(), _right.dispose()]);
  }

  Future<void> _play() async {
    final url = widget.janusWsUrl;
    if (url == null || _busy || !_ready) return;
    setState(() => _busy = true);
    try {
      await Future.wait([_connect(_left, url), _connect(_right, url)]);
      if (mounted) setState(() => _playing = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(JanusVideoController controller, String url) async {
    try {
      await controller.connect(url);
    } catch (e) {
      controller.status.value = '连接失败: $e';
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Future.wait([_left.stop(), _right.stop()]);
      if (mounted) setState(() => _playing = false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.janusWsUrl != null;
    return ConsoleCard(
      title: '视频流',
      icon: Icons.videocam_outlined,
      trailing: StatusPill(
        label: _playing
            ? 'LIVE'
            : connected
            ? 'STANDBY'
            : 'OFFLINE',
        color: _playing
            ? AppTheme.danger
            : connected
            ? AppTheme.slate500
            : AppTheme.slate400,
      ),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Row(
                children: [
                  Expanded(
                    child: _MappingStreamPane(
                      label: '左',
                      controller: _left,
                      placeholder: connected ? 'NO SIGNAL' : '未配置连接',
                    ),
                  ),
                  Expanded(
                    child: _MappingStreamPane(
                      label: '右',
                      controller: _right,
                      placeholder: connected ? 'NO SIGNAL' : '未配置连接',
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _playing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                label: Text(_playing ? '停止' : '播放'),
                onPressed: connected && !_busy
                    ? (_playing ? _stop : _play)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MappingStreamPane extends StatelessWidget {
  final String label;
  final JanusVideoController controller;
  final String placeholder;

  const _MappingStreamPane({
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoViewWidget(
          renderer: controller.renderer,
          placeholderText: placeholder,
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: ValueListenableBuilder<String>(
            valueListenable: controller.status,
            builder: (context, status, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$label · $status',
                style: const TextStyle(
                  color: Colors.white70,
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PointCloudCard extends StatelessWidget {
  final String? wsUrl;

  const _PointCloudCard({required this.wsUrl});

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: '点云视图',
      icon: Icons.blur_on_outlined,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: SizedBox(
          height: 360,
          child: PointCloudViewer(
            wsUrl: wsUrl,
            pointCloudTopic: '/tower/mapping/cloud_colored',
            accumulate: true,
          ),
        ),
      ),
    );
  }
}

enum _PgmPaintTool {
  free('空闲', 254, AppTheme.success),
  obstacle('障碍', 0, AppTheme.danger),
  unknown('未知', 205, AppTheme.warning);

  final String label;
  final int value;
  final Color color;

  const _PgmPaintTool(this.label, this.value, this.color);
}

class _PgmEditorCard extends StatefulWidget {
  final String mapName;
  final Uint8List sourceBytes;
  final bool saving;
  final String? error;
  final VoidCallback onCancel;
  final ValueChanged<Uint8List> onSave;

  const _PgmEditorCard({
    required this.mapName,
    required this.sourceBytes,
    required this.saving,
    required this.error,
    required this.onCancel,
    required this.onSave,
  });

  @override
  State<_PgmEditorCard> createState() => _PgmEditorCardState();
}

class _PgmEditorCardState extends State<_PgmEditorCard> {
  late PgmImage _image;
  late Uint8List _pixels;
  ui.Image? _preview;
  _PgmPaintTool _tool = _PgmPaintTool.free;
  int _brush = 4;
  bool _dirty = false;
  final List<Uint8List> _undo = [];

  @override
  void initState() {
    super.initState();
    _load(widget.sourceBytes);
  }

  @override
  void didUpdateWidget(covariant _PgmEditorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sourceBytes, widget.sourceBytes)) {
      _load(widget.sourceBytes);
    }
  }

  void _load(Uint8List bytes) {
    _image = parsePgm(bytes);
    _pixels = Uint8List.fromList(_image.pixels);
    _undo.clear();
    _dirty = false;
    unawaited(_refreshPreview());
  }

  Future<void> _refreshPreview() async {
    final rgba = Uint8List(_pixels.length * 4);
    for (var i = 0; i < _pixels.length; i++) {
      final value = _pixels[i];
      final base = i * 4;
      rgba[base] = value;
      rgba[base + 1] = value;
      rgba[base + 2] = value;
      rgba[base + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      _image.width,
      _image.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final next = await completer.future;
    if (mounted) setState(() => _preview = next);
  }

  void _pushUndo() {
    _undo.add(Uint8List.fromList(_pixels));
    if (_undo.length > 20) _undo.removeAt(0);
  }

  void _paint(Offset local, Size size, {bool start = false}) {
    if (size.width <= 0 || size.height <= 0) return;
    if (start) _pushUndo();

    final scale = _fitScale(size);
    final drawnWidth = _image.width * scale;
    final drawnHeight = _image.height * scale;
    final left = (size.width - drawnWidth) / 2;
    final top = (size.height - drawnHeight) / 2;
    final x = ((local.dx - left) / scale).floor();
    final y = ((local.dy - top) / scale).floor();
    if (x < 0 || x >= _image.width || y < 0 || y >= _image.height) return;

    final radius = _brush;
    final r2 = radius * radius;
    for (var yy = y - radius; yy <= y + radius; yy++) {
      if (yy < 0 || yy >= _image.height) continue;
      for (var xx = x - radius; xx <= x + radius; xx++) {
        if (xx < 0 || xx >= _image.width) continue;
        final dx = xx - x;
        final dy = yy - y;
        if (dx * dx + dy * dy <= r2) {
          _pixels[yy * _image.width + xx] = _tool.value;
        }
      }
    }
    _dirty = true;
    unawaited(_refreshPreview());
  }

  double _fitScale(Size size) {
    final sx = size.width / _image.width;
    final sy = size.height / _image.height;
    return sx < sy ? sx : sy;
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _pixels = _undo.removeLast();
      _dirty = true;
    });
    unawaited(_refreshPreview());
  }

  Uint8List _encodeP5() {
    final header = ascii.encode(
      'P5\n# edited by gshub app\n${_image.width} ${_image.height}\n255\n',
    );
    return Uint8List.fromList([...header, ..._pixels]);
  }

  @override
  Widget build(BuildContext context) {
    return ConsoleCard(
      title: 'PGM 编辑',
      icon: Icons.brush_outlined,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _PgmEditorToolbar(
              tool: _tool,
              brush: _brush,
              canUndo: _undo.isNotEmpty,
              saving: widget.saving,
              onToolChanged: (tool) => setState(() => _tool = tool),
              onBrushChanged: (value) => setState(() => _brush = value),
              onUndo: _undoLast,
              onCancel: widget.onCancel,
              onSave: _dirty ? () => widget.onSave(_encodeP5()) : null,
            ),
          ),
          SizedBox(
            height: 520,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return GestureDetector(
                  onPanStart: widget.saving
                      ? null
                      : (details) =>
                            _paint(details.localPosition, size, start: true),
                  onPanUpdate: widget.saving
                      ? null
                      : (details) => _paint(details.localPosition, size),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _PgmEditorPainter(
                      image: _preview,
                      sourceWidth: _image.width,
                      sourceHeight: _image.height,
                      borderColor: AppTheme.borderColor(context),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _InlineError(message: widget.error!),
            ),
        ],
      ),
    );
  }
}

class _PgmEditorToolbar extends StatelessWidget {
  final _PgmPaintTool tool;
  final int brush;
  final bool canUndo;
  final bool saving;
  final ValueChanged<_PgmPaintTool> onToolChanged;
  final ValueChanged<int> onBrushChanged;
  final VoidCallback onUndo;
  final VoidCallback onCancel;
  final VoidCallback? onSave;

  const _PgmEditorToolbar({
    required this.tool,
    required this.brush,
    required this.canUndo,
    required this.saving,
    required this.onToolChanged,
    required this.onBrushChanged,
    required this.onUndo,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<_PgmPaintTool>(
          segments: [
            for (final item in _PgmPaintTool.values)
              ButtonSegment(
                value: item,
                icon: Icon(Icons.circle, color: item.color, size: 15),
                label: Text(item.label),
              ),
          ],
          selected: {tool},
          onSelectionChanged: saving
              ? null
              : (values) => onToolChanged(values.first),
        ),
        SizedBox(
          width: 190,
          child: Row(
            children: [
              Text('笔刷', style: TextStyle(color: AppTheme.mutedText(context))),
              Expanded(
                child: Slider(
                  value: brush.toDouble(),
                  min: 1,
                  max: 18,
                  divisions: 17,
                  onChanged: saving
                      ? null
                      : (value) => onBrushChanged(value.round()),
                ),
              ),
              SizedBox(
                width: 26,
                child: Text(
                  '$brush',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: '撤销',
          onPressed: canUndo && !saving ? onUndo : null,
          icon: const Icon(Icons.undo_rounded),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('取消'),
          onPressed: saving ? null : onCancel,
        ),
        FilledButton.icon(
          icon: saving
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(saving ? '保存中...' : '保存'),
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}

class _PgmEditorPainter extends CustomPainter {
  final ui.Image? image;
  final int sourceWidth;
  final int sourceHeight;
  final Color borderColor;

  const _PgmEditorPainter({
    required this.image,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFF020617);
    canvas.drawRect(Offset.zero & size, background);
    final img = image;
    if (img == null) return;

    final scaleX = size.width / sourceWidth;
    final scaleY = size.height / sourceHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final width = sourceWidth * scale;
    final height = sourceHeight * scale;
    final dst = Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, sourceWidth.toDouble(), sourceHeight.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.drawRect(
      dst,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PgmEditorPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.borderColor != borderColor;
  }
}

class _MapListItem extends StatelessWidget {
  final MapInfo map;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _MapListItem({
    required this.map,
    required this.onOpen,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: AppTheme.borderColor(context)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: const Icon(Icons.map_outlined, color: AppTheme.primaryColor),
          title: Text(
            map.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${_formatDate(map.modifiedTime)}  /  ${_formatSize(map.size)}',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                icon: const Icon(Icons.download_outlined, size: 20),
                tooltip: '下载 ZIP',
                onPressed: onDownload,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppTheme.danger,
                tooltip: '删除地图',
                onPressed: onDelete,
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: onOpen,
        ),
      ),
    );
  }
}

class _MapFileRow extends StatelessWidget {
  final FileInfo file;

  const _MapFileRow({required this.file});

  @override
  Widget build(BuildContext context) {
    final ext = file.name.split('.').last.toUpperCase();
    final color = switch (ext) {
      'PGM' => AppTheme.primaryColor,
      'YAML' || 'YML' => AppTheme.warning,
      _ => AppTheme.slate400,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 50,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ext,
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          Text(
            _formatSize(file.size),
            style: TextStyle(
              color: AppTheme.mutedText(context),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final MappingStatus? status;

  const _MetricGrid({required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(
          label: '状态',
          value: status == null ? '获取中...' : _statusLabel(status!.status),
          valueColor: status == null ? null : _statusColor(status!.status),
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: '传感器',
          value: status == null
              ? '...'
              : status!.perceptionAvailable
              ? '正常'
              : '异常',
          valueColor: status == null
              ? null
              : status!.perceptionAvailable
              ? AppTheme.success
              : AppTheme.danger,
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: '2D地图',
          value: status == null
              ? '...'
              : status!.mapAvailable
              ? '正常'
              : '等待中',
          valueColor: status == null
              ? null
              : status!.mapAvailable
              ? AppTheme.success
              : AppTheme.warning,
        ),
        const SizedBox(height: 8),
        _StatusRow(
          label: '已采集点数',
          value: status?.pointsCollected.toString() ?? '...',
        ),
      ],
    );
  }
}

class _StopConfirmPanel extends StatelessWidget {
  final bool loading;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _StopConfirmPanel({
    required this.loading,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.subtleFill(context).withValues(alpha: 0.8),
        border: Border.all(color: AppTheme.borderColor(context)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('停止建图后地图将自动保存，确认继续？'),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: loading ? null : onConfirm,
                child: const Text('确认停止'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: loading ? null : onCancel,
                child: const Text('取消'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.chevron_left),
          label: const Text('上一页'),
          onPressed: onPrevious,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$page / $totalPages',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.chevron_right),
          label: const Text('下一页'),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _CenteredProgressView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? warning;
  final Widget? action;

  const _CenteredProgressView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.warning,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppTheme.primaryColor),
            const SizedBox(height: 14),
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: AppTheme.mutedText(context),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            if (warning != null) ...[
              const SizedBox(height: 12),
              _WarningBox(message: warning!),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String message;

  const _WarningBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.warning, fontSize: 12),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: AppTheme.danger, fontSize: 13),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppTheme.danger),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppTheme.mutedText(context))),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: valueColor,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'initializing' => '初始化中',
    'waiting_perception' => '等待传感器',
    'waiting_map' => '等待2D地图',
    'mapping' => '建图中',
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'mapping' => AppTheme.success,
    'initializing' => AppTheme.primaryColor,
    'waiting_perception' => AppTheme.danger,
    'waiting_map' => AppTheme.warning,
    _ => AppTheme.slate400,
  };
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _formatDate(double? ts) {
  if (ts == null) return '未知';
  final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).toInt());
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
