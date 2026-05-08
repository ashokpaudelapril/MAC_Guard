import Foundation
import UserNotifications

// TASK: Register UNUserNotificationCenter categories, send spike alerts, and handle action responses.
// HOW CODE SOLVES: Owns the UNUserNotificationCenterDelegate so alert logic stays out of AppDelegate.
//                  onKillNow and onIgnore are closures set by AppDelegate so AlertManager can trigger
//                  cancel/kill without holding a back-reference to AppDelegate (avoids retain cycle).
//                  userNotificationCenter(_:didReceive:withCompletionHandler:) is implemented here
//                  to handle the KILL and IGNORE action buttons — the spec omits this handler, which
//                  would leave action buttons silently doing nothing (BUG-S06 fix).
final class AlertManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertManager()

    var onKillNow: ((pid_t) -> Void)?
    var onIgnore:  ((pid_t) -> Void)?

    private let killActionID  = "KILL"
    private let ignoreActionID = "IGNORE"
    private let categoryID    = "CPU_SPIKE"

    // ISSUE: UNUserNotificationCenter.current() crashes when called from an SPM executable
    //        that has no bundle identifier — the notification subsystem requires a registered app.
    // FIX APPLIED: All UNUserNotificationCenter calls are guarded by hasBundle so the app runs
    //              cleanly as a plain `swift run` binary. Notifications will activate automatically
    //              once the app is packaged as a signed .app with a bundle ID in Week 6.
    private var hasBundle: Bool { Bundle.main.bundleIdentifier != nil }

    private override init() {
        super.init()
        guard Bundle.main.bundleIdentifier != nil else { return }
        registerCategory()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // TASK: Register the CPU_SPIKE category with Kill Now / Ignore action buttons.
    // HOW CODE SOLVES: Category registration must happen before any notification is scheduled.
    //                  The KILL action is marked destructive so macOS renders it in red. Called
    //                  once in init so it is guaranteed to be registered before any spike fires.
    private func registerCategory() {
        let kill   = UNNotificationAction(identifier: killActionID,   title: "Kill Now", options: .destructive)
        let ignore = UNNotificationAction(identifier: ignoreActionID, title: "Ignore",   options: [])
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [kill, ignore],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func notifySpike(_ process: MonitoredProcess) {
        guard hasBundle else { return }
        let content = UNMutableNotificationContent()
        content.title = "CPU Spike Detected"
        content.body  = "\(process.name) [PID \(process.pid)] is using \(Int(process.cpuPercent))% CPU"
        content.sound = .default
        content.categoryIdentifier = categoryID
        let request = UNNotificationRequest(
            identifier: "spike-\(process.pid)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // ISSUE: The spec defines notification categories with Kill Now / Ignore actions but omits
    //        the delegate method that handles the user's response — buttons appear but do nothing.
    // FIX APPLIED: Implement userNotificationCenter(_:didReceive:withCompletionHandler:), parse
    //              the PID from the notification identifier, and invoke onKillNow or onIgnore
    //              so AppDelegate can cancel the pending timer and/or kill the process (BUG-S06).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier   // "spike-<pid>"
        if let pidStr = identifier.split(separator: "-").last,
           let pid = pid_t(pidStr) {
            switch response.actionIdentifier {
            case killActionID:
                DispatchQueue.main.async { self.onKillNow?(pid) }
            case ignoreActionID:
                DispatchQueue.main.async { self.onIgnore?(pid) }
            default:
                break
            }
        }
        completionHandler()
    }

    // Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
