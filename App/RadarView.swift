import SwiftUI

struct RadarView: View {
    @EnvironmentObject private var scanner: BluetoothScanner
    @State private var trackerOnly = false

    private var visible: [NearbyDevice] {
        Array((trackerOnly ? scanner.devices.filter(\.isTrackerLike) : scanner.devices)
            .filter { !$0.isIgnored }
            .sorted { $0.smoothedRSSI > $1.smoothedRSSI }
            .prefix(18))
    }

    var body: some View {
        ZStack {
            UltraBackground()
            ScrollView {
                VStack(spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Nähe-Radar").font(.title2.bold())
                                    Text("Relative Darstellung nach RSSI").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("Nur Tracker", isOn: $trackerOnly).labelsHidden()
                            }
                        }
                    }
                    RadarCanvas(devices: visible)
                        .frame(height: 390)
                        .glassEffect(.regular, in: .rect(cornerRadius: 30))
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("So liest du das Radar", systemImage: "info.circle").font(.headline)
                            Text("Punkte weiter innen haben aktuell ein stärkeres Funksignal. Der Winkel ist bewusst nur eine stabile visuelle Verteilung – normale BLE-Werbung liefert auf dem iPhone keine echte Richtung. Für echte Richtung braucht ein unterstütztes Zubehör UWB oder iOS-27-Channel-Sounding mit kompatibler, gekoppelter Hardware.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(visible.prefix(8)) { device in
                        NavigationLink(value: device.id) { DeviceRow(device: device) }.buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Radar")
        .navigationDestination(for: UUID.self) { DeviceDetailView(deviceID: $0) }
    }
}

struct RadarCanvas: View {
    let devices: [NearbyDevice]

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.42
                for ring in 1...4 {
                    let r = radius * CGFloat(ring) / 4
                    let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.22)), lineWidth: 1)
                }
                context.stroke(Path { p in p.move(to: CGPoint(x: center.x - radius, y: center.y)); p.addLine(to: CGPoint(x: center.x + radius, y: center.y)) }, with: .color(.secondary.opacity(0.14)))
                context.stroke(Path { p in p.move(to: CGPoint(x: center.x, y: center.y - radius)); p.addLine(to: CGPoint(x: center.x, y: center.y + radius)) }, with: .color(.secondary.opacity(0.14)))

                for device in devices {
                    let normalized = min(max((-device.smoothedRSSI - 38) / 62, 0.08), 1.0)
                    let r = radius * normalized
                    let seed = abs(device.id.uuidString.hashValue % 360)
                    let angle = Double(seed) * .pi / 180
                    let point = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
                    let dotRect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
                    context.fill(Path(ellipseIn: dotRect), with: .color(device.isTrackerLike ? Color.orange : Color.cyan))
                }
                let meRect = CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28)
                context.fill(Path(ellipseIn: meRect), with: .color(.primary))
            }
            .overlay(alignment: .bottomLeading) {
                Text("\(devices.count) Signale")
                    .font(.caption.weight(.semibold))
                    .padding(10)
            }
        }
        .padding(12)
    }
}
