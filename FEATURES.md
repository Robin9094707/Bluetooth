# Feature Matrix

## Scanner
- live BLE scan
- name/local name/CoreBluetooth UUID
- RSSI + smoothed RSSI
- TX Power
- connectability
- manufacturer data/company ID
- service UUIDs/service data
- filters, sorting, search, favorites, ignored devices

## Tracker Safety
- DULT 0xFCB2 recognition
- network provider decode: Apple 0x01, Google 0x02, Samsung 0x03, Amazon 0x04
- near-owner/separated bit decode
- DULT GATT inspection for manufacturer/model/capabilities/network/firmware/battery
- non-owner sound start/stop protocol support
- Apple Offline Finding advertisement heuristic
- local sighting history and conservative attention scoring

## Device Details
- signal/proximity
- estimated distance only with advertised TX Power
- GATT service + characteristic explorer
- readable characteristic values
- raw hex payloads

## UX
- SwiftUI
- Liquid Glass
- Dark Mode
- Dynamic Type
- VoiceOver-friendly labels
- haptics
- onboarding
- empty/error/permission states
- debug console
