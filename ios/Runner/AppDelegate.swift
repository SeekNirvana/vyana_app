import Flutter
import UIKit
import YCProductSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ringDeviceChannel: FlutterMethodChannel?
  private var backupExclusionChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Item 102: Vyana's data never goes into an iCloud device backup. Done
    // at every launch, because the flag lives on the file and is lost when
    // a file or folder is recreated. Dart asks again once storage is set
    // up, which covers folders created after this point.
    Self.excludeUserDataFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Sets isExcludedFromBackup on everything that holds the user's data:
  /// Application Support (the vault, the database, meal photos, models),
  /// Documents, and the preferences file. Returns how many were marked.
  @discardableResult
  static func excludeUserDataFromBackup(extraPaths: [String] = []) -> Int {
    let fm = FileManager.default
    var urls: [URL] = []
    for dir in [FileManager.SearchPathDirectory.applicationSupportDirectory, .documentDirectory] {
      if let url = fm.urls(for: dir, in: .userDomainMask).first {
        urls.append(url)
      }
    }
    if let library = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
      let prefs = library.appendingPathComponent("Preferences", isDirectory: true)
      urls.append(prefs)
      if let id = Bundle.main.bundleIdentifier {
        urls.append(prefs.appendingPathComponent("\(id).plist"))
      }
    }
    for path in extraPaths {
      urls.append(URL(fileURLWithPath: path))
    }

    var marked = 0
    for original in urls {
      guard fm.fileExists(atPath: original.path) else { continue }
      var url = original
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        marked += 1
      } catch {
        NSLog("[Vyana] could not exclude \(url.path) from backup: \(error)")
      }
    }
    return marked
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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VyanaBackupExclusion") {
      let channel = FlutterMethodChannel(
        name: "vyana/backup_exclusion",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "excludeFromBackup":
          let arguments = call.arguments as? [String: Any]
          let paths = arguments?["paths"] as? [String] ?? []
          result(Self.excludeUserDataFromBackup(extraPaths: paths))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      backupExclusionChannel = channel
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
