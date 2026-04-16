// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Robot Console';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get navigation => 'Navigation';

  @override
  String get mapping => 'Mapping';

  @override
  String get logs => 'Logs';

  @override
  String get settings => 'Settings';

  @override
  String get connection => 'Connections';

  @override
  String get addConnection => 'Add Connection';

  @override
  String get editConnection => 'Edit Connection';

  @override
  String get deleteConnection => 'Delete Connection';

  @override
  String get connectionName => 'Name';

  @override
  String get serverAddress => 'Server Address';

  @override
  String get apiToken => 'API Token';

  @override
  String get terminalToken => 'Terminal Token (optional)';

  @override
  String get verify => 'Verify';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get connect => 'Connect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting...';

  @override
  String get verifySuccess => 'Verification successful';

  @override
  String get verifyFailed => 'Verification failed';

  @override
  String get networkError => 'Network error';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get refresh => 'Refresh';

  @override
  String get clear => 'Clear';

  @override
  String get search => 'Search';

  @override
  String get noData => 'No data';

  @override
  String get loading => 'Loading...';

  @override
  String get running => 'Running';

  @override
  String get stopped => 'Stopped';

  @override
  String get error => 'Error';

  @override
  String get mapName => 'Map Name';

  @override
  String get selectMap => 'Select Map';

  @override
  String get startNavigation => 'Start Navigation';

  @override
  String get stopNavigation => 'Stop Navigation';

  @override
  String get singlePoint => 'Single Point';

  @override
  String get pathMode => 'Path Mode';

  @override
  String get recordMode => 'Record Mode';

  @override
  String get waypoints => 'Waypoints';

  @override
  String get addWaypoint => 'Add Waypoint';

  @override
  String get savePath => 'Save Path';

  @override
  String get startMapping => 'Start Mapping';

  @override
  String get stopMapping => 'Stop Mapping';

  @override
  String get pointsCollected => 'Points Collected';

  @override
  String get sensorHealth => 'Sensor Health';

  @override
  String get mapAvailable => '2D Map';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get systemMode => 'System Default';

  @override
  String get aboutApp => 'About';

  @override
  String get version => 'Version';

  @override
  String get autoRefresh => 'Auto Refresh';

  @override
  String get deleteFile => 'Delete File';

  @override
  String get cleanupLogs => 'Cleanup Logs';

  @override
  String get downloadMap => 'Download Map';

  @override
  String get deleteMap => 'Delete Map';

  @override
  String get normal => 'Normal';

  @override
  String get abnormal => 'Abnormal';

  @override
  String get waiting => 'Waiting';

  @override
  String get initializing => 'Initializing';

  @override
  String get navigating => 'Navigating';

  @override
  String get arrived => 'Arrived';

  @override
  String get failed => 'Failed';

  @override
  String get paused => 'Paused';

  @override
  String get returnToOrigin => 'Return to Origin';

  @override
  String speedPercent(int percent) {
    return 'Speed $percent%';
  }

  @override
  String cpuUsage(String percent) {
    return 'CPU $percent%';
  }

  @override
  String memUsage(String used, String total) {
    return 'Memory $used/$total GB';
  }
}
