import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var scanner: BluetoothScanner
    @State private var showClear = false

    var body: some View {
        ZStack {
            UltraBackground()
            List {
                Section {
                    Text("Der Verlauf speichert nur lokale Funksichtungen der App. Er enthält keine GPS-Position und wird nicht hochgeladen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if scanner.history.records.isEmpty {
                    Section { ContentUnavailableView("Noch kein Tracker-Verlauf", systemImage: "clock", description: Text("Tracker-Sichtungen werden während des Scans lokal protokolliert.")) }
                } else {
                    Section("Letzte Sichtungen") {
                        ForEach(scanner.history.records.prefix(200)) { record in
                            HStack {
                                Image(systemName: record.kind.symbol)
                                    .foregroundStyle(record.risk == .normal ? Color.secondary : Color.orange)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.name).font(.headline)
                                    Text([record.network, "\(record.rssi) dBm"].compactMap { $0 }.joined(separator: " • "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(record.timestamp, style: .relative).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Verlauf")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { showClear = true } label: { Image(systemName: "trash") }.buttonStyle(.glass)
            }
        }
        .confirmationDialog("Verlauf löschen?", isPresented: $showClear, titleVisibility: .visible) {
            Button("Verlauf löschen", role: .destructive) { scanner.history.clear() }
        }
    }
}
