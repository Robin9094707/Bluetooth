import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var scanner: BluetoothScanner
    let completion: () -> Void

    var body: some View {
        ZStack {
            UltraBackground()
            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 40)
                    ZStack {
                        Circle().fill(.cyan.opacity(0.16)).frame(width: 132, height: 132)
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.system(size: 74, weight: .light))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.cyan)
                    }
                    VStack(spacing: 10) {
                        Text("RJ Bluetooth Ultra")
                            .font(.largeTitle.bold())
                        Text("Live-BLE-Scanner, Geräteanalyse und Anti-Stalking-Werkzeuge – direkt auf deinem iPhone.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        feature("antenna.radiowaves.left.and.right", "Live-Scanner", "Sieh BLE-Werbung, Signalstärke, Hersteller, Services und Rohdaten.")
                        feature("mappin.and.ellipse", "Tracker-Schutz", "Erkennt standardisierte DULT-Signale von Apple-, Google-, Samsung- und kompatiblen Netzwerken.")
                        feature("speaker.wave.3", "Ton finden", "Bei getrennten, standardkonformen Trackern kann der offizielle Nicht-Besitzer-Tonbefehl gesendet werden.")
                        feature("lock.shield", "Privat", "Kein Konto, kein Server und keine Standortfreigabe. Die Analyse läuft lokal.")
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Wichtig", systemImage: "info.circle.fill").font(.headline)
                            Text("iOS gibt Drittanbieter-Apps keinen Vollzugriff auf Classic-Bluetooth oder das private Find-My/SmartThings/Find-Hub-Netzwerk. Die App zeigt echte BLE-Daten und kennzeichnet Schätzwerte ausdrücklich.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        scanner.startScan()
                        completion()
                    } label: {
                        Label("Bluetooth-Scan starten", systemImage: "wave.3.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                .padding(22)
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).frame(width: 34).foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}
