import Foundation

struct DULTInfo: Equatable, Codable {
    var networkID: UInt8
    var networkName: String
    var isNearOwner: Bool
    var manufacturerName: String?
    var modelName: String?
    var firmwareVersion: String?
    var batteryLevel: String?
    var capabilities: UInt32?

    var isSeparated: Bool { !isNearOwner }
    var supportsPlaySound: Bool { capabilities.map { ($0 & 0x1) != 0 } ?? true }
}

enum DeviceKind: String, Codable, CaseIterable {
    case dultTracker
    case appleFindMy
    case samsung
    case googleFastPair
    case audio
    case display
    case generic

    var title: String {
        switch self {
        case .dultTracker: "Ortungs-Tracker"
        case .appleFindMy: "Apple Find My-Signal"
        case .samsung: "Samsung BLE"
        case .googleFastPair: "Google/Fast Pair"
        case .audio: "Audio"
        case .display: "TV/Display"
        case .generic: "Bluetooth LE"
        }
    }

    var symbol: String {
        switch self {
        case .dultTracker: "mappin.and.ellipse"
        case .appleFindMy: "dot.radiowaves.left.and.right"
        case .samsung: "tag"
        case .googleFastPair: "link"
        case .audio: "headphones"
        case .display: "tv"
        case .generic: "wave.3.right"
        }
    }
}

enum RiskLevel: Int, Codable, Comparable {
    case normal = 0
    case attention = 1
    case elevated = 2

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .normal: "Info"
        case .attention: "Beobachten"
        case .elevated: "Auffällig"
        }
    }
}

struct GATTCharacteristicSnapshot: Identifiable, Equatable {
    let id = UUID()
    var uuid: String
    var properties: String
    var valueHex: String?
}

struct GATTServiceSnapshot: Identifiable, Equatable {
    var id: String { uuid }
    var uuid: String
    var isPrimary: Bool
    var characteristics: [GATTCharacteristicSnapshot] = []
}

struct NearbyDevice: Identifiable, Equatable {
    var id: UUID
    var name: String
    var localName: String?
    var rssi: Int
    var smoothedRSSI: Double
    var txPower: Int?
    var isConnectable: Bool
    var manufacturerID: UInt16?
    var manufacturerName: String?
    var manufacturerDataHex: String?
    var serviceUUIDs: [String]
    var serviceData: [String: String]
    var kind: DeviceKind
    var dult: DULTInfo?
    var firstSeen: Date
    var lastSeen: Date
    var sightings: Int
    var isFavorite: Bool
    var isIgnored: Bool
    var connectionLabel: String = "Nicht verbunden"
    var operationMessage: String?
    var gattServices: [GATTServiceSnapshot] = []

    var age: TimeInterval { Date().timeIntervalSince(lastSeen) }
    var seenDuration: TimeInterval { lastSeen.timeIntervalSince(firstSeen) }

    var proximityLabel: String {
        if smoothedRSSI >= -55 { return "Sehr nah" }
        if smoothedRSSI >= -67 { return "Nah" }
        if smoothedRSSI >= -78 { return "Mittel" }
        if smoothedRSSI >= -90 { return "Weiter weg" }
        return "Sehr schwach"
    }

    var estimatedDistance: Double? {
        guard let txPower else { return nil }
        let n = 2.2
        return pow(10.0, (Double(txPower) - smoothedRSSI) / (10.0 * n))
    }

    var isTrackerLike: Bool {
        kind == .dultTracker || kind == .appleFindMy
    }

    var riskLevel: RiskLevel {
        if let dult, dult.isSeparated {
            if sightings >= 12 && seenDuration >= 8 * 60 { return .elevated }
            return .attention
        }
        if kind == .appleFindMy && sightings >= 15 && seenDuration >= 10 * 60 { return .attention }
        return .normal
    }
}

struct SightingRecord: Codable, Identifiable {
    var id = UUID()
    var deviceID: UUID
    var name: String
    var kind: DeviceKind
    var network: String?
    var rssi: Int
    var timestamp: Date
    var risk: RiskLevel
}

enum DeviceFilter: String, CaseIterable, Identifiable {
    case all, trackers, connectable, favorites
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: "Alle"
        case .trackers: "Tracker"
        case .connectable: "Verbindbar"
        case .favorites: "Favoriten"
        }
    }
}

enum DeviceSort: String, CaseIterable, Identifiable {
    case strongest, newest, name
    var id: String { rawValue }
    var title: String {
        switch self {
        case .strongest: "Signalstärke"
        case .newest: "Zuletzt gesehen"
        case .name: "Name"
        }
    }
}
