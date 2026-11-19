import Flutter
import UIKit
import UniformTypeIdentifiers
import YCProductSDK

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var ringDeviceChannel: FlutterMethodChannel?
  private var backupExclusionChannel: FlutterMethodChannel?
  private var backupFolderChannel: FlutterMethodChannel?
  private let backupFolder = BackupFolderBridge()

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VyanaBackupFolder") {
      let channel = FlutterMethodChannel(
        name: "vyana/backup_folder",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.backupFolder.handle(call, result: result)
          ?? result(FlutterMethodNotImplemented)
      }
      backupFolderChannel = channel
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


/// Item 108: the weekly backup's folder, kept the way iOS allows.
///
/// The folder used to be stored as a plain path from the picker. A folder
/// outside the app's sandbox (Files, iCloud Drive) can only be reached
/// again through a security-scoped bookmark, so the next week's run found
/// the path "no longer reachable". This picks the folder, keeps a bookmark
/// to it (sent to Dart as "bookmark:<base64>"), and resolves it with
/// start/stopAccessingSecurityScopedResource around every read and write.
final class BackupFolderBridge: NSObject, UIDocumentPickerDelegate {
  private var pendingPick: FlutterResult?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "pick" {
      pick(result: result)
      return
    }
    let args = call.arguments as? [String: Any]
    guard let token = args?["folder"] as? String else {
      result(FlutterError(code: "bad_args", message: "No folder", details: nil))
      return
    }
    DispatchQueue.global(qos: .utility).async {
      let value = self.run(call.method, token: token, args: args)
      DispatchQueue.main.async { result(value) }
    }
  }

  private func run(_ method: String, token: String, args: [String: Any]?) -> Any? {
    guard let url = resolve(token) else {
      return method == "reachable" ? false : FlutterError(
        code: "unreachable", message: "That folder is no longer reachable", details: nil)
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    var isDir: ObjCBool = false
    let exists = fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    switch method {
    case "reachable":
      return exists && fm.isWritableFile(atPath: url.path)
    case "list":
      guard exists else { return FlutterError(code: "unreachable", message: nil, details: nil) }
      return (try? fm.contentsOfDirectory(atPath: url.path)) ?? []
    case "write":
      guard let name = args?["name"] as? String,
            let data = args?["bytes"] as? FlutterStandardTypedData else {
        return FlutterError(code: "bad_args", message: "No name or bytes", details: nil)
      }
      do {
        try data.data.write(to: url.appendingPathComponent(name), options: .atomic)
        return true
      } catch {
        return FlutterError(code: "io", message: error.localizedDescription, details: nil)
      }
    case "delete":
      guard let name = args?["name"] as? String else {
        return FlutterError(code: "bad_args", message: "No name", details: nil)
      }
      return (try? fm.removeItem(at: url.appendingPathComponent(name))) != nil
    default:
      return FlutterMethodNotImplemented
    }
  }

  private func resolve(_ token: String) -> URL? {
    guard token.hasPrefix("bookmark:"),
          let data = Data(base64Encoded: String(token.dropFirst("bookmark:".count))) else {
      return nil
    }
    var stale = false
    return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil,
                    bookmarkDataIsStale: &stale)
  }

  private func pick(result: @escaping FlutterResult) {
    guard pendingPick == nil else {
      result(FlutterError(code: "busy", message: "A folder is already being chosen", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(nil)
      return
    }
    pendingPick = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController,
                      didPickDocumentsAt urls: [URL]) {
    let result = pendingPick
    pendingPick = nil
    guard let url = urls.first else {
      result?(nil)
      return
    }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil,
                                          relativeTo: nil)
      result?("bookmark:" + bookmark.base64EncodedString())
    } catch {
      NSLog("[Vyana] could not keep a bookmark to the backup folder: \(error)")
      result?(nil)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingPick?(nil)
    pendingPick = nil
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
