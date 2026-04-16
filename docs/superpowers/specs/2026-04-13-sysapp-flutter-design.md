# sysapp Flutter 多端应用设计文档

**日期：** 2026-04-13  
**项目：** sysapp（Flutter）← sys-controller-web（React + TypeScript）  
**范围：** MVP — 仪表盘、导航、建图、日志、设置  
**目标平台：** iOS、Android（手机/平板）、macOS、Windows、Linux（桌面端）

---

## 背景与目标

`sys-controller-web` 是一套完整的机器人控制系统 Web 前端，实现了实时 WebSocket 控制、2D 占用地图、Janus WebRTC 视频流、SSH 终端、语义搜索等功能。目标是将其核心功能迁移到 Flutter 多端 App，达到商业化发布标准（App Store / Google Play 上架、i18n 国际化、崩溃监控）。

后端 API 不变，Flutter 只替换前端，保持与现有 `/v1/api/` REST + WebSocket + SSE 接口兼容。

---

## 一、架构方案

**选型：Riverpod + GoRouter + Clean Architecture（三层分层）**

每个 feature 独立分层：

```
feature/
├── data/
│   ├── xxx_repository.dart    # 调用 API / WebSocket，返回 Dart 对象
│   └── xxx_api.dart           # Dio 请求封装
├── domain/
│   └── xxx_model.dart         # 纯 Dart 数据模型（Freezed 不可变）
└── presentation/
    ├── xxx_screen.dart        # 页面 Widget
    └── xxx_provider.dart      # Riverpod Provider（状态 + 业务逻辑）
```

UI 层只依赖 Provider，Provider 只依赖 Repository，Repository 负责网络/WS。

---

## 二、项目结构

```
lib/
├── main.dart
├── app/
│   ├── app.dart               # MaterialApp + GoRouter 根配置
│   ├── router.dart            # 全局路由表（GoRouter）
│   └── theme.dart             # 亮/暗主题定义
├── core/
│   ├── api/
│   │   ├── dio_client.dart    # Dio 实例 + Bearer Token 拦截器 + 错误处理
│   │   └── api_error.dart     # ApiError（code, msg, data 信封解包）
│   ├── websocket/
│   │   ├── ws_connection_manager.dart  # 统一 WS 管理（自动重连/展位切换）
│   │   └── ws_frame.dart               # 终端二进制帧协议编解码
│   ├── l10n/
│   │   ├── app_en.arb         # 英文文案
│   │   └── app_zh.arb         # 中文文案（默认）
│   └── utils/
│       ├── pgm_parser.dart    # PGM 图像格式解析 → Uint8List
│       └── map_coords.dart    # 像素坐标 ↔ 世界坐标转换
├── features/
│   ├── connection/            # 展位管理（多机器人地址 + Token 配置）
│   ├── dashboard/             # 仪表盘
│   ├── navigation/            # 导航
│   ├── mapping/               # 建图
│   ├── logs/                  # 日志
│   └── settings/              # 设置
└── shared/
    ├── widgets/
    │   ├── occupancy_map.dart  # CustomPainter 2D 占用地图
    │   ├── joystick.dart       # 虚拟摇杆 Widget
    │   └── video_view.dart     # RTCVideoView 封装
    └── providers/
        ├── device_provider.dart   # 设备信息（跨 feature 共享）
        └── system_health_provider.dart  # CPU/内存 SSE 流（跨 feature）
```

---

## 三、路由设计（GoRouter）

```
/                      → 重定向：无展位时 → /connection，有展位 → /dashboard
/connection            → 展位管理页（添加/切换机器人地址）
/dashboard             → 仪表盘
/navigation            → 导航页
/mapping               → 建图页
/logs                  → 日志页
/settings              → 设置页
```

`ShellRoute` 包裹 dashboard/navigation/mapping/logs/settings，提供统一壳层导航：

- **手机（width < 600）**：底部 `NavigationBar`，5 个 Tab，顶部 AppBar 右侧显示展位切换
- **平板 / 桌面（width ≥ 600）**：左侧 `NavigationRail` / `NavigationDrawer`，常驻显示机器人连接状态和展位名

---

## 四、展位（多机器人）管理

