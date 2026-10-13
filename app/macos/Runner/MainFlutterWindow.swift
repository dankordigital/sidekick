import AVFoundation
import ApplicationServices
import Cocoa
import QuartzCore
import UserNotifications
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let native = SidekickNative()
  private var ble: SidekickBLE?
  private var p2p: SidekickP2P?

  /// Keeps App Nap away: hidden in the menu bar, macOS would otherwise slow
  /// Sidekick's timers and network down, and paired devices would lose it
  /// or wait seconds for an answer. The Mac still sleeps as usual.
  private let awake = ProcessInfo.processInfo.beginActivity(
    options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
    reason: "Sidekick stays reachable for your paired devices")

  /// Closing hides the window to the menu bar (set from Dart at start);
  /// only Quit Sidekick (or Command-Q) quits. Caught
  /// at every step, since a close reaches the window more than one way: here
  /// (performClose and close), window_manager's delegate (Dart then calls
  /// hideToMenuBar), and AppDelegate never quits after the last window.
  var keepInMenuBar = false
  private var inMenuBar = false

  /// Hidden, still running and receiving, still in the Dock.
  func hideToMenuBar() {
    inMenuBar = true
    orderOut(nil)
    native.channel?.invokeMethod("closedToMenuBar", arguments: nil)
  }

  // The red button and Command-W.
  override func performClose(_ sender: Any?) {
    guard keepInMenuBar else { return super.performClose(sender) }
    hideToMenuBar()
  }

  override func close() {
    guard keepInMenuBar else { return super.close() }
    hideToMenuBar()
  }

  // Back on screen (the menu bar's Open Sidekick, or a click on the Dock).
  override func makeKeyAndOrderFront(_ sender: Any?) {
    if inMenuBar {
      inMenuBar = false
      native.channel?.invokeMethod("openedFromMenuBar", arguments: nil)
    }
    super.makeKeyAndOrderFront(sender)
  }

  /// Settings → Theme → Liquid Glass (macOS 26): Apple's glass behind the
  /// whole window, the Flutter view see-through on top of it.
  private var glassView: NSView?

  func setGlass(_ on: Bool) {
    guard let content = contentView, let frameView = content.superview else { return }
    glassView?.removeFromSuperview()
    glassView = nil
    let flutter = contentViewController as? FlutterViewController
    guard on else {
      isOpaque = true
      backgroundColor = .windowBackgroundColor
      flutter?.backgroundColor = .windowBackgroundColor
      return
    }
    let glass: NSView
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      glass = NSGlassEffectView()
    } else {
      glass = Self.vibrancy()
    }
    #else
    glass = Self.vibrancy()
    #endif
    glass.frame = frameView.bounds
    glass.autoresizingMask = [.width, .height]
    frameView.addSubview(glass, positioned: .below, relativeTo: content)
    glassView = glass
    isOpaque = false
    backgroundColor = .clear
    flutter?.backgroundColor = .clear
  }

  /// Before macOS 26: the desktop, blurred, behind the window.
  private static func vibrancy() -> NSView {
    let blur = NSVisualEffectView()
    blur.material = .underWindowBackground
    blur.blendingMode = .behindWindow
    blur.state = .active
    return blur
  }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 420, height: 560)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "sidekick/macos", binaryMessenger: flutterViewController.engine.binaryMessenger)
    let native = self.native
    native.window = self
    native.channel = channel
    channel.setMethodCallHandler { call, result in native.handle(call, result: result) }
    ble = SidekickBLE.register(messenger: flutterViewController.engine.binaryMessenger)
    p2p = SidekickP2P.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// Posts to Notification Center, and shows banners even while Sidekick is
/// the app in front.
final class MacNotifications: NSObject, UNUserNotificationCenterDelegate {
  static let shared = MacNotifications()
  private var asked = false

  func show(title: String, subtitle: String, body: String) {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    let post = {
      let content = UNMutableNotificationContent()
      content.title = title
      content.subtitle = subtitle
      content.body = body
      center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
    if asked { return post() }
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      self.asked = true
      if granted { post() }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
