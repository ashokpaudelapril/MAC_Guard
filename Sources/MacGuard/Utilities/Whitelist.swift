import Foundation

// TASK: Single source of truth for the three protected system-process names and whitelist helpers.
// HOW CODE SOLVES: The same ["kernel_task", "WindowServer", "launchd"] array was duplicated in
//                  AppSettings.whitelistDefaults, ProcessKiller.systemProtected, and
//                  SettingsView.protectedDefaults — three copies that could silently drift apart.
//                  Centralising here means a change to the protected set is made once and
//                  enforced everywhere: the UI, the runtime kill guard, and settings persistence.
enum Whitelist {
    static let protectedDefaults: [String] = ["kernel_task", "WindowServer", "launchd"]

    // TASK: Check whether a process name is in the immutable protected set.
    // HOW CODE SOLVES: Case-sensitive exact match per SECURITY.md whitelist integrity rules.
    //                  Used by ProcessKiller before Darwin.kill and by SettingsView to disable
    //                  the Remove button for protected entries.
    static func isProtected(_ name: String) -> Bool {
        protectedDefaults.contains(name)
    }

    // TASK: Merge user-supplied entries with the immutable protected defaults.
    // HOW CODE SOLVES: Unions stored entries with protectedDefaults so the three system-critical
    //                  names survive a UserDefaults clear or external edit. Called from
    //                  AppSettings.init so the merge happens once at load time.
    static func merging(_ user: [String]) -> [String] {
        Array(Set(user + protectedDefaults))
    }
}
