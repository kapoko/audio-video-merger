import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            guard let window = NSApp.windows.first else {
                return
            }

            window.setContentSize(NSSize(width: 500, height: 400))
            window.minSize = NSSize(width: 500, height: 400)
            window.title = ""
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
    }
}

@main
struct SwiftTestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
