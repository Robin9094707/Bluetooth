import Foundation
import Combine

final class HistoryStore: ObservableObject {
    @Published private(set) var records: [SightingRecord] = []
    private let key = "RJBT.sightingHistory.v1"
    private var lastSavedByDevice: [UUID: Date] = [:]

    init() { load() }

    func record(_ device: NearbyDevice) {
        let now = Date()
        if let last = lastSavedByDevice[device.id], now.timeIntervalSince(last) < 30 { return }
        lastSavedByDevice[device.id] = now
        records.insert(SightingRecord(
            deviceID: device.id,
            name: device.name,
            kind: device.kind,
            network: device.dult?.networkName,
            rssi: device.rssi,
            timestamp: now,
            risk: device.riskLevel
        ), at: 0)
        if records.count > 1000 { records.removeLast(records.count - 1000) }
        save()
    }

    func clear() { records = []; save() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SightingRecord].self, from: data) else { return }
        records = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
