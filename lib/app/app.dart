import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/connection/data/ap_network_service.dart';
import '../features/connection/presentation/connection_provider.dart';
import '../features/settings/presentation/settings_provider.dart';
import 'router.dart';
import 'theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    ref.watch(activeNetworkReadyProvider);

    ref.listen<String?>(authPromptProvider, (previous, next) {
      if (next == null || next == previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final dialogContext = rootNavigatorKey.currentContext;
        if (dialogContext == null) return;
        final connection = ref
            .read(connectionProvider)
            .connections
            .where((item) => item.id == next)
            .firstOrNull;
        showDialog<void>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('需要 API Token'),
            content: Text(
              '机器「${connection?.name ?? next}」拒绝了访问，请填写或更新 API Token。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('暂不'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(routerProvider).go('/connection');
                },
                child: const Text('去填写'),
              ),
            ],
          ),
        ).whenComplete(() {
          ref.read(authPromptProvider.notifier).dismiss();
        });
      });
    });
    ref.listen<AsyncValue<void>>(activeNetworkReadyProvider, (previous, next) {
      if (!next.hasError || previous?.error == next.error) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final dialogContext = rootNavigatorKey.currentContext;
        if (dialogContext == null) return;
        final error = next.error;
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text('无法自动连接机器人热点：$error'),
            action: SnackBarAction(
              label: '系统设置',
              onPressed: () =>
                  ref.read(apNetworkServiceProvider).openWiFiSettings(),
            ),
          ),
        );
      });
    });

    return MaterialApp.router(
      title: 'SysApp',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
    );
  }
}
