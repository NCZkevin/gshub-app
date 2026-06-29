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
        padding: const EdgeInsets.all(12),
        children: [
          // ─── 机器列表 ────────────────────────────────────────
          ConsoleCard(
            title: '机器列表',
            icon: Icons.wifi_tethering,
            trailing: TextButton(
              onPressed: () => context.push('/connection'),
              child: const Text('管理'),
            ),
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 28,
                  leading: Icon(
                    connectionState.active != null
                        ? Icons.wifi
                        : Icons.wifi_off,
                    size: 20,
                    color: connectionState.active != null
                        ? AppTheme.success
                        : AppTheme.slate500,
                  ),
                  title: Text(
                    connectionState.active != null
                        ? connectionState.active!.name
                        : '未连接',
                    style: _titleStyle(context),
                  ),
                  subtitle: connectionState.active != null
                      ? Text(
                          connectionState.active!.baseUrl,
                          style: _monoSubtitleStyle(context),
                        )
                      : Text('请先连接机器', style: _subtitleStyle(context)),
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
                      '所有机器',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...connectionState.connections.map((conn) {
                    final isActive = conn.id == connectionState.activeId;
                    return ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      minLeadingWidth: 26,
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
          const SizedBox(height: 12),

          // ─── 主题 ─────────────────────────────────────────────
          ConsoleCard(
            title: '主题',
            icon: Icons.dark_mode_outlined,
            child: SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined, size: 20),
              title: Text('深色模式', style: _titleStyle(context)),
              subtitle: Text(
                themeMode == ThemeMode.dark ? '已启用' : '已关闭',
                style: _subtitleStyle(context),
              ),
              value: themeMode == ThemeMode.dark,
              onChanged: (v) {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 12),

          // ─── 语言 ─────────────────────────────────────────────
          ConsoleCard(
            title: '语言',
            icon: Icons.language,
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 28,
              leading: const Icon(Icons.language, size: 20),
              title: Text('显示语言', style: _titleStyle(context)),
              trailing: DropdownButton<String>(
                value: locale?.languageCode ?? 'zh',
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(
                    value: 'zh',
                    child: Text('中文', style: TextStyle(fontSize: 14)),
                  ),
                  DropdownMenuItem(
                    value: 'en',
                    child: Text('English', style: TextStyle(fontSize: 14)),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  ref.read(localeProvider.notifier).setLocale(Locale(v));
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ─── 诊断 ─────────────────────────────────────────────
          ConsoleCard(
            title: '诊断',
            icon: Icons.build_circle_outlined,
            child: ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              minLeadingWidth: 28,
              leading: const Icon(Icons.article_outlined, size: 20),
              title: Text('运行日志', style: _titleStyle(context)),
              subtitle: Text('查看设备和服务日志', style: _subtitleStyle(context)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/logs'),
            ),
          ),
          const SizedBox(height: 12),

          // ─── 关于 ─────────────────────────────────────────────
          ConsoleCard(
            title: '关于',
            icon: Icons.info_outline,
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 28,
                  leading: const Icon(Icons.info_outline, size: 20),
                  title: Text('应用版本', style: _titleStyle(context)),
                  trailing: Text('1.0.0', style: _monoSubtitleStyle(context)),
                ),
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 28,
                  leading: const Icon(Icons.android, size: 20),
                  title: Text('SysApp', style: _titleStyle(context)),
                  subtitle: Text('机器人控制系统', style: _subtitleStyle(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  TextStyle? _titleStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w700);

  TextStyle? _subtitleStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12);

  TextStyle? _monoSubtitleStyle(BuildContext context) =>
      _subtitleStyle(context)?.copyWith(fontFamily: 'monospace');
}
