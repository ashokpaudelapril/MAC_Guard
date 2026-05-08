import AppKit
import SwiftUI
import UserNotifications

// TASK: Real AppDelegate — owns the NSStatusItem, NSPopover, ProcessMonitor, and kill timers.
// HOW CODE SOLVES: Replaces the Week 2 placeholder in main.swift. Sets up the Google-Blue
//                  menu-bar icon, wires ProcessMonitor callbacks, and manages per-PID
//                  DispatchWorkItems so auto-kill timers can be cancelled by Kill Now or Ignore
//                  notification actions without a double-kill (BUG-S05/S06 fix over the spec's
//                  hardcoded 60 s delay and missing timer-cancellation path).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let monitor = ProcessMonitor(settings: AppSettings.shared)

    // ISSUE: Spec schedules auto-kills with DispatchQueue.main.asyncAfter and never stores the
    //        work item, making it impossible to cancel when the user taps Kill Now or Ignore.
    // FIX APPLIED: Store one DispatchWorkItem per PID so handleSpike, executeKill, and
    //              cancelKill can all reach the same item to cancel or replace it (BUG-S06).
    private var pendingKills: [pid_t: DispatchWorkItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupMonitorCallbacks()

        AlertManager.shared.requestPermission()
        AlertManager.shared.onKillNow = { [weak self] pid in
            DispatchQueue.main.async { self?.executeKill(pid: pid) }
        }
        AlertManager.shared.onIgnore = { [weak self] pid in
            DispatchQueue.main.async { self?.cancelKill(pid: pid) }
        }

        SpikeAlertState.shared.onCancel = { [weak self] pid in
            self?.cancelKill(pid: pid)
        }

        monitor.start()
    }

    // MARK: — Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "MacGuard")?
            .withSymbolConfiguration(config)
        button.contentTintColor = NSColor(red: 0.204, green: 0.659, blue: 0.325, alpha: 1) // googleGreen
        button.action = #selector(togglePopover)
        button.target = self
    }

    // TASK: Tint the menu-bar SF Symbol to green / yellow / red matching the Google palette.
    // HOW CODE SOLVES: NSButton.contentTintColor (macOS 10.14+) colours a non-template SF Symbol
    //                  image, giving a persistent coloured icon rather than the default monochrome.
    //                  Called from the onUpdate callback on the main thread after every poll.
    private func updateMenuBarIcon(for level: CPULevel) {
        guard let button = statusItem?.button else { return }
        switch level {
        case .normal:
            button.contentTintColor = NSColor(red: 0.204, green: 0.659, blue: 0.325, alpha: 1)
        case .warning:
            button.contentTintColor = NSColor(red: 0.984, green: 0.737, blue: 0.020, alpha: 1)
        case .critical:
            button.contentTintColor = NSColor(red: 0.918, green: 0.263, blue: 0.208, alpha: 1)
        }
    }

    // MARK: — Popover

    private func setupPopover() {
        let hosting = NSHostingController(rootView:
            ContentView()
                .environmentObject(monitor)
                .environmentObject(AppSettings.shared)
        )
        let p = NSPopover()
        p.contentSize = NSSize(width: 380, height: 480)
        p.behavior = .transient
        p.contentViewController = hosting
        popover = p
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if let popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: — Monitor callbacks

    private func setupMonitorCallbacks() {
        monitor.onSpike = { [weak self] process in
            self?.handleSpike(process)
        }
        monitor.onUpdate = { [weak self] level in
            self?.updateMenuBarIcon(for: level)
        }
    }

    // TASK: Respond to a confirmed CPU spike — send notification and arm the auto-kill timer.
    // HOW CODE SOLVES: Reads killDelay from AppSettings.shared rather than hardcoding 60 s
    //                  (BUG-S05). Stores the DispatchWorkItem in pendingKills[pid] so it can
    //                  be cancelled by Kill Now or Ignore before it fires. Cancels any existing
    //                  item for the same PID first to prevent duplicate timers if the monitor
    //                  re-fires for the same PID (should not happen due to alertedPIDs guard,
    //                  but defensive cancellation costs nothing).
    private func handleSpike(_ process: MonitoredProcess) {
        AlertManager.shared.notifySpike(process)
        Logger.shared.log("ALERT: \(process.name) [PID \(process.pid)] at \(Int(process.cpuPercent))% CPU")

        let pid   = process.pid
        let name  = process.name
        let delay = AppSettings.shared.killDelay

        SpikeAlertState.shared.add(pid: pid, name: name, delay: delay)

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingKills[pid] = nil
            SpikeAlertState.shared.remove(pid: pid)
            guard self.monitor.processes.contains(where: { $0.pid == pid }) else { return }
            Logger.shared.log("AUTO-KILL: \(name) [PID \(pid)]")
            ProcessKiller.kill(pid: pid, name: name)
        }

        pendingKills[pid]?.cancel()
        pendingKills[pid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // TASK: Immediately kill a process and cancel its pending auto-kill timer.
    // HOW CODE SOLVES: Cancels the DispatchWorkItem before killing so the timer callback
    //                  cannot also fire and produce a double-kill log entry (BUG-S06).
    private func executeKill(pid: pid_t) {
        pendingKills[pid]?.cancel()
        pendingKills[pid] = nil
        SpikeAlertState.shared.remove(pid: pid)
        if let process = monitor.processes.first(where: { $0.pid == pid }) {
            Logger.shared.log("KILL-NOW: \(process.name) [PID \(pid)]")
            ProcessKiller.kill(pid: pid, name: process.name)
        }
    }

    // TASK: Cancel the auto-kill timer without killing the process (user chose Ignore).
    // HOW CODE SOLVES: Cancelling the stored DispatchWorkItem prevents the timer from
    //                  firing and killing the process after the user explicitly dismissed
    //                  the alert — the spec has no cancel path (BUG-S06 fix).
    private func cancelKill(pid: pid_t) {
        pendingKills[pid]?.cancel()
        pendingKills[pid] = nil
        SpikeAlertState.shared.remove(pid: pid)
        Logger.shared.log("IGNORED: PID \(pid)")
    }
}
