import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
  UNUserNotificationCenterDelegate
{
  private var mainWindow: NSWindow?
  private var minimumFrameSize = NSSize(width: 300, height: 150)

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    if (Bundle.main.object(forInfoDictionaryKey: "CFBundlePackageType") as? String) == "APPL" {
      configureNotifications()
    }

    showMainWindow()

    let startupPaths = startupFilePaths()
    if !startupPaths.isEmpty {
      enqueueOpenedFiles(startupPaths)
    }
  }

  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(macOS 11.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  private func configureNotifications() {
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  func application(_ sender: NSApplication, openFiles filenames: [String]) {
    showMainWindow()
    enqueueOpenedFiles(filenames)
    sender.reply(toOpenOrPrint: .success)
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    showMainWindow()
    DropViewModel.shared.handleDroppedFileURLs(urls)
  }

  func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    showMainWindow()
    enqueueOpenedFiles([filename])
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  private func startupFilePaths() -> [String] {
    let arguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
    return arguments.filter { argument in
      !argument.hasPrefix("-") && FileManager.default.fileExists(atPath: argument)
    }
  }

  private func enqueueOpenedFiles(_ paths: [String]) {
    let resolvedURLs = paths.compactMap(resolveDroppedFileURL)
    guard !resolvedURLs.isEmpty else {
      return
    }

    DropViewModel.shared.handleDroppedFileURLs(resolvedURLs)
  }

  private func resolveDroppedFileURL(_ value: String) -> URL? {
    if let fileURL = URL(string: value), fileURL.isFileURL {
      return fileURL
    }

    let pathURL = URL(fileURLWithPath: value)
    if FileManager.default.fileExists(atPath: pathURL.path) {
      return pathURL
    }

    return nil
  }

  private func showMainWindow() {
    if let existingWindow = mainWindow {
      existingWindow.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let contentView = ContentView()
    let hostingController = NSHostingController(rootView: contentView)

    let initialContentSize = NSSize(width: 500, height: 400)
    let minimumContentSize = NSSize(width: 300, height: 150)

    let window = NSWindow(contentViewController: hostingController)
    window.setContentSize(initialContentSize)
    window.contentMinSize = minimumContentSize
    let minimumFrame = window.frameRect(
      forContentRect: NSRect(origin: .zero, size: minimumContentSize)
    )
    minimumFrameSize = minimumFrame.size
    window.minSize = minimumFrameSize
    window.delegate = self
    window.title = ""
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.center()
    window.makeKeyAndOrderFront(nil)

    mainWindow = window
    NSApp.activate(ignoringOtherApps: true)
  }

  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
    NSSize(
      width: max(frameSize.width, minimumFrameSize.width),
      height: max(frameSize.height, minimumFrameSize.height)
    )
  }
}

@main
struct AudioVideoMergerApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
