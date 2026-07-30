import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/features/provisioning/domain/provisioning_models.dart';

void main() {
  group('ProvisioningDeviceInfo', () {
    test('keeps legacy wifi-only daemons backward compatible', () {
      final info = ProvisioningDeviceInfo.fromJson({
        'sn': 'GS000001',
        'api_port': 8898,
      });

      expect(info.capabilities, {'wifi_client'});
      expect(info.supportsAP, isFalse);
    });

    test('detects AP support from negotiated capabilities', () {
      final info = ProvisioningDeviceInfo.fromJson({
        'sn': 'GS000002',
        'capabilities': ['wifi_client', 'wifi_ap'],
      });

      expect(info.supportsAP, isTrue);
    });
  });

  test('parses AP result used to join and persist the robot hotspot', () {
    final result = ProvisioningAPResult.fromJson({
      'ssid': 'GSHUB-AP-000002',
      'password': 'gshub1234',
      'ip': '192.168.4.1',
      'api_port': 8898,
      'prefix_length': 24,
      'band': '2.4ghz',
      'channel': 6,
      'can_restore': true,
      'previous_ssid': 'office',
    });

    expect(result.ssid, 'GSHUB-AP-000002');
    expect(result.ip, '192.168.4.1');
    expect(result.canRestore, isTrue);
    expect(result.previousSSID, 'office');
  });

  test('parses AP state and previous Wi-Fi restore metadata', () {
    final status = ProvisioningStatus.fromJson({
      'wifi': {
        'mode': 'ap',
        'connected': true,
        'ssid': 'GSHUB-AP-000002',
        'ip': '192.168.4.1',
        'can_restore': true,
        'previous_ssid': 'office',
      },
    });

    expect(status.apActive, isTrue);
    expect(status.canRestore, isTrue);
    expect(status.previousSSID, 'office');
  });
}
