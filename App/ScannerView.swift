import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var scanner: BluetoothScanner

    var body: some View {
        ZStack {
            UltraBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    hero
                    controls
                    if scanner.filteredDevices.isEmpty {
                        ContentUnavailableView(
                            scanner.isScanning ? "Suche nach Bluetooth-Geräten …" : "Scan pausiert",
                            systemImage: scanner.isScanning ? "wave.3.right" : "pause.circle",
                            description: Text("BLE-Geräte erscheinen, sobald sie Werbepakete senden.")
                        )
                        .padding(.top, 50)
                    } else {
                        ForEach(scanner.filteredDevices) { device in
                            NavigationLink(value: device.id) {
                                DeviceRow(device: device)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { scanner.restartScan() }
        }
        .navigationTitle("Bluetooth Ultra")
        .navigationDestination(for: UUID.self) { id in DeviceDetailView(deviceID: id) }
        .searchable(text: $scanner.searchText, prompt: "Gerät, Hersteller oder UUID")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { scanner.isScanning ? scanner.stopScan() : scanner.startScan() } label: {
                    Image(systemName: scanner.isScanning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var hero: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(scanner.isScanning ? "Live-Umgebung" : "Scanner pausiert")
                            .font(.title2.bold())
                        Text(scanner.bluetoothStatusText)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: scanner.isScanning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 34))
                        .symbolEffect(.variableColor.iterative, isActive: scanner.isScanning)
                        .foregroundStyle(.cyan)
                }
                HStack {
                    MetricPill(icon: "dot.radiowaves.left.and.right", title: "Sichtbar", value: "\(scanner.devices.count)")
                    MetricPill(icon: "mappin.and.ellipse", title: "Tracker", value: "\(scanner.devices.filter(\.isTrackerLike).count)")
                    MetricPill(icon: "link", title: "Verbindbar", value: "\(scanner.devices.filter(\.isConnectable).count)")
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Filter", selection: $scanner.selectedFilter) {
                ForEach(DeviceFilter.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("\(scanner.filteredDevices.count) Ergebnisse").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Picker("Sortieren", selection: $scanner.selectedSort) {
                        ForEach(DeviceSort.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    Label(scanner.selectedSort.title, systemImage: "arrow.up.arrow.down")
                }
                .buttonStyle(.glass)
            }
        }
    }
}

struct DeviceRow: View {
    let device: NearbyDevice

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(device.isTrackerLike ? Color.orange.opacity(0.15) : Color.cyan.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: device.kind.symbol)
                    .font(.title2)
                    .foregroundStyle(device.isTrackerLike ? .orange : .cyan)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(device.name).font(.headline).lineLimit(1)
                    if device.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow) }
                }
                Text(device.dult?.networkName ?? device.manufacturerName ?? device.kind.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 7) {
                    Text(device.proximityLabel)
                    Text("•")
                    Text("\(Int(device.smoothedRSSI.rounded())) dBm")
                    if device.isConnectable { Text("• verbindbar") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                SignalBars(rssi: device.smoothedRSSI)
                if device.riskLevel != .normal {
                    StatusBadge(text: device.riskLevel.title, icon: "exclamationmark.triangle.fill", tint: .orange)
                }
            }
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

struct SignalBars: View {
    let rssi: Double
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < strength ? Color.primary : Color.secondary.opacity(0.2))
                    .frame(width: 4, height: CGFloat(6 + index * 4))
            }
        }
        .accessibilityLabel("Signal \(strength) von 4")
    }
    private var strength: Int {
        if rssi >= -55 { return 4 }
        if rssi >= -67 { return 3 }
        if rssi >= -80 { return 2 }
        return 1
    }
}
