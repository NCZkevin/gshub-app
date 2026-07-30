import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/console_widgets.dart';
import '../../connection/data/ap_network_service.dart';
import '../../connection/presentation/connection_provider.dart';
import '../data/ble_provisioning_repository.dart';
import '../domain/provisioning_models.dart';

enum _Stage {
  scanningDevices,
  devices,
  connectingDevice,
  selectingMode,
  scanningWiFi,
  networks,
  connectingWiFi,
  activatingAP,
  joiningAP,
  restoringWiFi,
  verifying,
  succeeded,
}

class ProvisioningScreen extends ConsumerStatefulWidget {
  const ProvisioningScreen({super.key});

  @override
  ConsumerState<ProvisioningScreen> createState() => _ProvisioningScreenState();
}

class _ProvisioningScreenState extends ConsumerState<ProvisioningScreen> {
  _Stage _stage = _Stage.scanningDevices;
  List<ProvisioningDevice> _devices = const [];
  List<ProvisioningWiFiNetwork> _networks = const [];
  ProvisioningSession? _session;
  ProvisioningDeviceInfo? _deviceInfo;
  ProvisioningStatus? _status;
  ProvisioningAPResult? _pendingAP;
  StreamSubscription<ProvisioningEnvelope>? _eventSubscription;
  String? _error;
  String _progress = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanDevices());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _session?.close();
    super.dispose();
  }

  Future<void> _scanDevices() async {
    await _replaceSession(null);
    setState(() {
      _stage = _Stage.scanningDevices;
      _devices = const [];
      _networks = const [];
      _deviceInfo = null;
      _status = null;
      _pendingAP = null;
      _error = null;
      _progress = '正在搜索附近进入配网模式的机器…';
    });
    try {
      final devices = await ref.read(bleProvisioningRepositoryProvider).scan();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _stage = _Stage.devices;
        _progress = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.devices;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _connectDevice(ProvisioningDevice device) async {
    setState(() {
      _stage = _Stage.connectingDevice;
      _error = null;
      _progress = '正在连接 ${device.name}…';
    });
    try {
      final session = await ref
          .read(bleProvisioningRepositoryProvider)
          .connect(device);
      if (!mounted) {
        await session.close();
        return;
      }
      await _replaceSession(session);
      _deviceInfo = session.deviceInfo;
      _eventSubscription = session.events.listen(
        _handleEvent,
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() {
            _stage = _Stage.devices;
            _error = _displayError(error);
            _progress = '';
          });
        },
      );
      if (session.deviceInfo.supportsAP) {
        final status = await session.getStatus();
        if (!mounted) return;
        setState(() {
          _status = status;
          _stage = _Stage.selectingMode;
          _progress = '';
        });
      } else {
        await _scanWiFi();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.devices;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _startAP() async {
    final session = _session;
    if (session == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('开启机器人热点'),
        content: const Text(
          '开启后机器人会断开当前 Wi-Fi，手机随后连接机器人提供的热点。'
          '机器人将保持 AP 模式，直到恢复上次 Wi-Fi 或配置新的 Wi-Fi。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认开启'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _stage = _Stage.activatingAP;
      _error = null;
      _progress = '正在创建机器人热点…';
    });
    try {
      final result = await session.startAP();
      if (!mounted) return;
      _pendingAP = result;
      await _joinAP(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.selectingMode;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _joinAP(ProvisioningAPResult ap) async {
    setState(() {
      _stage = _Stage.joiningAP;
      _error = null;
      _progress = '热点 ${ap.ssid} 已启动，正在让手机加入…';
    });
    try {
      await ref
          .read(apNetworkServiceProvider)
          .join(ssid: ap.ssid, password: ap.password);
      await _verifyAndActivate(ap.ip, ap: ap);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.selectingMode;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _restorePreviousWiFi() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _stage = _Stage.restoringWiFi;
      _error = null;
      _progress = '正在恢复 ${_status?.previousSSID ?? '上次 Wi-Fi'}…';
    });
    try {
      final result = await session.stopAP();
      final ip = result['ip']?.toString() ?? '';
      if (ip.isEmpty) {
        throw const ProvisioningException(
          code: 'NO_IP_ADDRESS',
          message: '已恢复 Wi-Fi，但机器人没有获得 IP 地址',
        );
      }
      await ref.read(apNetworkServiceProvider).release(forget: true);
      await _verifyAndActivate(ip);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.selectingMode;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _scanWiFi() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _stage = _Stage.scanningWiFi;
      _error = null;
      _progress = '正在让机器人扫描 Wi-Fi…';
    });
    try {
      final networks = await session.scanWiFi();
      if (!mounted) return;
      setState(() {
        _networks = networks;
        _stage = _Stage.networks;
        _progress = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.networks;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _selectNetwork(ProvisioningWiFiNetwork network) async {
    var password = '';
    if (network.security != ProvisioningWiFiSecurity.open) {
      final value = await showDialog<String>(
        context: context,
        builder: (_) => _PasswordDialog(ssid: network.ssid),
      );
      if (value == null) return;
      password = value;
    }
    await _connectWiFi(
      ssid: network.ssid,
      security: network.security,
      password: password,
    );
  }

  Future<void> _showHiddenNetworkDialog() async {
    final credentials = await showDialog<_HiddenNetworkCredentials>(
      context: context,
      builder: (_) => const _HiddenNetworkDialog(),
    );
    if (credentials == null) return;
    await _connectWiFi(
      ssid: credentials.ssid,
      security: credentials.security,
      password: credentials.password,
      hidden: true,
    );
  }

  Future<void> _connectWiFi({
    required String ssid,
    required ProvisioningWiFiSecurity security,
    required String password,
    bool hidden = false,
  }) async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _stage = _Stage.connectingWiFi;
      _error = null;
      _progress = '正在连接 $ssid…';
    });
    try {
      final result = await session.connectWiFi(
        ssid: ssid,
        security: security,
        password: password,
        hidden: hidden,
      );
      final ip = result['ip']?.toString() ?? '';
      if (ip.isEmpty) {
        throw const ProvisioningException(
          code: 'NO_IP_ADDRESS',
          message: '机器人已连接 Wi-Fi，但没有获得 IP 地址',
        );
      }
      await ref.read(apNetworkServiceProvider).release(forget: true);
      await _verifyAndActivate(ip);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.networks;
        _error = _displayError(error);
        _progress = '';
      });
    }
  }

  Future<void> _verifyAndActivate(String ip, {ProvisioningAPResult? ap}) async {
    final info = _deviceInfo;
    if (info == null) {
      throw const ProvisioningException(
        code: 'DEVICE_INFO_MISSING',
        message: '无法确认机器人身份',
      );
    }
    setState(() {
      _stage = _Stage.verifying;
      _progress = ap == null
          ? 'Wi-Fi 已连接，正在通过 $ip 验证机器人身份…'
          : '机器人热点已连接，正在通过 $ip 验证身份…';
    });

    final discovery = ref.read(deviceDiscoveryRepositoryProvider);
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final robot = await discovery.probe(
          host: ip,
          port: ap?.apiPort ?? info.apiPort,
          timeout: const Duration(seconds: 2),
        );
        if (robot.sn != info.sn) {
          throw const ProvisioningException(
            code: 'DEVICE_IDENTITY_MISMATCH',
            message: 'IP 地址对应的机器与蓝牙设备不一致',
            retryable: false,
          );
        }
        if (ap == null) {
          await ref.read(connectionProvider.notifier).addProvisioned(robot);
        } else {
          await ref
              .read(connectionProvider.notifier)
              .addProvisionedAP(
                robot: robot,
                ssid: ap.ssid,
                password: ap.password,
              );
        }
        if (!mounted) return;
        setState(() {
          _stage = _Stage.succeeded;
          _progress = '已连接并激活 ${robot.sn}';
        });
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) context.go('/dashboard');
        return;
      } catch (error) {
        if (error is ProvisioningException && !error.retryable) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw ProvisioningException(
      code: 'LOCAL_API_UNREACHABLE',
      message: ap == null
          ? '机器人已联网，但手机暂时无法访问 $ip。请确认手机和机器人位于同一 Wi-Fi 后重试。'
          : '手机已请求加入 ${ap.ssid}，但暂时无法访问 $ip。请确认系统 Wi-Fi 已连接该热点。',
      retryable: true,
    );
  }

  void _handleEvent(ProvisioningEnvelope event) {
    if (!mounted ||
        !{
          'wifi.connect.progress',
          'wifi.ap.start.progress',
          'wifi.ap.stop.progress',
        }.contains(event.type)) {
      return;
    }
    final payload = event.payload;
    if (payload is! Map<String, dynamic>) return;
    final state = payload['state']?.toString() ?? '';
    final label = switch (state) {
      'associating' => '正在进行 Wi-Fi 认证和关联…',
      'obtaining_ip' => '认证成功，正在获取 IP 地址…',
      'verifying_route' => '已获得 IP，正在检查默认路由…',
      'connected' => 'Wi-Fi 已连接…',
      'ap_activating' => '正在启动机器人热点和 DHCP…',
      'ap_active' => '机器人热点已启动…',
      'restoring_wifi' => '正在恢复上次 Wi-Fi…',
      _ => '正在连接 Wi-Fi…',
    };
    setState(() => _progress = label);
  }

  Future<void> _cancelConnection() async {
    try {
      await _session?.cancel();
    } catch (_) {
      // The operation may have finished while the cancel command was sent.
    }
  }

  Future<void> _replaceSession(ProvisioningSession? next) async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    final previous = _session;
    _session = next;
    if (previous != null && !identical(previous, next)) {
      await previous.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = {
      _Stage.scanningDevices,
      _Stage.connectingDevice,
      _Stage.scanningWiFi,
      _Stage.connectingWiFi,
      _Stage.activatingAP,
      _Stage.joiningAP,
      _Stage.restoringWiFi,
      _Stage.verifying,
    }.contains(_stage);

    return ConsoleScaffold(
      appBar: AppBar(
        title: const ConsoleAppBarTitle(
          title: '蓝牙网络配置',
          subtitle: 'BLE provisioning',
        ),
        leading: BackButton(
          onPressed: busy
              ? null
              : () => context.canPop()
                    ? context.pop()
                    : context.go('/connection'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 16),
              if (busy)
                ConsoleCard(
                  child: Column(
                    children: [
                      const LinearProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _progress,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if ({
                        _Stage.connectingWiFi,
                        _Stage.activatingAP,
                        _Stage.restoringWiFi,
                      }.contains(_stage)) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _cancelConnection,
                          child: const Text('取消操作'),
                        ),
                      ],
                    ],
                  ),
                ),
              if (_error != null) ...[
                ConsoleCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_stage == _Stage.devices) _buildDevices(),
              if (_stage == _Stage.selectingMode) _buildModeSelection(),
              if (_stage == _Stage.networks) _buildNetworks(),
              if (_stage == _Stage.succeeded)
                const ConsoleCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 54,
                        color: AppTheme.success,
                      ),
                      SizedBox(height: 12),
                      Text('配网完成'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final step = switch (_stage) {
      _Stage.scanningDevices || _Stage.devices => 0,
      _Stage.connectingDevice || _Stage.selectingMode => 1,
      _Stage.scanningWiFi ||
      _Stage.networks ||
      _Stage.connectingWiFi ||
      _Stage.activatingAP ||
      _Stage.joiningAP ||
      _Stage.restoringWiFi ||
      _Stage.verifying => 2,
      _Stage.succeeded => 3,
    };
    const labels = ['发现机器', '选择模式', '网络切换', '完成'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= step;
        return Expanded(
          child: Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: active
                    ? AppTheme.primaryColor
                    : AppTheme.slate500.withValues(alpha: 0.25),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[index], style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildModeSelection() {
    final info = _deviceInfo;
    final status = _status;
    final pending = _pendingAP;
    return ConsoleCard(
      title: info == null ? '选择网络模式' : '${info.sn} · 选择网络模式',
      icon: Icons.settings_input_antenna,
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wifi),
            title: const Text('连接现有 Wi-Fi'),
            subtitle: const Text('扫描附近路由器，让机器人加入局域网'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _scanWiFi,
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.wifi_tethering),
            title: Text(status?.apActive == true ? '连接当前机器人热点' : '开启机器人热点'),
            subtitle: Text(
              status?.apActive == true
                  ? '重新获取热点凭据并让手机加入'
                  : '机器人提供 2.4 GHz 热点，手机直接连接控制',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _startAP,
          ),
          if (status?.canRestore == true) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_backup_restore),
              title: const Text('恢复上次 Wi-Fi'),
              subtitle: Text(status!.previousSSID),
              trailing: const Icon(Icons.chevron_right),
              onTap: _restorePreviousWiFi,
            ),
          ],
          if (pending != null) ...[
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '热点：${pending.ssid}\n密码：${pending.password}\n机器人地址：${pending.ip}',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _joinAP(pending),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试自动连接'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      ref.read(apNetworkServiceProvider).openWiFiSettings(),
                  icon: const Icon(Icons.settings),
                  label: const Text('打开系统设置'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDevices() {
    return ConsoleCard(
      title: '附近机器',
      icon: Icons.bluetooth_searching,
      child: Column(
        children: [
          if (_devices.isEmpty)
            const EmptyState(
              icon: Icons.bluetooth_disabled,
              label: '未发现正在广播的机器',
            )
          else
            ..._devices.map(
              (device) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.precision_manufacturing_outlined),
                title: Text(device.name),
                subtitle: Text('${device.id} · ${device.rssi} dBm'),
                trailing: FilledButton(
                  onPressed: () => _connectDevice(device),
                  child: const Text('连接'),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scanDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('重新搜索 15 秒'),
          ),
          const SizedBox(height: 8),
          const Text(
            '离线超过 2 分钟的机器会自动广播；已联网机器需先在其设置中打开配网窗口。',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworks() {
    return ConsoleCard(
      title: _deviceInfo == null ? '选择 Wi-Fi' : '${_deviceInfo!.sn} · 选择 Wi-Fi',
      icon: Icons.wifi,
      child: Column(
        children: [
          if (_networks.isEmpty)
            const EmptyState(icon: Icons.wifi_find, label: '没有扫描到可用 Wi-Fi')
          else
            ..._networks.map(
              (network) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_wifiIcon(network.strength)),
                title: Text(network.ssid),
                subtitle: Text(
                  [
                    _securityLabel(network.security),
                    network.frequencyMHz >= 5000 ? '5 GHz' : '2.4 GHz',
                    if (network.saved) '已保存',
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectNetwork(network),
              ),
            ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _scanWiFi,
                icon: const Icon(Icons.refresh),
                label: const Text('重新扫描'),
              ),
              TextButton.icon(
                onPressed: _showHiddenNetworkDialog,
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('隐藏网络'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _wifiIcon(int strength) {
    if (strength >= 70) return Icons.wifi;
    if (strength >= 35) return Icons.network_wifi_2_bar;
    return Icons.network_wifi_1_bar;
  }

  String _securityLabel(ProvisioningWiFiSecurity security) {
    return switch (security) {
      ProvisioningWiFiSecurity.open => '开放网络',
      ProvisioningWiFiSecurity.wpa2Personal => 'WPA2',
      ProvisioningWiFiSecurity.wpa3Personal => 'WPA3',
    };
  }

  String _displayError(Object error) {
    if (error is ProvisioningException) {
      return switch (error.code) {
        'AUTHENTICATION_FAILED' => 'Wi-Fi 密码错误，请重新输入。',
        'NETWORK_NOT_FOUND' => '没有找到该 Wi-Fi，请靠近路由器后重试。',
        'DHCP_TIMEOUT' => '路由器没有及时分配 IP 地址，请稍后重试。',
        'NO_DEFAULT_ROUTE' => '已连接 Wi-Fi，但没有可用的默认路由。',
        'ASSOCIATION_FAILED' => '无法加入该 Wi-Fi，请检查路由器状态后重试。',
        'CONNECT_TIMEOUT' => '连接 Wi-Fi 超时，请靠近路由器后重试。',
        'AP_UNSUPPORTED' => '这台机器的无线网卡不支持热点模式。',
        'AP_DHCP_UNAVAILABLE' => '机器人热点未能启动 IP 分配服务，已尝试恢复原 Wi-Fi。',
        'AP_START_FAILED' => '机器人热点启动失败，已尝试恢复原 Wi-Fi。',
        'AP_RESTORE_FAILED' => '恢复上次 Wi-Fi 失败，机器人会继续保持热点模式。',
        'NO_SAVED_NETWORK' => '没有可恢复的历史 Wi-Fi，请选择并配置一个新网络。',
        'CANCELED' => '操作已取消。',
        'UNSUPPORTED_SECURITY' => '该 Wi-Fi 的安全类型暂不支持。',
        'BUSY' => '另一台手机或另一个配网操作正在进行。',
        'BLUETOOTH_DISCONNECTED' => '蓝牙连接已断开，请重新搜索机器。',
        _ => error.message,
      };
    }
    if (error is APNetworkException) return error.message;
    if (error is TimeoutException) return '操作超时，请重试。';
    return '操作失败：$error';
  }
}

class _PasswordDialog extends StatefulWidget {
  final String ssid;
  const _PasswordDialog({required this.ssid});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('连接 ${widget.ssid}'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'Wi-Fi 密码',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          ),
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) Navigator.of(context).pop(value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_controller.text.isNotEmpty) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: const Text('连接'),
        ),
      ],
    );
  }
}

class _HiddenNetworkCredentials {
  final String ssid;
  final String password;
  final ProvisioningWiFiSecurity security;

  const _HiddenNetworkCredentials({
    required this.ssid,
    required this.password,
    required this.security,
  });
}

class _HiddenNetworkDialog extends StatefulWidget {
  const _HiddenNetworkDialog();

  @override
  State<_HiddenNetworkDialog> createState() => _HiddenNetworkDialogState();
}

class _HiddenNetworkDialogState extends State<_HiddenNetworkDialog> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  var _security = ProvisioningWiFiSecurity.wpa2Personal;

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('连接隐藏网络'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ssid,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Wi-Fi 名称'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ProvisioningWiFiSecurity>(
            initialValue: _security,
            decoration: const InputDecoration(labelText: '安全类型'),
            items: const [
              DropdownMenuItem(
                value: ProvisioningWiFiSecurity.open,
                child: Text('开放网络'),
              ),
              DropdownMenuItem(
                value: ProvisioningWiFiSecurity.wpa2Personal,
                child: Text('WPA2 Personal'),
              ),
              DropdownMenuItem(
                value: ProvisioningWiFiSecurity.wpa3Personal,
                child: Text('WPA3 Personal'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _security = value);
            },
          ),
          if (_security != ProvisioningWiFiSecurity.open) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Wi-Fi 密码'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final ssid = _ssid.text.trim();
            if (ssid.isEmpty) return;
            if (_security != ProvisioningWiFiSecurity.open &&
                _password.text.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              _HiddenNetworkCredentials(
                ssid: ssid,
                password: _password.text,
                security: _security,
              ),
            );
          },
          child: const Text('连接'),
        ),
      ],
    );
  }
}
