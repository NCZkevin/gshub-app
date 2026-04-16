import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/connection/presentation/connection_provider.dart';
import '../domain/app_models.dart';

/// 系统健康流（SSE 驱动的 CPU/内存实时数据）
/// 使用轮询 /hub_info 代替 SSE（dart:io 的 SSE 支持需要额外封装）
class SystemHealthNotifier extends AutoDisposeAsyncNotifier<HubInfo?> {
  Timer? _timer;

  @override
  Future<HubInfo?> build() async {
    ref.onDispose(() => _timer?.cancel());
    return _fetch();
  }

  Future<HubInfo?> _fetch() async {
    final client = await ref.read(dioClientFutureProvider.future);
    if (client == null) return null;
    final data = await client.get('/hub_info');
    if (data == null) return null;
    return HubInfo.fromJson(data as Map<String, dynamic>);
  }

  void startPolling({Duration interval = const Duration(seconds: 3)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) async {
      try {
        final info = await _fetch();
        state = AsyncValue.data(info);
      } catch (e, st) {
        state = AsyncValue.error(e, st);
      }
    });
  }

  void stopPolling() => _timer?.cancel();
}

final systemHealthProvider =
    AsyncNotifierProvider.autoDispose<SystemHealthNotifier, HubInfo?>(
  SystemHealthNotifier.new,
);
