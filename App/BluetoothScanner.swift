import Foundation
import CoreBluetooth
import Combine

final class BluetoothScanner: NSObject, ObservableObject {
    @Published private(set) var devices: [NearbyDevice] = []
    @Published private(set) var state: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published var scanAllowDuplicates = true
    @Published var showUnnamedDevices = true
    @Published var autoPruneSeconds: Double = 45
    @Published var selectedFilter: DeviceFilter = .all
    @Published var selectedSort: DeviceSort = .strongest
    @Published var searchText = ""

    let history = HistoryStore()

    private var central: CBCentralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var deviceMap: [UUID: NearbyDevice] = [:]
    private var favorites = Set<UUID>()
    private var ignored = Set<UUID>()
    private var pendingAction: [UUID: PendingAction] = [:]
    private var dultCharacteristic: [UUID: CBCharacteristic] = [:]
    private var dultCommandQueue: [UUID: [UInt16]] = [:]
    private var pruneTimer: Timer?

    private enum PendingAction { case inspectGATT, inspectDULT, soundStart, soundStop }

    override init() {
        super.init()
        loadFlags()
        central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.pruneOldDevices() }
    }

    deinit { pruneTimer?.invalidate() }

    var bluetoothStatusText: String {
        switch state {
        case .poweredOn: "Bereit"
        case .poweredOff: "Bluetooth aus"
        case .unauthorized: "Nicht erlaubt"
        case .unsupported: "Nicht unterstützt"
        case .resetting: "Wird neu gestartet"
        default: "Wird geprüft"
        }
    }

    var filteredDevices: [NearbyDevice] {
        var values = devices.filter { !$0.isIgnored }
        if !showUnnamedDevices { values = values.filter { $0.name != "Unbenanntes BLE-Gerät" } }
        switch selectedFilter {
        case .all: break
        case .trackers: values = values.filter(\.isTrackerLike)
        case .connectable: values = values.filter(\.isConnectable)
        case .favorites: values = values.filter(\.isFavorite)
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            values = values.filter {
                $0.name.lowercased().contains(query) ||
                ($0.manufacturerName?.lowercased().contains(query) ?? false) ||
                ($0.dult?.networkName.lowercased().contains(query) ?? false) ||
                $0.id.uuidString.lowercased().contains(query)
            }
        }
        switch selectedSort {
        case .strongest: values.sort { $0.smoothedRSSI > $1.smoothedRSSI }
        case .newest: values.sort { $0.lastSeen > $1.lastSeen }
        case .name: values.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return values
    }

    func startScan() {
        guard state == .poweredOn else { return }
        let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: scanAllowDuplicates]
        central.scanForPeripherals(withServices: nil, options: options)
        isScanning = true
        Task { @MainActor in DebugLogger.shared.log("BLE-Scan gestartet (Duplicates: \(scanAllowDuplicates))") }
    }

    func stopScan() {
        central.stopScan(); isScanning = false
        Task { @MainActor in DebugLogger.shared.log("BLE-Scan gestoppt") }
    }

    func restartScan() { stopScan(); startScan() }

    func clearLiveDevices() {
        stopScan()
        deviceMap.removeAll(); devices.removeAll(); peripherals.removeAll()
        startScan()
    }

    func toggleFavorite(_ id: UUID) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        persistFlags(); mutate(id) { $0.isFavorite = favorites.contains(id) }
        Haptics.impact(.light)
    }

    func toggleIgnored(_ id: UUID) {
        if ignored.contains(id) { ignored.remove(id) } else { ignored.insert(id) }
        persistFlags(); mutate(id) { $0.isIgnored = ignored.contains(id) }
    }

    func inspectGATT(_ id: UUID) { connect(id, action: .inspectGATT) }
    func inspectDULT(_ id: UUID) { connect(id, action: .inspectDULT) }
    func playTrackerSound(_ id: UUID) { connect(id, action: .soundStart) }
    func stopTrackerSound(_ id: UUID) { connect(id, action: .soundStop) }

    func disconnect(_ id: UUID) {
        guard let peripheral = peripherals[id] else { return }
        central.cancelPeripheralConnection(peripheral)
    }

    private func connect(_ id: UUID, action: PendingAction) {
        guard let peripheral = peripherals[id] else { return }
        pendingAction[id] = action
        mutate(id) { device in
            device.connectionLabel = "Verbinde …"
            device.operationMessage = nil
        }
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        Task { @MainActor in DebugLogger.shared.log("Verbinde mit \(id.uuidString) für \(String(describing: action))") }
    }

    private func parseAdvertisement(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: Int) -> NearbyDevice {
        let id = peripheral.identifier
        let now = Date()
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let displayName = localName ?? peripheral.name ?? "Unbenanntes BLE-Gerät"
        let connectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let manufacturerID: UInt16? = manufacturerData?.littleEndianUInt16()
        let manufacturerName = manufacturerID.flatMap(BluetoothKnowledge.companyName)
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let serviceDataRaw = advertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data] ?? [:]
        let serviceData = Dictionary(uniqueKeysWithValues: serviceDataRaw.map { ($0.key.uuidString.uppercased(), $0.value.hexString) })

        var dult: DULTInfo?
        if let dultData = serviceDataRaw.first(where: { $0.key.uuidString.uppercased() == BluetoothKnowledge.dultServiceDataUUID })?.value,
           dultData.count >= 2 {
            let networkID = dultData[dultData.startIndex]
            let stateByte = dultData[dultData.index(after: dultData.startIndex)]
            dult = DULTInfo(
                networkID: networkID,
                networkName: BluetoothKnowledge.networkName(networkID),
                isNearOwner: (stateByte & 0x01) == 0x01
            )
        }

        let kind = classify(name: displayName, manufacturerData: manufacturerData, manufacturerID: manufacturerID, serviceUUIDs: serviceUUIDs, dult: dult)
        let old = deviceMap[id]
        let smoothed = old.map { ($0.smoothedRSSI * 0.72) + (Double(rssi) * 0.28) } ?? Double(rssi)

        var result = NearbyDevice(
            id: id,
            name: displayName,
            localName: localName,
            rssi: rssi,
            smoothedRSSI: smoothed,
            txPower: txPower,
            isConnectable: connectable,
            manufacturerID: manufacturerID,
            manufacturerName: manufacturerName,
            manufacturerDataHex: manufacturerData?.hexString,
            serviceUUIDs: serviceUUIDs,
            serviceData: serviceData,
            kind: kind,
            dult: dult,
            firstSeen: old?.firstSeen ?? now,
            lastSeen: now,
            sightings: (old?.sightings ?? 0) + 1,
            isFavorite: favorites.contains(id),
            isIgnored: ignored.contains(id),
            connectionLabel: old?.connectionLabel ?? "Nicht verbunden",
            operationMessage: old?.operationMessage,
            gattServices: old?.gattServices ?? []
        )

        if let oldDULT = old?.dult {
            result.dult?.manufacturerName = oldDULT.manufacturerName
            result.dult?.modelName = oldDULT.modelName
            result.dult?.firmwareVersion = oldDULT.firmwareVersion
            result.dult?.batteryLevel = oldDULT.batteryLevel
            result.dult?.capabilities = oldDULT.capabilities
        }
        return result
    }

    private func classify(name: String, manufacturerData: Data?, manufacturerID: UInt16?, serviceUUIDs: [String], dult: DULTInfo?) -> DeviceKind {
        if dult != nil { return .dultTracker }
        if let data = manufacturerData, data.count >= 4,
           data.littleEndianUInt16() == 0x004C,
           data[data.index(data.startIndex, offsetBy: 2)] == 0x12,
           data[data.index(data.startIndex, offsetBy: 3)] == 0x19 {
            return .appleFindMy
        }
        let lower = name.lowercased()
        if manufacturerID == 0x0075 || lower.contains("smarttag") || lower.contains("galaxy") { return .samsung }
        if serviceUUIDs.contains(where: { $0.uppercased() == "FE2C" }) { return .googleFastPair }
        if lower.contains("tv") || lower.contains("television") || lower.contains("display") { return .display }
        if lower.contains("buds") || lower.contains("airpods") || lower.contains("speaker") || lower.contains("headphone") { return .audio }
        return .generic
    }

    private func pruneOldDevices() {
        guard autoPruneSeconds > 0 else { return }
        let now = Date()
        let expired = deviceMap.values.filter { now.timeIntervalSince($0.lastSeen) > autoPruneSeconds && !$0.isFavorite }.map(\.id)
        for id in expired { deviceMap.removeValue(forKey: id); peripherals.removeValue(forKey: id) }
        if !expired.isEmpty { publish() }
    }

    private func publish() { devices = Array(deviceMap.values) }

    private func mutate(_ id: UUID, _ body: (inout NearbyDevice) -> Void) {
        guard var device = deviceMap[id] else { return }
        body(&device); deviceMap[id] = device; publish()
    }

    private func loadFlags() {
        if let favoriteStrings = UserDefaults.standard.array(forKey: "RJBT.favorites") as? [String] {
            favorites = Set(favoriteStrings.compactMap(UUID.init(uuidString:)))
        }
        if let ignoredStrings = UserDefaults.standard.array(forKey: "RJBT.ignored") as? [String] {
            ignored = Set(ignoredStrings.compactMap(UUID.init(uuidString:)))
        }
    }

    private func persistFlags() {
        UserDefaults.standard.set(favorites.map(\.uuidString), forKey: "RJBT.favorites")
        UserDefaults.standard.set(ignored.map(\.uuidString), forKey: "RJBT.ignored")
    }

    private func prepareDULT(_ peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let id = peripheral.identifier
        dultCharacteristic[id] = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
        switch pendingAction[id] {
        case .soundStart:
            sendDULTCommand(0x0300, to: peripheral, characteristic: characteristic)
        case .soundStop:
            sendDULTCommand(0x0301, to: peripheral, characteristic: characteristic)
        case .inspectDULT:
            dultCommandQueue[id] = [0x0004, 0x0005, 0x0008, 0x0009, 0x000A, 0x000C]
            sendNextDULTCommand(peripheral)
        default: break
        }
    }

    private func sendNextDULTCommand(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard var queue = dultCommandQueue[id], !queue.isEmpty, let characteristic = dultCharacteristic[id] else {
            if pendingAction[id] == .inspectDULT {
                mutate(id) { $0.operationMessage = "Tracker-Informationen gelesen" }
                pendingAction[id] = nil
            }
            return
        }
        let opcode = queue.removeFirst(); dultCommandQueue[id] = queue
        sendDULTCommand(opcode, to: peripheral, characteristic: characteristic)
    }

    private func sendDULTCommand(_ opcode: UInt16, to peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        let data = Data.littleEndian(opcode)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        Task { @MainActor in DebugLogger.shared.log(String(format: "DULT command 0x%04X an %@", opcode, peripheral.identifier.uuidString)) }
    }

    private func parseDULTResponse(_ data: Data, peripheral: CBPeripheral) {
        guard let opcode = data.littleEndianUInt16() else { return }
        let id = peripheral.identifier
        switch opcode {
        case 0x0804:
            let text = String(data: Data(data.dropFirst(2)), encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            mutate(id) { $0.dult?.manufacturerName = text }
            sendNextDULTCommand(peripheral)
        case 0x0805:
            let text = String(data: Data(data.dropFirst(2)), encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
            mutate(id) { $0.dult?.modelName = text }
            sendNextDULTCommand(peripheral)
        case 0x0808:
            let capabilities = data.littleEndianUInt32(at: 2)
            mutate(id) { $0.dult?.capabilities = capabilities }
            sendNextDULTCommand(peripheral)
        case 0x0809:
            if data.count >= 3 {
                let network = data[data.index(data.startIndex, offsetBy: 2)]
                mutate(id) { device in
                    device.dult?.networkID = network
                    device.dult?.networkName = BluetoothKnowledge.networkName(network)
                }
            }
            sendNextDULTCommand(peripheral)
        case 0x080A:
            if let fw = data.littleEndianUInt32(at: 2) {
                let major = (fw >> 16) & 0xFFFF, minor = (fw >> 8) & 0xFF, revision = fw & 0xFF
                mutate(id) { $0.dult?.firmwareVersion = "\(major).\(minor).\(revision)" }
            }
            sendNextDULTCommand(peripheral)
        case 0x080C:
            if data.count >= 3 {
                let level = data[data.index(data.startIndex, offsetBy: 2)]
                let label = [0: "Voll", 1: "Mittel", 2: "Niedrig", 3: "Kritisch"][Int(level)] ?? "Unbekannt"
                mutate(id) { $0.dult?.batteryLevel = label }
            }
            sendNextDULTCommand(peripheral)
        case 0x0302:
            let command = data.littleEndianUInt16(at: 2)
            let status = data.littleEndianUInt16(at: 4)
            let ok = status == 0
            mutate(id) { device in
                if command == 0x0300 { device.operationMessage = ok ? "Ton wird abgespielt" : "Ton konnte nicht gestartet werden (Status \(status ?? 0))" }
                if command == 0x0301 { device.operationMessage = ok ? "Ton gestoppt" : "Ton konnte nicht gestoppt werden" }
            }
            if ok { Haptics.success() } else { Haptics.warning() }
        case 0x0303:
            mutate(id) { $0.operationMessage = "Ton abgeschlossen" }
        default:
            Task { @MainActor in DebugLogger.shared.log(String(format: "Unbekannte DULT-Antwort 0x%04X: %@", opcode, data.hexString)) }
            if pendingAction[id] == .inspectDULT { sendNextDULTCommand(peripheral) }
        }
    }

    private func propertiesString(_ properties: CBCharacteristicProperties) -> String {
        var values: [String] = []
        if properties.contains(.read) { values.append("Read") }
        if properties.contains(.write) { values.append("Write") }
        if properties.contains(.writeWithoutResponse) { values.append("Write NR") }
        if properties.contains(.notify) { values.append("Notify") }
        if properties.contains(.indicate) { values.append("Indicate") }
        if properties.contains(.broadcast) { values.append("Broadcast") }
        return values.joined(separator: ", ")
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        Task { @MainActor in DebugLogger.shared.log("Bluetooth state: \(central.state.rawValue)") }
        if central.state == .poweredOn { startScan() } else { isScanning = false }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        guard rssi != 127 else { return }
        peripherals[peripheral.identifier] = peripheral
        let parsed = parseAdvertisement(peripheral: peripheral, advertisementData: advertisementData, rssi: rssi)
        deviceMap[peripheral.identifier] = parsed
        publish()
        if parsed.isTrackerLike { history.record(parsed) }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        mutate(peripheral.identifier) { $0.connectionLabel = "Verbunden" }
        peripheral.delegate = self
        switch pendingAction[peripheral.identifier] {
        case .inspectGATT:
            peripheral.discoverServices(nil)
        case .inspectDULT, .soundStart, .soundStop:
            peripheral.discoverServices([CBUUID(string: BluetoothKnowledge.dultNonOwnerServiceUUID)])
        case .none:
            peripheral.discoverServices(nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        mutate(peripheral.identifier) {
            $0.connectionLabel = "Verbindung fehlgeschlagen"
            $0.operationMessage = error?.localizedDescription ?? "Keine Verbindung möglich"
        }
        pendingAction[peripheral.identifier] = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        mutate(peripheral.identifier) { $0.connectionLabel = "Nicht verbunden" }
        dultCharacteristic[peripheral.identifier] = nil
        dultCommandQueue[peripheral.identifier] = nil
    }
}

extension BluetoothScanner: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            mutate(peripheral.identifier) { $0.operationMessage = error?.localizedDescription }
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
            mutate(peripheral.identifier) { device in
                if !device.gattServices.contains(where: { $0.uuid == service.uuid.uuidString }) {
                    device.gattServices.append(GATTServiceSnapshot(uuid: service.uuid.uuidString, isPrimary: service.isPrimary))
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        let characteristics = service.characteristics ?? []
        mutate(peripheral.identifier) { device in
            if let index = device.gattServices.firstIndex(where: { $0.uuid == service.uuid.uuidString }) {
                device.gattServices[index].characteristics = characteristics.map {
                    GATTCharacteristicSnapshot(uuid: $0.uuid.uuidString, properties: propertiesString($0.properties), valueHex: $0.value?.hexString)
                }
            }
        }
        for characteristic in characteristics {
            if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
            if service.uuid == CBUUID(string: BluetoothKnowledge.dultNonOwnerServiceUUID),
               characteristic.uuid == CBUUID(string: BluetoothKnowledge.dultNonOwnerCharacteristicUUID) {
                prepareDULT(peripheral, characteristic: characteristic)
            }
        }
        if pendingAction[peripheral.identifier] == .inspectGATT {
            mutate(peripheral.identifier) { $0.operationMessage = "GATT-Dienste geladen" }
            pendingAction[peripheral.identifier] = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else { return }
        if characteristic.uuid == CBUUID(string: BluetoothKnowledge.dultNonOwnerCharacteristicUUID) {
            parseDULTResponse(value, peripheral: peripheral)
        }
        mutate(peripheral.identifier) { device in
            for serviceIndex in device.gattServices.indices {
                if let charIndex = device.gattServices[serviceIndex].characteristics.firstIndex(where: { $0.uuid == characteristic.uuid.uuidString }) {
                    device.gattServices[serviceIndex].characteristics[charIndex].valueHex = value.hexString
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            mutate(peripheral.identifier) { $0.operationMessage = "Schreiben fehlgeschlagen: \(error.localizedDescription)" }
        }
    }
}
