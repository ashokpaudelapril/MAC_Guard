import AppKit

// TASK: Entry point for the MacGuard menu-bar app.
// HOW CODE SOLVES: Boots NSApplication on the main thread, attaches a placeholder
//                  AppDelegate, and sets activation policy to `.accessory` so the app has
//                  no Dock icon and no main menu — only a menu-bar status item (added in
//                  Week 3). `app.run()` blocks the main thread on the AppKit run loop;
//                  the user terminates the process with Ctrl-C until a Quit menu item
//                  is wired up in Week 3.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

// TASK: Week 1 placeholder for the real AppDelegate that lands in Week 3.
// HOW CODE SOLVES: Implements just enough of NSApplicationDelegate to confirm the app
//                  reached the run loop. Prints a sentinel line that the Week 1 smoke
//                  test greps for. The Week 3 AppDelegate (spec section 4.2) replaces
//                  this entire class with the menu-bar status item, ProcessMonitor
//                  wiring, and dashboard window orchestration.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("MacGuard launched")
    }
}
