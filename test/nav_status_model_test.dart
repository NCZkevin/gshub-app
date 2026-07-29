import 'package:flutter_test/flutter_test.dart';
import 'package:sysapp/shared/domain/app_models.dart';

void main() {
  test('idle means the navigation service is ready without an active task', () {
    final status = NavStatus.fromJson({'status': 'idle'});

    expect(status.status, NavigationStatus.vacant);
  });

  test('stop values without a mission mean there is no active task', () {
    for (final value in ['idle', 'stop', 'stopped']) {
      final status = NavStatus.fromJson({'status': value});

      expect(status.status, NavigationStatus.vacant);
    }
  });
}