- 本地持久化（`shared_preferences`）存储展位列表：`{name, baseUrl, apiToken, terminalToken}`
- Token 值用 `flutter_secure_storage` 加密存储（iOS Keychain / Android Keystore / macOS Keychain）
- 切换展位时：断开所有 WebSocket → 更新全局 base URL → 重新初始化连接
- 首次启动引导：`/connection` 页填写 IP 地址和 Token，验证成功（`POST /auth/verify_token`）后保存

---

## 五、实时通信层

### WebSocket 连接管理器（`WsConnectionManager`）

统一管理所有 WebSocket，支持指数退避自动重连，展位切换时全部断开重连：

```dart
class WsConnectionManager {
  // 里程计（机器人实时位置）
  Stream<RobotOdometry> get odometryStream

  // 控制指令发送（摇杆 → 速度指令）
  void sendCmdVel(double linearX, double angularZ)

  // 终端帧（MVP V2）
  Stream<WsFrame> get terminalStream
  void sendTerminalInput(Uint8List data)

  // 点云帧（MVP V2）
  Stream<Uint8List> get pointCloudStream
}
```

### 视频流（Janus WebRTC）

- 使用 `flutter_webrtc` 包，与 Janus Gateway HTTP JSON RPC 信令协议对接
- 渲染：`RTCVideoRenderer` → `RTCVideoView` Widget
- 支持平台：iOS / Android / macOS / Windows / Linux

### SSE（系统健康流）

- `dio` 流式请求替代浏览器 EventSource
- 推送 CPU 使用率、内存用量，驱动仪表盘实时指标

---

## 六、功能模块详细设计

### 6.1 仪表盘（Dashboard）

| 组件 | 实现方案 |
|------|---------|
| 虚拟摇杆 | `flutter_joystick` 包；平板/桌面响应式切换为 D-Pad 按钮 |
| 速度调节 | `Slider` Widget，实时调节最大线速度系数 |
| 视频流 | `RTCVideoView`（Janus WebRTC） |
| CPU/内存 | SSE Provider → `LinearProgressIndicator` |
| 服务开关 | `Switch` + REST API；状态颜色徽章（running/stopped/offline） |
| 模型容器 | `ListView` + `Switch`；`GET /runtime/containers?class=model` |

仪表盘布局：
- 手机竖屏：上下滚动卡片
- 平板/桌面：三列网格（遥控 / 视频+状态 / 终端占位）

### 6.2 导航页（Navigation）

状态机：`checking → setup → active`

**Setup 视图：**
- 地图选择下拉 (`GET /maps`)
- 重定位开关
- 启动导航按钮 (`POST /nav/container/start`)
- PGM 地图预览

**Active 视图：**
- 占用格栅地图（`CustomPainter`）：
  - 解析 PGM 文件为灰度像素
  - 叠加层：机器人位置（来自里程计 WS）、规划路径、目标点、航点
  - 交互：`InteractiveViewer` 缩放/平移，`GestureDetector.onTapDown` 像素→世界坐标转换
- 三种模式 Tab：单点导航 / 路径导航 / 路径录制
- 导航状态横幅：navigating / arrived / failed / paused
- 控制按钮：暂停 / 继续 / 停止 / 返回原点

### 6.3 建图页（Mapping）

| 视图 | 内容 |
|------|------|
| 列表 | 已有地图卡片，点击查看文件，支持下载 ZIP / 删除 |
| 启动 | 输入地图名称 → `POST /mapping/container/start` |
| 进行中 | 采集点数、传感器状态、2D 地图可用性；复用摇杆 + 视频 Widget |

MVP 暂缓：3D 点云查看器、语义搜索（V2 迭代）

### 6.4 日志页（Logs）

- 平板/桌面：左右双栏；手机：列表 → 详情两级导航
- 文件列表：文件名、大小、修改时间、删除按钮
- 日志内容：`SelectableText` + 等宽字体，支持文本复制
- 搜索过滤：`TextField` + Riverpod 派生 Provider 实时过滤
- 自动刷新：可配置间隔（10s/30s/60s/5min），`Timer.periodic`

### 6.5 设置页

- 展位管理（增删改，验证连通性）
- API Token 验证 (`POST /auth/verify_token`)
- Terminal Token 配置
- 语言切换（跟随系统 / 手动选中英文）
- 主题切换（亮 / 暗 / 跟随系统）
- 关于（版本号、构建号）

