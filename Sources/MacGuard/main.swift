import AppKit

// TASK: Entry point for the MacGuard menu-bar app.
// HOW CODE SOLVES: Boots NSApplication with .accessory activation policy (no Dock icon,
//                  no main menu bar) then hands control to AppDelegate (AppDelegate.swift),
//                  which sets up the NSStatusItem, NSPopover, ProcessMonitor, and kill timers.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
