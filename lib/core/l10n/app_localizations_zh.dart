// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '机器人控制台';

  @override
  String get dashboard => '仪表盘';

  @override
  String get navigation => '导航';

  @override
  String get mapping => '建图';

  @override
  String get logs => '日志';

  @override
  String get settings => '设置';

  @override
  String get connection => '连接管理';

  @override
  String get addConnection => '添加机器';

  @override
  String get editConnection => '编辑机器';

  @override
  String get deleteConnection => '删除机器';

  @override
  String get connectionName => '机器名称';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get apiToken => 'API Token';

  @override
  String get terminalToken => '终端 Token（可选）';

  @override
  String get verify => '验证';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确认';

  @override
  String get connect => '连接';

  @override
  String get disconnect => '断开';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get connecting => '连接中...';

  @override
  String get verifySuccess => '验证成功';

  @override
  String get verifyFailed => '验证失败';

  @override
  String get networkError => '网络错误';

  @override
  String get unknownError => '未知错误';

  @override
  String get start => '启动';

  @override
  String get stop => '停止';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续';

  @override
  String get refresh => '刷新';

  @override
  String get clear => '清除';

  @override
  String get search => '搜索';

  @override
  String get noData => '暂无数据';

  @override
  String get loading => '加载中...';

  @override
  String get running => '运行中';

  @override
  String get stopped => '已停止';

  @override
  String get error => '错误';

  @override
  String get mapName => '地图名称';

  @override
  String get selectMap => '选择地图';

  @override
  String get startNavigation => '开始导航';

  @override
  String get stopNavigation => '停止导航';

  @override
  String get singlePoint => '单点导航';

  @override
  String get pathMode => '路径导航';

  @override
  String get recordMode => '路径录制';

  @override
  String get waypoints => '航点';

  @override
  String get addWaypoint => '添加航点';

  @override
  String get savePath => '保存路径';

  @override
  String get startMapping => '开始建图';

  @override
  String get stopMapping => '停止建图';

  @override
  String get pointsCollected => '采集点数';

  @override
  String get sensorHealth => '传感器状态';

  @override
  String get mapAvailable => '2D 地图';

  @override
  String get language => '语言';

  @override
  String get theme => '主题';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get systemMode => '跟随系统';

  @override
  String get aboutApp => '关于';

  @override
  String get version => '版本';

  @override
  String get autoRefresh => '自动刷新';

  @override
  String get deleteFile => '删除文件';

  @override
  String get cleanupLogs => '清理日志';

  @override
  String get downloadMap => '下载地图';

  @override
  String get deleteMap => '删除地图';

  @override
  String get normal => '正常';

  @override
  String get abnormal => '异常';

  @override
  String get waiting => '等待中';

  @override
  String get initializing => '初始化中';

  @override
  String get navigating => '导航中';

  @override
  String get arrived => '已到达';

  @override
  String get failed => '失败';

  @override
  String get paused => '已暂停';

  @override
  String get returnToOrigin => '返回原点';

  @override
  String speedPercent(int percent) {
    return '速度 $percent%';
  }

  @override
  String cpuUsage(String percent) {
    return 'CPU $percent%';
  }

  @override
  String memUsage(String used, String total) {
    return '内存 $used/$total GB';
  }
}
