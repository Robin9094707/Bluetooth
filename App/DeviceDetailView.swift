import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var scanner: BluetoothScanner
    let deviceID: UUID
    @State private var showRaw = false

    private var device: NearbyDevice? { scanner.devices.first(where: { $0.id == deviceID }) }

    var body: some View {
        ZStack {
            UltraBackground()
            if let device {
                ScrollView {
                    VStack(spacing: 14) {
                        header(device)
                        signalCard(device)
                        if device.isTrackerLike { trackerCard(device) }
                        identityCard(device)
                        gattCard(device)
                        rawCard(device)
                    }
                    .padding(16)
                }
            } else {
                ContentUnavailableView("Gerät nicht mehr sichtbar", systemImage: "wave.3.right.slash", description: Text("Starte den Scan neu oder gehe näher an das Gerät."))
            }
        }
        .navigationTitle(device?.name ?? "Gerät")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let device {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { scanner.toggleFavorite(device.id) } label: { Image(systemName: device.isFavorite ? "star.fill" : "star") }
                        .buttonStyle(.glass)
                }
            }
        }
    }

    private func header(_ device: NearbyDevice) -> some View {
        GlassCard {
            HStack(spacing: 15) {
                Image(systemName: device.kind.symbol)
                    .font(.system(size: 38))
                    .foregroundStyle(device.isTrackerLike ? .orange : .cyan)
                    .frame(width: 58, height: 58)
                    .background((device.isTrackerLike ? Color.orange : Color.cyan).opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 5) {
                    Text(device.name).font(.title2.bold())
                    Text(device.kind.title).foregroundStyle(.secondary)
                    HStack {
                        StatusBadge(text: device.connectionLabel, icon: device.connectionLabel == "Verbunden" ? "link" : "link.badge.plus", tint: .cyan)
                        if device.isConnectable { StatusBadge(text: "Verbindbar", icon: "checkmark.circle", tint: .green) }
                    }
                }
                Spacer()
            }
        }
    }

    private func signalCard(_ device: NearbyDevice) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Nähe & Signal", systemImage: "scope").font(.headline)
                HStack(alignment: .lastTextBaseline) {
                    Text(device.proximityLabel).font(.title.bold())
                    Spacer()
                    Text("\(Int(device.smoothedRSSI.rounded())) dBm").font(.title3.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressView(value: min(max((device.smoothedRSSI + 100) / 55, 0), 1))
                HStack {
                    infoCell("RSSI", "\(device.rssi) dBm")
                    infoCell("TX Power", device.txPower.map { "\($0) dBm" } ?? "–")
                    infoCell("Distanz", device.estimatedDistance.map { String(format: "≈ %.1f m", $0) } ?? "RSSI-Schätzung")
                }
                Text("RSSI ist keine echte Entfernung: Wände, Körperhaltung und Antennen verändern den Wert stark. Eine Meterangabe erscheint nur, wenn das Gerät TX-Power mitsendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func trackerCard(_ device: NearbyDevice) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Tracker-Sicherheitsanalyse", systemImage: "shield.lefthalf.filled").font(.headline)
                    Spacer()
                    StatusBadge(text: device.riskLevel.title, icon: device.riskLevel == .normal ? "info.circle" : "exclamationmark.triangle.fill", tint: device.riskLevel == .normal ? .blue : .orange)
                }
                if let dult = device.dult {
                    LabeledContent("Netzwerk", value: dult.networkName)
                    LabeledContent("Status", value: dult.isSeparated ? "Vom Besitzer getrennt" : "Besitzer vermutlich in der Nähe")
                    LabeledContent("Beobachtet", value: "\(device.sightings)× seit \(device.firstSeen.formatted(date: .omitted, time: .shortened))")
                    if let m = dult.manufacturerName { LabeledContent("Hersteller", value: m) }
                    if let m = dult.modelName { LabeledContent("Modell", value: m) }
                    if let b = dult.batteryLevel { LabeledContent("Batterie", value: b) }

                    HStack {
                        Button { scanner.inspectDULT(device.id) } label: { Label("Tracker-Infos", systemImage: "doc.text.magnifyingglass") }
                            .buttonStyle(.glass)
                        Button { scanner.playTrackerSound(device.id) } label: { Label("Ton abspielen", systemImage: "speaker.wave.3.fill") }
                            .buttonStyle(.glassProminent)
                            .disabled(!dult.isSeparated || !device.isConnectable)
                    }
                    if !dult.isSeparated {
                        Text("Der standardisierte Nicht-Besitzer-Ton ist nur im getrennten Zustand freigegeben.").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Dieses Paket sieht wie ein Apple-Find-My-Offlinesignal aus. Bei älteren/proprietären Find-My-Signalen stellt iOS Drittanbieter-Apps jedoch keinen öffentlichen Ton- oder Präzisionssuche-Befehl bereit.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let message = device.operationMessage {
                    Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func identityCard(_ device: NearbyDevice) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Identität & Werbung", systemImage: "info.square").font(.headline)
                LabeledContent("CoreBluetooth-ID", value: device.id.uuidString)
                LabeledContent("Hersteller", value: device.manufacturerName ?? "Nicht erkannt")
                if let id = device.manufacturerID { LabeledContent("Company ID", value: String(format: "0x%04X", id)) }
                LabeledContent("Connectable", value: device.isConnectable ? "Ja" : "Nein")
                LabeledContent("Erstes Signal", value: device.firstSeen.formatted(date: .omitted, time: .standard))
                LabeledContent("Letztes Signal", value: device.lastSeen.formatted(date: .omitted, time: .standard))
                LabeledContent("Pakete", value: "\(device.sightings)")
            }
            .font(.subheadline)
        }
    }

    private func gattCard(_ device: NearbyDevice) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("GATT Explorer", systemImage: "point.3.connected.trianglepath.dotted").font(.headline)
                    Spacer()
                    if device.connectionLabel == "Verbunden" {
                        Button("Trennen") { scanner.disconnect(device.id) }.buttonStyle(.glass)
                    } else {
                        Button("Verbinden & prüfen") { scanner.inspectGATT(device.id) }.buttonStyle(.glass)
                            .disabled(!device.isConnectable)
                    }
                }
                if device.gattServices.isEmpty {
                    Text(device.isConnectable ? "Nach dem Verbinden werden Services, Characteristics, Rechte und lesbare Werte angezeigt." : "Dieses Gerät bewirbt sich aktuell nicht als verbindbar.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(device.gattServices) { service in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(service.characteristics) { characteristic in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(characteristic.uuid).font(.caption.monospaced())
                                        Text(characteristic.properties).font(.caption2).foregroundStyle(.secondary)
                                        if let value = characteristic.valueHex { Text(value).font(.caption2.monospaced()).textSelection(.enabled) }
                                    }
                                    Divider()
                                }
                            }.padding(.top, 8)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(BluetoothKnowledge.shortServiceName(service.uuid) ?? service.uuid)
                                if BluetoothKnowledge.shortServiceName(service.uuid) != nil { Text(service.uuid).font(.caption2.monospaced()).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func rawCard(_ device: NearbyDevice) -> some View {
        GlassCard {
            DisclosureGroup("Rohdaten", isExpanded: $showRaw) {
                VStack(alignment: .leading, spacing: 10) {
                    if let data = device.manufacturerDataHex {
                        Text("Manufacturer Data").font(.caption.bold())
                        Text(data).font(.caption.monospaced()).textSelection(.enabled)
                    }
                    if !device.serviceUUIDs.isEmpty {
                        Text("Service UUIDs").font(.caption.bold())
                        Text(device.serviceUUIDs.joined(separator: "\n")).font(.caption.monospaced()).textSelection(.enabled)
                    }
                    ForEach(device.serviceData.keys.sorted(), id: \.self) { key in
                        Text("Service Data \(key)").font(.caption.bold())
                        Text(device.serviceData[key] ?? "").font(.caption.monospaced()).textSelection(.enabled)
                    }
                }.padding(.top, 10)
            }
        }
    }

    private func infoCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
