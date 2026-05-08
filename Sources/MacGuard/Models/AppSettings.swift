import Foundation

// TASK: UserDefaults-backed settings singleton shared across ProcessMonitor and the Settings UI.
// HOW CODE SOLVES: Single instance via private init + static let shared. @Published properties
//                  auto-persist to UserDefaults on every change via didSet. Defaults are loaded
//                  with an explicit key-presence check so a legitimately stored value of 0.0 is
//                  preserved rather than silently replaced by the fallback — the spec's nonZeroOr
//                  extension would discard any setting the user intentionally set to zero on the
//                  next relaunch (BUG-S08 fix). Whitelist always contains the three protected
//                  defaults even if UserDefaults stored a list that somehow omitted them.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var cpuThreshold: Double {
        didSet { UserDefaults.standard.set(cpuThreshold, forKey: "cpuThreshold") }
    }
    @Published var killDelay: TimeInterval {
        didSet { UserDefaults.standard.set(killDelay, forKey: "killDelay") }
    }
    @Published var whitelist: [String] {
        didSet { UserDefaults.standard.set(whitelist, forKey: "whitelist") }
    }

    private init() {
        cpuThreshold = AppSettings.loadDouble("cpuThreshold", default: 80.0)
        killDelay    = AppSettings.loadDouble("killDelay",    default: 60.0)

        // ISSUE: Duplicated whitelist constants across AppSettings, ProcessKiller, SettingsView.
        // FIX APPLIED: Use Whitelist.merging so the single source of truth in Whitelist.swift
        //              governs both the persisted defaults and the runtime guard (BUG-S10).
        let stored = (UserDefaults.standard.array(forKey: "whitelist") as? [String]) ?? []
        whitelist  = Whitelist.merging(stored)
    }

    // TASK: Load a Double from UserDefaults, falling back to a default only when the key
    //       is genuinely absent (never written), not when it contains a stored 0.0.
    // HOW CODE SOLVES: .object(forKey:) returns nil when the key has never been set, whereas
    //                  .double(forKey:) returns 0.0 for both "absent" and "stored as 0".
    //                  Checking .object first lets us distinguish the two cases (BUG-S08).
    private static func loadDouble(_ key: String, default fallback: Double) -> Double {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return UserDefaults.standard.double(forKey: key)
    }
}
