import SwiftUI
import AppKit
import UniformTypeIdentifiers

// TASK: History tab — displays kill event log entries from history.log, newest first.
// HOW CODE SOLVES: Reads Logger.shared.entries() on appear (one-shot synchronous file
//                  read, safe on the main thread for a ≤5 MB file). A Refresh button
//                  re-reads the file so the user can see events that fired since the
//                  popover was last opened without reopening it.
struct HistoryView: View {
    @State private var entries: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background(Color.googleSurface)
        .onAppear { reload() }
    }

    private var toolbar: some View {
        HStack {
            Text("\(entries.count) events")
                .font(.caption)
                .foregroundColor(.googleSubtext)
            Spacer()
            // TASK: Export visible log entries to a CSV file the user chooses via NSSavePanel.
            // HOW CODE SOLVES: Logger.exportCSV() formats the data; NSSavePanel handles the
            //                  path selection safely without any user-supplied path in code.
            Button {
                exportCSV()
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(.googleBlue)
            }
            .buttonStyle(.plain)
            .disabled(entries.isEmpty)

            Button {
                reload()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundColor(.googleBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            VStack(spacing: 6) {
                Spacer()
                Image(systemName: "clock")
                    .font(.largeTitle)
                    .foregroundColor(.googleSubtext.opacity(0.5))
                Text("No history yet")
                    .foregroundColor(.googleSubtext)
                    .font(.callout)
                Text("Kill events will appear here")
                    .foregroundColor(.googleSubtext)
                    .font(.caption)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(entries.indices, id: \.self) { i in
                        Text(entries[i])
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.googleText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(i % 2 == 0 ? Color.white : Color.googleSurface)
                    }
                }
            }
        }
    }

    private func reload() {
        entries = Logger.shared.entries()
    }

    private func exportCSV() {
        guard let csv = Logger.shared.exportCSV() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "macguard-history.csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
