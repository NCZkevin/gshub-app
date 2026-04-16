# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app
flutter run

# Build
flutter build macos         # macOS desktop
flutter build apk           # Android
flutter build ios           # iOS

# Lint & analyze
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Code generation (freezed models, Riverpod providers, JSON serializers)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code gen during development
dart run build_runner watch --delete-conflicting-outputs

# Regenerate i18n ARB output (after editing lib/core/l10n/*.arb)
flutter gen-l10n
```

Generated files (`*.freezed.dart`, `*.g.dart`) are committed to the repo. Run `build_runner` after editing any `@freezed` model, `@riverpod` provider, or `@JsonSerializable` class.

## Architecture

### Feature-first structure

Code under `lib/` follows a feature-first layout:

```
lib/
  app/           – App entry (App widget, GoRouter, AdaptiveShell, theme)
  core/          – Infrastructure: DioClient, WsConnectionManager, utils, l10n
  features/
    connection/  – Robot connection management (CRUD + active connection)
    dashboard/   – Hub/robot status, container/service controls
    navigation/  – Map selection, nav container, waypoint navigation
    mapping/     – Mapping session control, map management
    logs/        – Log file listing and download
    settings/    – Theme, locale, token verification
  shared/
    domain/      – Cross-feature freezed models (app_models.dart)
    providers/   – device_provider, system_health_provider
    widgets/     – JoystickWidget, OccupancyMap, VideoViewWidget
```

Each feature is split into three layers:
- `data/` — Repository classes that call `DioClient` (REST) or `WsConnectionManager` (WebSocket).
- `domain/` — Freezed data models with JSON serialization.
- `presentation/` — Riverpod providers (Notifier/AsyncNotifier) and Screen widgets.

### Provider dependency chain

```
sharedPreferencesProvider (injected at ProviderScope)
  └─ connectionRepositoryProvider
       └─ connectionProvider (NotifierProvider<ConnectionState>)
            └─ activeConnectionProvider
                 └─ dioClientFutureProvider (FutureProvider<DioClient?>)
                      └─ feature repository providers (e.g. dashboardRepositoryProvider)
                           └─ feature AsyncNotifier providers

wsManagerProvider (Provider<WsConnectionManager>)
  – depends on activeConnectionProvider; auto-connects/disconnects on switch
```

When the active connection changes (`activate()` or `update()`), `dioClientProvider` and `wsManagerProvider` are invalidated, causing downstream providers to rebuild.

### HTTP API layer

`DioClient` (`lib/core/api/dio_client.dart`) wraps Dio with:
- Base URL set to `{baseUrl}/v1/api`
- Bearer token via `_AuthInterceptor`
- `_EnvelopeInterceptor`: all responses have the shape `{code, data, msg}`. Code 0 = success (unwraps to `data`); non-zero rejects with `ApiException`.
- `getBytes()` for binary downloads (PGM maps, ZIP archives).

### WebSocket layer

`WsConnectionManager` (`lib/core/websocket/ws_connection_manager.dart`) maintains two persistent WebSocket connections:
- **Odometry** (`/tower/odometry/robot_odometry`) — emits `RobotOdometry` on `odometryStream`.
- **Control** (`/tower/control/cmd_vel`) — outgoing cmd_vel with 100 ms cooldown; use `sendCmdVel(linearX, angularZ)` or `sendStop()`.

Both channels use exponential backoff reconnection (2–30 s). Generation counters prevent stale reconnect callbacks after `disconnect()`.

`WsFrame` (`lib/core/websocket/ws_frame.dart`) is a binary frame protocol used by the terminal WebSocket: 1-byte type prefix (input=0x00, resize=0x01, output=0x02, error=0x03) followed by payload.

### Adaptive navigation shell

`AdaptiveShell` uses `NavigationBar` (bottom) when `width < 600 px` and `NavigationRail` (side) otherwise. The router redirects to `/connection` whenever `connectionProvider.activeId == null`.

### Storage

- `SharedPreferences` — connection list JSON and active connection ID.
- `FlutterSecureStorage` — API tokens keyed as `api_token_{id}` and terminal tokens as `terminal_token_{id}`.

### State management conventions

- Providers in `presentation/` use Riverpod's `Notifier` / `AsyncNotifier` (manual, no `@riverpod` codegen at present).
- `AutoDisposeAsyncNotifier` is used for feature providers that poll (dashboardProvider polls hub info every 3 s; systemHealthProvider is manually started/stopped).
- `FutureProvider` is used for one-shot async reads (dioClientFutureProvider, deviceInfoProvider).

### Localization

ARB files live in `lib/core/l10n/`. The template is `app_zh.arb`; English strings are in `app_en.arb`. After editing ARBs, run `flutter gen-l10n` to regenerate `app_localizations.dart`.
