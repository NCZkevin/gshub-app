import Flutter
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var wifiChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.gshub.sysapp/wifi",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleWiFiCall(call, result: result)
    }
    wifiChannel = channel
  }

  private func handleWiFiCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "joinAP":
      guard
        let arguments = call.arguments as? [String: Any],
        let ssid = arguments["ssid"] as? String,
        let password = arguments["password"] as? String,
        !ssid.isEmpty,
        (8...63).contains(password.count)
      else {
        result(FlutterError(
          code: "INVALID_AP_CREDENTIALS",
          message: "Invalid AP SSID or password",
          details: nil
        ))
        return
      }
      let configuration = NEHotspotConfiguration(
        ssid: ssid,
        passphrase: password,
        isWEP: false
      )
      configuration.joinOnce = false
      NEHotspotConfigurationManager.shared.apply(configuration) { error in
        DispatchQueue.main.async {
          if let error = error as NSError? {
            if error.domain == NEHotspotConfigurationErrorDomain,
              error.code == NEHotspotConfigurationError.alreadyAssociated.rawValue
            {
              result(true)
              return
            }
            result(FlutterError(
              code: "WIFI_JOIN_FAILED",
              message: error.localizedDescription,
              details: error.code
            ))
            return
          }
          result(true)
        }
      }
    case "leaveAP":
      let arguments = call.arguments as? [String: Any]
      if arguments?["forget"] as? Bool == true,
        let ssid = arguments?["ssid"] as? String,
        !ssid.isEmpty
      {
        NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
      }
      result(nil)
    case "openWiFiSettings":
      guard let url = URL(string: UIApplication.openSettingsURLString) else {
        result(nil)
        return
      }
      UIApplication.shared.open(url) { _ in result(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
