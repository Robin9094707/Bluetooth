import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var scanner: BluetoothScanner
    @StateObject private var logger = DebugLogger.shared
    @State private var showDebug = false

    var body: some View {
        ZStack {
            UltraBackground()
            Form {
                Section("Scan") {
                    Toggle("Doppelte Werbepakete auswerten", isOn: $scanner.scanAllowDuplicates)
                        .onChange(of: scanner.scanAllowDuplicates) { _, _ in scanner.restartScan() }
                    Toggle("Unbenannte Geräte anzeigen", isOn: $scanner.showUnnamedDevices)
                    Picker("Live-Geräte ausblenden nach", selection: $scanner.autoPruneSeconds) {
                        Text("30 Sekunden").tag(30.0)
                        Text("45 Sekunden").tag(45.0)
                        Text("90 Sekunden").tag(90.0)
                        Text("Nie").tag(0.0)
                    }
                    Button("Live-Liste leeren") { scanner.clearLiveDevices() }
                }
                Section("Technik") {
                    LabeledContent("Bluetooth", value: scanner.bluetoothStatusText)
                    LabeledContent("BLE-Scan", value: "CoreBluetooth")
                    LabeledContent("DULT", value: "v03-kompatible Erkennung")
                    LabeledContent("iOS 27", value: "Channel Sounding: nur gekoppelte kompatible Hardware")
                }
                Section("Grenzen von iOS") {
                    Text("Classic-Bluetooth-Geräte erscheinen nur, wenn sie zusätzlich BLE senden. AirTag-/Find-My-, Samsung- und Google-Cloudkonten sind nicht öffentlich auslesbar. Die App liest keine fremden Standorte aus Netzwerken aus.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Diagnose") {
                    Button("Debug-Konsole öffnen") { showDebug = true }
                    ShareLink(item: logger.exportText.isEmpty ? "Keine Debug-Einträge" : logger.exportText) {
                        Label("Debug-Log teilen", systemImage: "square.and.arrow.up")
                    }
                }
                Section("Über") {
                    LabeledContent("App", value: "RJ Bluetooth Ultra")
                    LabeledContent("Version", value: "1.0")
                    Text("Native SwiftUI-App ohne Drittanbieter-SDKs. Geräte- und Trackeranalyse läuft lokal auf dem iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Mehr")
        .sheet(isPresented: $showDebug) { DebugConsoleView() }
    }
}
