import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'机器人控制台'**
  String get appTitle;

  /// No description provided for @dashboard.
  ///
  /// In zh, this message translates to:
  /// **'仪表盘'**
  String get dashboard;

  /// No description provided for @navigation.
  ///
  /// In zh, this message translates to:
  /// **'导航'**
  String get navigation;

  /// No description provided for @mapping.
  ///
  /// In zh, this message translates to:
  /// **'建图'**
  String get mapping;

  /// No description provided for @logs.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logs;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @connection.
  ///
  /// In zh, this message translates to:
  /// **'连接管理'**
  String get connection;

  /// No description provided for @addConnection.
  ///
  /// In zh, this message translates to:
  /// **'添加机器'**
  String get addConnection;

  /// No description provided for @editConnection.
  ///
  /// In zh, this message translates to:
  /// **'编辑机器'**
  String get editConnection;

  /// No description provided for @deleteConnection.
  ///
  /// In zh, this message translates to:
  /// **'删除机器'**
  String get deleteConnection;

  /// No description provided for @connectionName.
  ///
  /// In zh, this message translates to:
  /// **'机器名称'**
  String get connectionName;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @apiToken.
  ///
  /// In zh, this message translates to:
  /// **'API Token'**
  String get apiToken;

  /// No description provided for @terminalToken.
  ///
  /// In zh, this message translates to:
  /// **'终端 Token（可选）'**
  String get terminalToken;

  /// No description provided for @verify.
  ///
  /// In zh, this message translates to:
  /// **'验证'**
  String get verify;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @connect.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开'**
  String get disconnect;

  /// No description provided for @connected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中...'**
  String get connecting;

  /// No description provided for @verifySuccess.
  ///
  /// In zh, this message translates to:
  /// **'验证成功'**
  String get verifySuccess;

  /// No description provided for @verifyFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证失败'**
  String get verifyFailed;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络错误'**
  String get networkError;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// No description provided for @start.
  ///
  /// In zh, this message translates to:
  /// **'启动'**
  String get start;

  /// No description provided for @stop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get stop;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get resume;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @running.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get running;

  /// No description provided for @stopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get stopped;

  /// No description provided for @error.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get error;

  /// No description provided for @mapName.
  ///
  /// In zh, this message translates to:
  /// **'地图名称'**
  String get mapName;

  /// No description provided for @selectMap.
  ///
  /// In zh, this message translates to:
  /// **'选择地图'**
  String get selectMap;

  /// No description provided for @startNavigation.
  ///
  /// In zh, this message translates to:
  /// **'开始导航'**
  String get startNavigation;

  /// No description provided for @stopNavigation.
  ///
  /// In zh, this message translates to:
  /// **'停止导航'**
  String get stopNavigation;

  /// No description provided for @singlePoint.
  ///
  /// In zh, this message translates to:
  /// **'单点导航'**
  String get singlePoint;

  /// No description provided for @pathMode.
  ///
  /// In zh, this message translates to:
  /// **'路径导航'**
  String get pathMode;

  /// No description provided for @recordMode.
  ///
  /// In zh, this message translates to:
  /// **'路径录制'**
  String get recordMode;

  /// No description provided for @waypoints.
  ///
  /// In zh, this message translates to:
  /// **'航点'**
  String get waypoints;

  /// No description provided for @addWaypoint.
  ///
  /// In zh, this message translates to:
  /// **'添加航点'**
  String get addWaypoint;

  /// No description provided for @savePath.
  ///
  /// In zh, this message translates to:
  /// **'保存路径'**
  String get savePath;

  /// No description provided for @startMapping.
  ///
  /// In zh, this message translates to:
  /// **'开始建图'**
  String get startMapping;

  /// No description provided for @stopMapping.
  ///
  /// In zh, this message translates to:
  /// **'停止建图'**
  String get stopMapping;

  /// No description provided for @pointsCollected.
  ///
  /// In zh, this message translates to:
  /// **'采集点数'**
  String get pointsCollected;

  /// No description provided for @sensorHealth.
  ///
  /// In zh, this message translates to:
  /// **'传感器状态'**
  String get sensorHealth;

  /// No description provided for @mapAvailable.
  ///
  /// In zh, this message translates to:
  /// **'2D 地图'**
  String get mapAvailable;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In zh, this message translates to:
  /// **'浅色模式'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get systemMode;

  /// No description provided for @aboutApp.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutApp;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @autoRefresh.
  ///
  /// In zh, this message translates to:
  /// **'自动刷新'**
  String get autoRefresh;

  /// No description provided for @deleteFile.
  ///
  /// In zh, this message translates to:
  /// **'删除文件'**
  String get deleteFile;

  /// No description provided for @cleanupLogs.
  ///
  /// In zh, this message translates to:
  /// **'清理日志'**
  String get cleanupLogs;

  /// No description provided for @downloadMap.
  ///
  /// In zh, this message translates to:
  /// **'下载地图'**
  String get downloadMap;

  /// No description provided for @deleteMap.
  ///
  /// In zh, this message translates to:
  /// **'删除地图'**
  String get deleteMap;

  /// No description provided for @normal.
  ///
  /// In zh, this message translates to:
  /// **'正常'**
  String get normal;

  /// No description provided for @abnormal.
  ///
  /// In zh, this message translates to:
  /// **'异常'**
  String get abnormal;

  /// No description provided for @waiting.
  ///
  /// In zh, this message translates to:
  /// **'等待中'**
  String get waiting;

  /// No description provided for @initializing.
  ///
  /// In zh, this message translates to:
  /// **'初始化中'**
  String get initializing;

  /// No description provided for @navigating.
  ///
  /// In zh, this message translates to:
  /// **'导航中'**
  String get navigating;

  /// No description provided for @arrived.
  ///
  /// In zh, this message translates to:
  /// **'已到达'**
  String get arrived;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'失败'**
  String get failed;

  /// No description provided for @paused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停'**
  String get paused;

  /// No description provided for @returnToOrigin.
  ///
  /// In zh, this message translates to:
  /// **'返回原点'**
  String get returnToOrigin;

  /// No description provided for @speedPercent.
  ///
  /// In zh, this message translates to:
  /// **'速度 {percent}%'**
  String speedPercent(int percent);

  /// No description provided for @cpuUsage.
  ///
  /// In zh, this message translates to:
  /// **'CPU {percent}%'**
  String cpuUsage(String percent);

  /// No description provided for @memUsage.
  ///
  /// In zh, this message translates to:
  /// **'内存 {used}/{total} GB'**
  String memUsage(String used, String total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
