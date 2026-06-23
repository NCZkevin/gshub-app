# GSHUB App 运行文档

本文档说明如何在本地运行 GSHUB Flutter App 的不同平台版本。

## 前置条件

先确认 Flutter 环境可用：

```bash
flutter doctor
flutter pub get
```

常用设备检查命令：

```bash
flutter devices
```

如果要运行 iOS 或 macOS，请在 macOS 上安装 Xcode，并完成首次授权：

```bash
sudo xcodebuild -license
```

如果 iOS/macOS CocoaPods 依赖异常，可分别执行：

```bash
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```

## Web

开发运行：

```bash
flutter run -d chrome
```

指定本地 web-server 端口：

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 54931
```

构建 Web 产物：

```bash
flutter build web
```

产物目录：

```text
build/web
```

## iOS

列出可用模拟器或真机：

```bash
flutter devices
```

运行到指定 iOS 设备：

```bash
flutter run -d <device-id>
```

构建 iOS release：

```bash
flutter build ios
```

打开 Xcode 工程：

```bash
open ios/Runner.xcworkspace
```

注意：真机运行通常需要在 Xcode 里配置 Team、Bundle Identifier 和签名。

## Android

启动 Android 模拟器或连接真机后，查看设备：

```bash
flutter devices
```

运行到指定 Android 设备：

```bash
flutter run -d <device-id>
```

构建 APK：

```bash
flutter build apk
```

构建 App Bundle：

```bash
flutter build appbundle
```

常见产物位置：

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

## macOS

运行 macOS 桌面版：

```bash
flutter run -d macos
```

构建 macOS release：

```bash
flutter build macos
```

产物目录通常在：

```text
build/macos/Build/Products/Release
```

如果提示未启用桌面支持：

```bash
flutter config --enable-macos-desktop
```

## Windows

在 Windows 开发机上启用桌面支持：

```bash
flutter config --enable-windows-desktop
```

运行 Windows 桌面版：

```bash
flutter run -d windows
```

构建 Windows release：

```bash
flutter build windows
```

产物目录通常在：

```text
build/windows/x64/runner/Release
```

注意：Windows 构建需要 Visual Studio 的 Desktop development with C++ 工作负载。

## Linux

在 Linux 开发机上启用桌面支持：

```bash
flutter config --enable-linux-desktop
```

运行 Linux 桌面版：

```bash
flutter run -d linux
```

构建 Linux release：

```bash
flutter build linux
```

产物目录通常在：

```text
build/linux/x64/release/bundle
```

常见依赖包括 clang、cmake、ninja-build、pkg-config、GTK 开发库等，缺少时按 `flutter doctor` 提示安装。

## 常用开发命令

格式化：

```bash
dart format lib test
```

静态分析：

```bash
flutter analyze lib test
```

运行测试：

```bash
flutter test
```

清理构建缓存：

```bash
flutter clean
flutter pub get
```

## 运行参数

如果需要给 Dart 代码传入编译期变量，可以使用 `--dart-define`：

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080
```

当前 App 的机器人展位连接主要在应用内“机器人展位/设置”页面配置，包括展位名称、服务器地址和 API Token。

## 常见问题

如果 `flutter run` 提示没有设备，先执行：

```bash
flutter devices
```

如果 iOS/macOS 依赖错误，先尝试：

```bash
cd ios && pod install && cd ..
cd macos && pod install && cd ..
```

如果 Web 构建出现 WASM dry-run 警告，但 `flutter build web` 最终成功，通常可以先忽略；这是依赖包对 WebAssembly 的兼容性提示，不影响常规 JavaScript Web 构建。

如果分析命令扫描到 `build/` 下第三方 checkout 的错误，优先使用：

```bash
flutter analyze lib test
```
