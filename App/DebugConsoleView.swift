import SwiftUI

struct DebugConsoleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var logger = DebugLogger.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(logger.exportText.isEmpty ? "Noch keine Debug-Einträge." : logger.exportText)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Leeren", role: .destructive) { logger.clear() } }
            }
        }
    }
}
