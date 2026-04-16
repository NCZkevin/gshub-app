import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mapping_provider.dart';
import '../../../shared/domain/app_models.dart';

class MappingScreen extends ConsumerStatefulWidget {
  const MappingScreen({super.key});

  @override
  ConsumerState<MappingScreen> createState() => _MappingScreenState();
}

class _MappingScreenState extends ConsumerState<MappingScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(mappingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('建图管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(mappingProvider.notifier).refresh(),
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
                onPressed: () => ref.read(mappingProvider.notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (state) {
          if (state.viewState == MappingViewState.active) {
            return _buildActiveView(context, state);
          }
          return _buildListView(context, state);
        },
      ),
    );
  }

  Widget _buildListView(BuildContext context, MappingState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Start mapping section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '开始建图',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '地图名称',
                    hintText: '请输入地图名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (state.error != null) ...[
                  Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: state.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.map),
                    label: const Text('开始建图'),
                    onPressed: state.loading
                        ? null
                        : () {
                            ref
                                .read(mappingProvider.notifier)
                                .startMapping(_nameController.text);
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '已保存的地图 (${state.maps.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (state.maps.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('暂无保存的地图', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...state.maps.map((map) => _MapCard(
                map: map,
                onDelete: () => _confirmDelete(context, map.name),
              )),
      ],
    );
  }

  Widget _buildActiveView(BuildContext context, MappingState state) {
    final status = state.mappingStatus;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 12),
                      const SizedBox(width: 8),
                      Text(
                        '建图进行中',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (status?.sceneName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '地图: ${status!.sceneName}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                  const Divider(height: 24),
                  _StatusRow(
                    label: '状态',
                    value: status?.status ?? '获取中...',
                  ),
                  const SizedBox(height: 8),
                  _StatusRow(
                    label: '传感器健康',
                    value: status == null
                        ? '...'
                        : status.perceptionAvailable
                            ? '正常'
                            : '异常',
                    valueColor: status == null
                        ? null
                        : status.perceptionAvailable
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(height: 8),
                  _StatusRow(
                    label: '地图可用',
                    value: status == null
                        ? '...'
                        : status.mapAvailable
                            ? '是'
                            : '否',
                    valueColor: status == null
                        ? null
                        : status.mapAvailable
                            ? Colors.green
                            : Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _StatusRow(
                    label: '已采集点数',
                    value: status == null
                        ? '...'
                        : status.pointsCollected.toString(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: state.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.stop_circle_outlined),
              label: const Text('停止建图'),
              onPressed: state.loading
                  ? null
                  : () => ref.read(mappingProvider.notifier).stopMapping(),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除地图'),
        content: Text('确认删除地图「$name」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(mappingProvider.notifier).deleteMap(name);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final MapInfo map;
  final VoidCallback onDelete;

  const _MapCard({required this.map, required this.onDelete});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.map_outlined, size: 32),
        title: Text(map.name),
        subtitle: Text(
          '${_formatSize(map.size)}  •  ${_formatDate(map.modifiedTime)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: onDelete,
          tooltip: '删除地图',
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
