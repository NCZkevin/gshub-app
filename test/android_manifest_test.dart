import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'declares permission required by ConnectivityManager.requestNetwork',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android.permission.CHANGE_NETWORK_STATE'));
    },
  );
}
