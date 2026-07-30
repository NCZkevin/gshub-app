import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/connection/data/ap_network_service.dart';
import '../features/connection/data/machine_connection_probe.dart';
import '../features/connection/presentation/connection_provider.dart';
import '../features/connection/presentation/machine_availability_provider.dart';
import '../features/settings/presentation/settings_provider.dart';
import 'router.dart';
import 'theme.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(machineAvailabilityProvider.notifier).retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    ref.watch(machineAvailabilityProvider);

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
    ref.listen<MachineAvailabilityState>(
      machineAvailabilityProvider,
      _handleAvailabilityChange,
    );

    return MaterialApp.router(
      title: 'SysApp',
      scaffoldMessengerKey: rootScaffoldMessengerKey,
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

  void _handleAvailabilityChange(
    MachineAvailabilityState? previous,
    MachineAvailabilityState next,
  ) {
    if (previous?.status == next.status &&
        previous?.connectionId == next.connectionId &&
        previous?.message == next.message) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger == null) return;

      if (next.status == MachineAvailabilityStatus.online) {
        messenger.clearMaterialBanners();
        if (previous?.isUnavailable == true) {
          final connection = ref.read(activeConnectionProvider);
          messenger.showSnackBar(
            SnackBar(
              content: Text('已恢复与「${connection?.name ?? '机器'}」的连接'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (next.status == MachineAvailabilityStatus.noMachine) {
        messenger.clearMaterialBanners();
        return;
      }
      if (next.status == MachineAvailabilityStatus.checking &&
          previous?.isUnavailable != true) {
        return;
      }

      final connection = ref.read(activeConnectionProvider);
      final isAPError =
          next.failureKind == MachineConnectionFailureKind.apNetwork;
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          leading: Icon(
            next.status == MachineAvailabilityStatus.reconnecting ||
                    next.status == MachineAvailabilityStatus.checking
                ? Icons.sync_rounded
                : Icons.cloud_off_outlined,
            color: next.status == MachineAvailabilityStatus.offline
                ? AppTheme.danger
                : AppTheme.warning,
          ),
          content: Text(
            '机器「${connection?.name ?? next.connectionId ?? ''}」'
            '：${next.message ?? '暂时不可用'}',
          ),
          actions: [
            if (isAPError)
              TextButton(
                onPressed: () =>
                    ref.read(apNetworkServiceProvider).openWiFiSettings(),
                child: const Text('系统设置'),
              ),
            TextButton(
              onPressed: () =>
                  ref.read(machineAvailabilityProvider.notifier).retry(),
              child: const Text('重试'),
            ),
            TextButton(
              onPressed: () => ref.read(routerProvider).go('/connection'),
              child: const Text('切换机器'),
            ),
          ],
        ),
      );
    });
  }
}
