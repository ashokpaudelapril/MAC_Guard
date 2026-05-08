import Foundation
import Darwin

// TASK: Kill a process by PID with a defense-in-depth whitelist guard.
// HOW CODE SOLVES: Checks hard-coded system-critical names AND AppSettings.shared.whitelist
//                  before calling Darwin.kill, so even if UserDefaults is cleared the three
//                  protected processes (kernel_task, WindowServer, launchd) can never be killed.
//                  Returns true if SIGKILL was dispatched successfully, false if blocked.
final class ProcessKiller {
    @discardableResult
    static func kill(pid: pid_t, name: String) -> Bool {
        // ISSUE: Duplicated hard-coded protected list was out of sync with AppSettings and UI.
        // FIX APPLIED: Delegate to Whitelist.isProtected (BUG-S10) so protection logic has
        //              one source of truth; log skipped kills so the history file is complete.
        guard !Whitelist.isProtected(name),
              !AppSettings.shared.whitelist.contains(name) else {
            Logger.shared.log("SKIPPED: \(name) [PID \(pid)] is whitelisted")
            return false
        }
        let ok = Darwin.kill(pid, SIGKILL) == 0
        if !ok { Logger.shared.log("KILL-FAILED: \(name) [PID \(pid)] errno=\(errno)") }
        return ok
    }
}
