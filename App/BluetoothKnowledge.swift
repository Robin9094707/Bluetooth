import Foundation

struct BluetoothKnowledge {
    static let dultServiceDataUUID = "FCB2"
    static let dultNonOwnerServiceUUID = "15190001-12F4-C226-88ED-2AC5579F2A85"
    static let dultNonOwnerCharacteristicUUID = "8E0C0001-1D68-FB92-BF61-48377421680E"

    static func networkName(_ id: UInt8) -> String {
        switch id {
        case 0x01: "Apple Find My"
        case 0x02: "Google Find Hub"
        case 0x03: "Samsung Find"
        case 0x04: "Amazon"
        default: String(format: "Netzwerk 0x%02X", id)
        }
    }

    static func companyName(_ id: UInt16) -> String? {
        switch id {
        case 0x004C: "Apple"
        case 0x0075: "Samsung Electronics"
        case 0x00E0: "Google"
        case 0x0006: "Microsoft"
        case 0x0059: "Nordic Semiconductor"
        case 0x0131: "Google"
        default: nil
        }
    }

    static func shortServiceName(_ uuid: String) -> String? {
        switch uuid.uppercased() {
        case "1800": "Generic Access"
        case "1801": "Generic Attribute"
        case "180A": "Device Information"
        case "180F": "Battery"
        case "1812": "Human Interface Device"
        case "FE2C": "Google Fast Pair"
        case "FCB2": "Unwanted Tracking"
        case dultNonOwnerServiceUUID: "DULT Non-Owner"
        default: nil
        }
    }
}

extension Data {
    var hexString: String { map { String(format: "%02X", $0) }.joined(separator: " ") }

    func littleEndianUInt16(at offset: Int = 0) -> UInt16? {
        guard count >= offset + 2 else { return nil }
        return UInt16(self[index(startIndex, offsetBy: offset)]) |
            (UInt16(self[index(startIndex, offsetBy: offset + 1)]) << 8)
    }

    func littleEndianUInt32(at offset: Int = 0) -> UInt32? {
        guard count >= offset + 4 else { return nil }
        return UInt32(self[index(startIndex, offsetBy: offset)]) |
            (UInt32(self[index(startIndex, offsetBy: offset + 1)]) << 8) |
            (UInt32(self[index(startIndex, offsetBy: offset + 2)]) << 16) |
            (UInt32(self[index(startIndex, offsetBy: offset + 3)]) << 24)
    }

    static func littleEndian(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)])
    }
}
