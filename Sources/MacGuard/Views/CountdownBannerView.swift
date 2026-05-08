import SwiftUI

// TASK: Observable store for active spike alerts awaiting auto-kill.
// HOW CODE SOLVES: AppDelegate calls add/remove as spikes are armed and resolved.
//                  CountdownBannerView observes this object and re-renders on every change.
//                  Keeping state here (rather than on AppDelegate) avoids making AppDelegate
//                  an ObservableObject and lets the banner work without an environment injection.
final class SpikeAlertState: ObservableObject {
    static let shared = SpikeAlertState()
    @Published var alerts: [SpikeAlert] = []
    var onCancel: ((pid_t) -> Void)?
    private init() {}

    func add(pid: pid_t, name: String, delay: TimeInterval) {
        alerts.removeAll { $0.pid == pid }
        alerts.append(SpikeAlert(pid: pid, name: name,
                                  deadline: Date().addingTimeInterval(delay)))
    }

    func remove(pid: pid_t) {
        alerts.removeAll { $0.pid == pid }
    }
}

// TASK: Value representing one active spike pending auto-kill.
// HOW CODE SOLVES: Stores the absolute deadline so countdown can be computed at any moment
//                  as (deadline − now) without needing a running counter.
struct SpikeAlert: Identifiable {
    let pid: pid_t
    let name: String
    let deadline: Date
    var id: pid_t { pid }
}

// TASK: Show one banner row per active spike with a live countdown and a Cancel button.
// HOW CODE SOLVES: Uses a 1-second Timer publisher to tick `now` so remaining seconds
//                  recompute every second via pure subtraction. When alerts is empty the
//                  view renders nothing, so it adds no layout space in the Monitor tab.
//                  The Cancel button calls SpikeAlertState.onCancel (wired to
//                  AppDelegate.cancelKill) and removes the alert immediately from the UI
//                  before the delegate callback confirms — optimistic update feels faster.
struct CountdownBannerView: View {
    @ObservedObject private var state = SpikeAlertState.shared
    @State private var now = Date()

    var body: some View {
        if !state.alerts.isEmpty {
            VStack(spacing: 6) {
                ForEach(state.alerts) { alert in
                    BannerRow(alert: alert, now: now) {
                        state.onCancel?(alert.pid)
                        state.remove(pid: alert.pid)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) {
                now = $0
            }
        }
    }
}

// TASK: Single-spike countdown row — progress bar, label, and Cancel button.
// HOW CODE SOLVES: Progress runs from 1.0 (just armed) down to 0.0 (kill imminent),
//                  matching the visual expectation that the bar drains as time runs out.
//                  Bar and accent colour use googleRed to make the urgency visually clear.
private struct BannerRow: View {
    let alert: SpikeAlert
    let now: Date
    let onCancel: () -> Void

    private var remaining: TimeInterval { max(0, alert.deadline.timeIntervalSince(now)) }
    private var total: TimeInterval { AppSettings.shared.killDelay }
    private var progress: Double { max(0, min(1, remaining / total)) }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.googleRed)
                    .font(.caption)
                Text("\(alert.name) — killing in \(Int(remaining))s")
                    .font(.caption)
                    .foregroundColor(.googleText)
                    .lineLimit(1)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.googleBlue)
                    .buttonStyle(.plain)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.googleRed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.googleRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
