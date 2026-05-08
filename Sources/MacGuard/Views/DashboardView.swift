import SwiftUI

// TASK: Google Material colour palette as Color extensions shared across all MacGuard views.
// HOW CODE SOLVES: Centralises the six brand colours so every view uses the same hex values.
//                  Defined here (the main view file) rather than in a separate Utilities file
//                  because no additional abstraction is needed for six static constants.
extension Color {
    static let googleBlue    = Color(red: 0.259, green: 0.522, blue: 0.957)  // #4285F4
    static let googleGreen   = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853
    static let googleYellow  = Color(red: 0.984, green: 0.737, blue: 0.020)  // #FBBC05
    static let googleRed     = Color(red: 0.918, green: 0.263, blue: 0.208)  // #EA4335
    static let googleSurface = Color(red: 0.973, green: 0.976, blue: 0.980)  // #F8F9FA
    static let googleText    = Color(red: 0.126, green: 0.133, blue: 0.157)  // #202124
    static let googleSubtext = Color(red: 0.373, green: 0.392, blue: 0.408)  // #5F6368
}

// TASK: Root view of the NSPopover — Google Blue header + Monitor / Settings tab layout.
// HOW CODE SOLVES: ContentView owns the header so it stays consistent regardless of which tab is
//                  active. Both child views receive ProcessMonitor and AppSettings via
//                  @EnvironmentObject, injected once at the NSHostingController call site in
//                  AppDelegate rather than prop-drilled through every level.
struct ContentView: View {
    @EnvironmentObject var monitor: ProcessMonitor
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            TabView {
                DashboardView()
                    .tabItem { Label("Monitor", systemImage: "cpu") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape") }
                HistoryView()
                    .tabItem { Label("History", systemImage: "clock") }
            }
        }
        .frame(width: 380, height: 480)
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "cpu")
                .foregroundColor(.white)
            Text("MacGuard")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            statusChip
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.googleBlue)
    }

    private var statusChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(levelColor)
                .frame(width: 8, height: 8)
            Text(levelLabel)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
    }

    private var levelColor: Color {
        switch monitor.cpuLevel {
        case .normal:   return .googleGreen
        case .warning:  return .googleYellow
        case .critical: return .googleRed
        }
    }

    private var levelLabel: String {
        switch monitor.cpuLevel {
        case .normal:   return "Normal"
        case .warning:  return "Warning"
        case .critical: return "Critical"
        }
    }
}

// TASK: Monitor tab — live scrollable list of the top 20 processes sorted by CPU%.
// HOW CODE SOLVES: Sorts and slices on every @Published update from ProcessMonitor so the
//                  list always reflects the current poll without additional state. Uses
//                  MonitoredProcess (not ProcessInfo) per BUG-S01. LazyVStack avoids
//                  allocating all rows at once when the list is long.
struct DashboardView: View {
    @EnvironmentObject var monitor: ProcessMonitor
    @EnvironmentObject var settings: AppSettings

    private var topProcesses: [MonitoredProcess] {
        Array(monitor.processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(20))
    }

    var body: some View {
        VStack(spacing: 0) {
            CountdownBannerView()
            Group {
                if topProcesses.isEmpty {
                    VStack {
                        Spacer()
                        ProgressView("Scanning processes…")
                            .foregroundColor(.googleSubtext)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(topProcesses) { process in
                                ProcessRow(
                                    process: process,
                                    threshold: settings.cpuThreshold,
                                    history: monitor.cpuHistory(for: process.pid)
                                )
                            }
                        }
                        .padding(12)
                    }
                }
            }
        }
        .background(Color.googleSurface)
    }
}

// TASK: Single row in the process monitor list showing status dot, name, PID, memory and CPU%.
// HOW CODE SOLVES: Dot colour and CPU% text colour follow the four-colour Google palette:
//                  green below 70% of threshold, yellow from 70% up to threshold, red at or
//                  above threshold — consistent with the menu-bar icon tinting scheme.
struct ProcessRow: View {
    let process: MonitoredProcess
    let threshold: Double
    let history: [Double]

    private var dotColor: Color {
        if process.cpuPercent >= threshold        { return .googleRed    }
        if process.cpuPercent >= threshold * 0.7  { return .googleYellow }
        return .googleGreen
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.callout)
                    .foregroundColor(.googleText)
                    .lineLimit(1)
                Text("PID \(process.pid)  ·  \(String(format: "%.0f", process.memoryMB)) MB")
                    .font(.caption)
                    .foregroundColor(.googleSubtext)
            }
            Spacer()
            if history.count >= 2 {
                SparklineView(values: history, threshold: threshold)
                    .frame(width: 52, height: 20)
            }
            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(.callout, design: .monospaced).weight(.medium))
                .foregroundColor(dotColor)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// TASK: 60-second rolling CPU sparkline drawn as a stroked Path.
// HOW CODE SOLVES: GeometryReader maps each sample to a pixel coordinate — x is evenly
//                  spaced across the width, y is normalised against max(threshold, peak)
//                  so the line fills the available height and a spike at exactly the
//                  threshold touches the top edge. Drawn in googleBlue at 50% opacity
//                  so it's readable without competing with the CPU% number.
struct SparklineView: View {
    let values: [Double]
    let threshold: Double

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(threshold, values.max() ?? threshold)
            let w = geo.size.width
            let h = geo.size.height
            let step = w / CGFloat(values.count - 1)

            Path { path in
                for (i, val) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = h - CGFloat(val / maxVal) * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else       { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color.googleBlue.opacity(0.55), lineWidth: 1.5)
        }
    }
}
