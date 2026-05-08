import SwiftUI
import ServiceManagement

// TASK: Settings tab — CPU threshold slider, kill-delay slider, and whitelist editor.
// HOW CODE SOLVES: Sliders bind directly to AppSettings @Published properties so every change
//                  auto-persists to UserDefaults via didSet. The Remove button is explicitly
//                  disabled for the three protected defaults (kernel_task, WindowServer, launchd)
//                  so the UI enforces the same invariant as AppSettings.whitelistDefaults and
//                  the runtime guard in ProcessKiller — users cannot remove system-critical names
//                  from the whitelist through the UI (BUG-S05 / SECURITY.md requirement).
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var newEntry = ""
    // TASK: Persist the Launch at Login toggle state across view reloads.
    // HOW CODE SOLVES: Initialised from SMAppService.mainApp.status so the toggle reflects
    //                  the real registration state rather than a local boolean that could
    //                  drift from the system. Wrapped in #available — already guaranteed by
    //                  the macOS 13 deployment target, but explicit for clarity.
    @State private var launchAtLogin: Bool = {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                thresholdSection
                killDelaySection
                whitelistSection
                launchAtLoginSection
            }
            .padding(14)
        }
        .background(Color.googleSurface)
    }

    // MARK: — CPU Threshold

    // ISSUE: Spec hardcodes the alert threshold check to 80 without reading AppSettings.
    // FIX APPLIED: Slider binds to settings.cpuThreshold so the user's configured value is
    //              always what ProcessMonitor compares against (BUG-S05 counterpart for UI).
    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("CPU Threshold", icon: "exclamationmark.triangle")
            HStack {
                Slider(value: $settings.cpuThreshold, in: 5...100, step: 5)
                    .accentColor(.googleBlue)
                Text("\(Int(settings.cpuThreshold))%")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.googleText)
                    .frame(width: 44, alignment: .trailing)
            }
            Text("Alert when a process exceeds this for 30 s")
                .font(.caption)
                .foregroundColor(.googleSubtext)
        }
        .settingsCard()
    }

    // MARK: — Kill Delay

    // ISSUE: Spec hardcodes the auto-kill grace period to 60 s in AppDelegate.
    // FIX APPLIED: Slider binds to settings.killDelay so AppDelegate reads the stored value
    //              via AppSettings.shared.killDelay when scheduling DispatchWorkItem (BUG-S05).
    private var killDelaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Auto-Kill Delay", icon: "timer")
            HStack {
                Slider(value: $settings.killDelay, in: 30...300, step: 30)
                    .accentColor(.googleBlue)
                Text("\(Int(settings.killDelay))s")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.googleText)
                    .frame(width: 44, alignment: .trailing)
            }
            Text("Seconds before auto-killing after the alert fires")
                .font(.caption)
                .foregroundColor(.googleSubtext)
        }
        .settingsCard()
    }

    // MARK: — Whitelist

    private var whitelistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Whitelist", icon: "shield.checkmark")
            ForEach(settings.whitelist.sorted(), id: \.self) { entry in
                whitelistRow(entry)
            }
            Divider()
            addEntryRow
        }
        .settingsCard()
    }

    private func whitelistRow(_ entry: String) -> some View {
        let isProtected = Whitelist.isProtected(entry)
        return HStack(spacing: 8) {
            Image(systemName: isProtected ? "lock.fill" : "checkmark.shield")
                .foregroundColor(isProtected ? .googleSubtext : .googleBlue)
                .frame(width: 16)
            Text(entry)
                .font(.callout)
                .foregroundColor(isProtected ? .googleSubtext : .googleText)
            Spacer()
            if !isProtected {
                Button {
                    settings.whitelist.removeAll { $0 == entry }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundColor(.googleRed)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addEntryRow: some View {
        HStack {
            TextField("Add process name…", text: $newEntry)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
            Button {
                let trimmed = newEntry.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !settings.whitelist.contains(trimmed) else { return }
                settings.whitelist.append(trimmed)
                newEntry = ""
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.googleBlue)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(newEntry.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: — Launch at Login

    // TASK: Toggle macOS login-item registration via SMAppService (macOS 13 API).
    // HOW CODE SOLVES: SMAppService.mainApp.register/unregister manage the system-level
    //                  entry. If the call throws (e.g. app is unsigned during development)
    //                  the toggle reverts so the UI never shows a state that doesn't match
    //                  reality. A caption explains the signed-bundle requirement when running
    //                  as a bare SPM executable without a bundle identifier.
    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Startup", icon: "power")
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .tint(.googleBlue)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }
            if Bundle.main.bundleIdentifier == nil {
                Text("Requires a signed .app bundle (Week 6)")
                    .font(.caption)
                    .foregroundColor(.googleSubtext)
            }
        }
        .settingsCard()
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enable { try SMAppService.mainApp.register()   }
            else      { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = !enable   // revert toggle to match actual state
        }
    }

    // MARK: — Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.googleText)
    }
}

// TASK: Card-style container for each settings section.
// HOW CODE SOLVES: ViewModifier keeps the white card + subtle shadow styling DRY across the
//                  three settings sections without repeating the same modifier chain each time.
private struct SettingsCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

extension View {
    func settingsCard() -> some View {
        modifier(SettingsCardModifier())
    }
}
