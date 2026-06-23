import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import 'settings_provider.dart';
import '../../../features/connection/presentation/connection_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final connectionState = ref.watch(connectionProvider);

    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(
          title: '设置',
          subtitle: 'console preferences',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── 展位列表 ────────────────────────────────────────
          ConsoleCard(
            title: '展位列表',
            icon: Icons.wifi_tethering,
            trailing: TextButton(
              onPressed: () => context.go('/connection'),
              child: const Text('管理'),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    connectionState.active != null
                        ? Icons.wifi
                        : Icons.wifi_off,
                    color: connectionState.active != null
                        ? AppTheme.success
                        : AppTheme.slate500,
                  ),
                  title: Text(
                    connectionState.active != null
                        ? connectionState.active!.name
                        : '未连接',
                  ),
                  subtitle: connectionState.active != null
                      ? Text(connectionState.active!.baseUrl)
                      : const Text('请先连接展位'),
                  trailing: StatusPill(
                    label: connectionState.active != null
                        ? 'ACTIVE'
                        : 'OFFLINE',
                    color: connectionState.active != null
                        ? AppTheme.success
                        : AppTheme.slate500,
                  ),
                ),
                if (connectionState.connections.isNotEmpty) ...[
                  Divider(color: AppTheme.borderColor(context)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '所有展位',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...connectionState.connections.map((conn) {
                    final isActive = conn.id == connectionState.activeId;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isActive ? Icons.wifi : Icons.wifi_off,
                        size: 18,
                        color: isActive ? AppTheme.success : AppTheme.slate500,
                      ),
                      title: Text(
                        conn.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        conn.baseUrl,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: isActive
                          ? const StatusPill(
                              label: 'ACTIVE',
                              color: AppTheme.success,
                            )
                          : TextButton(
                              onPressed: () => ref
                                  .read(connectionProvider.notifier)
                                  .activate(conn.id),
                              child: const Text(
                                '连接',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ─── 主题 ─────────────────────────────────────────────
          ConsoleCard(
            title: '主题',
            icon: Icons.dark_mode_outlined,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('深色模式'),
              subtitle: Text(themeMode == ThemeMode.dark ? '已启用' : '已关闭'),
              value: themeMode == ThemeMode.dark,
              onChanged: (v) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 16),

          // ─── 语言 ─────────────────────────────────────────────
          ConsoleCard(
            title: '语言',
            icon: Icons.language,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
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
                  ref.read(localeProvider.notifier).setLocale(Locale(v));
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── 关于 ─────────────────────────────────────────────
          ConsoleCard(
            title: '关于',
            icon: Icons.info_outline,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('应用版本'),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(color: AppTheme.mutedText(context)),
                  ),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.android),
                  title: Text('SysApp'),
                  subtitle: Text('机器人控制系统'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
