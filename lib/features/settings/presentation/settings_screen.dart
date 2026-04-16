import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'settings_provider.dart';
import '../../../features/connection/presentation/connection_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // ─── 展位列表 ────────────────────────────────────────
          _SectionHeader(title: '展位列表'),
          ListTile(
            leading: const Icon(Icons.wifi),
            title: Text(
              connectionState.active != null
                  ? connectionState.active!.name
                  : '未连接',
            ),
            subtitle: connectionState.active != null
                ? Text(connectionState.active!.baseUrl)
                : const Text('请先连接展位'),
            trailing: TextButton(
              onPressed: () => context.go('/connection'),
              child: const Text('管理展位'),
            ),
          ),
          if (connectionState.connections.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '所有展位',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            ...connectionState.connections.map((conn) {
              final isActive = conn.id == connectionState.activeId;
              return ListTile(
                dense: true,
                leading: Icon(
                  isActive ? Icons.wifi : Icons.wifi_off,
                  size: 18,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                title: Text(conn.name, style: const TextStyle(fontSize: 14)),
                subtitle:
                    Text(conn.baseUrl, style: const TextStyle(fontSize: 12)),
                trailing: isActive
                    ? const Chip(
                        label: Text('活跃', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      )
                    : TextButton(
                        onPressed: () => ref
                            .read(connectionProvider.notifier)
                            .activate(conn.id),
                        child: const Text('连接', style: TextStyle(fontSize: 12)),
                      ),
              );
            }),
          ],
          const Divider(),

          // ─── 主题 ─────────────────────────────────────────────
          _SectionHeader(title: '主题'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            subtitle: Text(themeMode == ThemeMode.dark ? '已启用' : '已关闭'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    v ? ThemeMode.dark : ThemeMode.light,
                  );
            },
          ),
          const Divider(),

          // ─── 语言 ─────────────────────────────────────────────
          _SectionHeader(title: '语言'),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('显示语言'),
            trailing: DropdownButton<String>(
              value: locale?.languageCode ?? 'zh',
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v == null) return;
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(v));
              },
            ),
          ),
          const Divider(),

          // ─── 关于 ─────────────────────────────────────────────
          _SectionHeader(title: '关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('应用版本'),
            trailing: Text('1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          const ListTile(
            leading: Icon(Icons.android),
            title: Text('SysApp'),
            subtitle: Text('机器人控制系统'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