---

## 七、商业化配套

### 7.1 依赖包清单

| 分类 | 包 | 用途 |
|------|----|----|
| 状态管理 | `flutter_riverpod` `riverpod_annotation` `riverpod_generator` | Provider + 代码生成 |
| 路由 | `go_router` | 导航 + 深链接 |
| HTTP | `dio` | REST API + 拦截器 |
| WS/WebRTC | `web_socket_channel` `flutter_webrtc` | WebSocket + 视频流 |
| 本地存储 | `shared_preferences` | 展位配置持久化 |
| 安全存储 | `flutter_secure_storage` | Token 加密存储 |
| 虚拟摇杆 | `flutter_joystick` | 移动端摇杆控制 |
| i18n | `flutter_localizations` `intl` | 中英文国际化 |
| 崩溃监控 | `firebase_crashlytics` `firebase_performance` | 崩溃上报 + 性能追踪 |
| 数据模型 | `freezed` `freezed_annotation` `json_serializable` | 不可变模型 + JSON 序列化 |
| SVG | `flutter_svg` | 图标支持 |
| 代码生成 | `build_runner` | 构建时代码生成 |

### 7.2 国际化（i18n）

- `lib/core/l10n/app_zh.arb`（默认中文）和 `app_en.arb`（英文）
- 设置页提供语言切换，优先跟随系统语言
- 涵盖所有 UI 文案：按钮、标签、错误消息、提示文字

### 7.3 崩溃监控

- `FlutterError.onError` + `PlatformDispatcher.onError` 捕获所有未处理异常
- 附带上下文：当前路由、展位名（脱敏）、Flutter/App 版本
- Firebase Crashlytics 支持 iOS / Android / macOS / Windows

### 7.4 安全存储

- API Token 和 Terminal Token 仅存于 `flutter_secure_storage`（平台加密存储）
- 不写入 SharedPreferences 明文

### 7.5 发布准备

| 平台 | 配置 |
|------|------|
| iOS | Runner target，签名证书，AppDelegate，Info.plist 补充权限 |
| Android | release build，proguard 规则，签名 keystore，minSdk 配置 |
| macOS | Hardened Runtime，Sandbox entitlements，App Sandbox 网络权限 |
| Windows | MSIX 打包（`msix` 包），应用图标 |
| Linux | AppImage / Debian 包（视目标渠道） |

---

## 八、MVP 范围与 V2 迭代

### MVP（当前目标）

- [x] 展位管理 + 多机器人切换
- [x] 仪表盘（摇杆控制 + 服务开关 + 视频流 + 系统指标）
- [x] 导航（地图选择 + 单点/路径导航 + 实时地图 + 控制）
- [x] 建图（启停 + 状态监控 + 地图列表）
- [x] 日志管理
- [x] 设置（Token + 展位 + 语言 + 主题）
- [x] i18n（中/英）
- [x] Crashlytics 崩溃监控
- [x] App Store / Google Play 发布配置

### V2（后续迭代）

- [ ] SSH 终端（`xterm`-equivalent via `flutter_pty` 或 WebSocket 二进制帧）
- [ ] 3D 点云查看器（`flutter_gl` + 自定义 GLSL 渲染器）
- [ ] 语义搜索（NLP 查询 + Base64 图片展示）
- [ ] 地图编辑器（Canvas 绘制 PGM）
- [ ] 推送通知（导航完成、建图完成、系统告警）
- [ ] 本地录制（导航轨迹回放）

---

## 九、验证方案

1. **单元测试：** Repository 层测试（mock HTTP/WS），Provider 测试（mock Repository）
2. **Widget 测试：** OccupancyMap CustomPainter 渲染测试，Joystick 输入测试
3. **集成测试：** 真实设备接入 sys-controller 后端，验证 WebSocket 控制 → 机器人响应
4. **平台验证：**
   - iOS Simulator + 真机
   - Android Emulator + 真机
   - macOS 本机运行
   - Windows VM 或真机
5. **发布前检查：** `flutter build ios --release`，`flutter build apk --release`，`flutter build macos --release`，`flutter build windows --release` 全部通过无警告
