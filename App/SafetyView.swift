import SwiftUI

struct SafetyView: View {
    @EnvironmentObject private var scanner: BluetoothScanner

    private var trackers: [NearbyDevice] {
        scanner.devices.filter { $0.isTrackerLike && !$0.isIgnored }.sorted { $0.riskLevel > $1.riskLevel || ($0.riskLevel == $1.riskLevel && $0.smoothedRSSI > $1.smoothedRSSI) }
    }

    var body: some View {
        ZStack {
            UltraBackground()
            ScrollView {
                VStack(spacing: 14) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "shield.checkered").font(.system(size: 42)).foregroundStyle(.green)
                                VStack(alignment: .leading) {
                                    Text("Anti-Tracking-Check").font(.title2.bold())
                                    Text(scanner.isScanning ? "Live-Suche läuft" : "Scanner pausiert").foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            HStack {
                                MetricPill(icon: "mappin.and.ellipse", title: "Tracker-Signale", value: "\(trackers.count)")
                                MetricPill(icon: "exclamationmark.triangle", title: "Auffällig", value: "\(trackers.filter { $0.riskLevel == .elevated }.count)")
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Wichtig für echte Verfolgungswarnungen", systemImage: "iphone.gen3.radiowaves.left.and.right").font(.headline)
                            Text("Die systemweite iPhone-Funktion für unerwünschte Tracker bleibt die verlässlichste Warnung, weil iOS längere Bewegungsmuster und bekannte eigene Geräte berücksichtigen kann. RJ Bluetooth Ultra ergänzt das mit einer manuellen lokalen Funkanalyse und dem offenen DULT-Protokoll.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    if trackers.isEmpty {
                        ContentUnavailableView("Keine Tracker-Signale erkannt", systemImage: "shield.checkered", description: Text("Das bedeutet nicht automatisch, dass kein Tracker existiert – er kann gerade nicht senden oder außerhalb der BLE-Reichweite sein."))
                            .padding(.top, 40)
                    } else {
                        ForEach(trackers) { device in
                            NavigationLink(value: device.id) {
                                SafetyTrackerCard(device: device)
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(16)
            }
        }
        .navigationTitle("Schutz")
        .navigationDestination(for: UUID.self) { DeviceDetailView(deviceID: $0) }
    }
}

struct SafetyTrackerCard: View {
    let device: NearbyDevice

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: device.kind.symbol).font(.title2).foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text(device.name).font(.headline)
                        Text(device.dult?.networkName ?? "Apple Find My-kompatibles Signal").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(text: device.riskLevel.title, icon: device.riskLevel == .normal ? "info.circle" : "exclamationmark.triangle.fill", tint: device.riskLevel == .normal ? .blue : .orange)
                }
                if let dult = device.dult {
                    Text(dult.isSeparated ? "Der Tracker meldet den standardisierten Status „vom Besitzer getrennt“." : "Der Tracker meldet „Besitzer in der Nähe“." )
                        .font(.subheadline)
                }
                HStack {
                    Text(device.proximityLabel)
                    Text("• \(Int(device.smoothedRSSI.rounded())) dBm")
                    Text("• \(device.sightings) Sichtungen")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
