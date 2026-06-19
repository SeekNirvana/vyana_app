import Flutter
import UIKit
import YCProductSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ringDeviceChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VyanaRingDevice") {
      let channel = FlutterMethodChannel(
        name: "vyana/ring_device",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "setDeviceName":
          guard let self = self else {
            result(FlutterError(
              code: "unavailable",
              message: "Ring device channel is unavailable",
              details: nil
            ))
            return
          }
          self.setDeviceName(call: call, result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      ringDeviceChannel = channel
    }
  }

  private func setDeviceName(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    let cleanName = (arguments?["name"] as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) ?? ""

    guard !cleanName.isEmpty else {
      result([
        "statusCode": Self.pluginStateFailed,
        "message": "Ring name is required"
      ])
      return
    }

    YCProduct.setDeviceName(name: cleanName) { state, response in
      DispatchQueue.main.async {
        result([
          "statusCode": Self.pluginStatusCode(state),
          "sdkState": String(describing: state),
          "message": Self.deviceNameMessage(state),
          "data": String(describing: response ?? "")
        ])
      }
    }
  }

  private static func pluginStatusCode(_ state: YCProductState) -> Int {
    if state == .succeed {
      return pluginStateSucceed
    }
    if state == .unavailable {
      return pluginStateUnavailable
    }
    return pluginStateFailed
  }

  private static func deviceNameMessage(_ state: YCProductState) -> String {
    if state == .succeed {
      return "Ring accepted name change"
    }
    if state == .unavailable {
      return "Ring name change is unavailable"
    }
    return "Ring rejected name change"
  }

  private static let pluginStateSucceed = 0
  private static let pluginStateFailed = 1
  private static let pluginStateUnavailable = 2
}
