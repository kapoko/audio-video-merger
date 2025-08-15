import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Audio Video Merger"

        // Create and add the drop view
        let dropView = DropView(frame: window.contentView!.bounds)
        dropView.autoresizingMask = [.width, .height]
        
        window.contentView?.addSubview(dropView)
        
        window.makeKeyAndOrderFront(nil)
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func buttonClicked(_ sender: NSButton) {
        print("Button was clicked!")
        // You can add your button action here
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
