import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/features/connection/domain/connection_model.dart';

void main() {
  test('loads legacy saved connections as LAN connections', () {
    final connection = RobotConnection.fromJson({
      'id': 'GS000001',
      'name': 'robot',
      'baseUrl': 'http://192.168.5.31:8898',
    });

    expect(connection.networkKind, ConnectionNetworkKind.lan);
    expect(connection.apSsid, isNull);
  });

  test('round-trips AP reconnect metadata', () {
    const connection = RobotConnection(
      id: 'GS000002',
      name: 'robot AP',
      baseUrl: 'http://192.168.4.1:8898',
      networkKind: ConnectionNetworkKind.ap,
      apSsid: 'GSHUB-AP-000002',
    );

    expect(RobotConnection.fromJson(connection.toJson()), connection);
  });
}
