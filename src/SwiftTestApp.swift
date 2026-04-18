import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var mainWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    showMainWindow()

    let startupPaths = startupFilePaths()
    if !startupPaths.isEmpty {
      enqueueOpenedFiles(startupPaths)
    }
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

    let window = NSWindow(contentViewController: hostingController)
    window.setContentSize(NSSize(width: 500, height: 400))
    window.minSize = NSSize(width: 500, height: 400)
    window.title = ""
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)

    mainWindow = window
    NSApp.activate(ignoringOtherApps: true)
  }
}

@main
struct SwiftTestApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
