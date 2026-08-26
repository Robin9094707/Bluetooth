# RJ Bluetooth Ultra

Native iOS Bluetooth diagnostics and tracker-safety app for iOS 26+.

## Highlights

- Live CoreBluetooth BLE scan with duplicate advertisement processing
- RSSI smoothing, proximity classes and optional TX-Power distance estimate
- Manufacturer/company recognition and raw advertising data
- Service UUID and Service Data inspection
- GATT explorer for user-selected connectable peripherals
- Cross-platform unwanted-tracker recognition using DULT service data UUID `0xFCB2`
- DULT network IDs: Apple, Google, Samsung and Amazon
- DULT separated/near-owner state
- Standards-based non-owner Play Sound command for compatible separated trackers
- Legacy Apple Find My advertisement heuristic (Apple company ID + Offline Finding payload)
- Tracker sighting history stored locally without GPS
- Radar visualization (relative RSSI, not fake direction)
- Liquid Glass SwiftUI interface
- Debug console and export

## Important platform limits

CoreBluetooth scans Bluetooth Low Energy advertisers. iOS does not expose arbitrary Classic Bluetooth discovery, private Find My / SmartThings / Find Hub account databases, or unrestricted AirTag precision finding APIs to third-party apps.

The Play Sound function is only attempted for devices advertising the cross-platform DULT payload and reporting separated mode. The implementation uses the public draft protocol's non-owner service/characteristic and Sound_Start opcode.

## Build

GitHub Actions builds an unsigned IPA on the `xcode-27` public-preview runner. The workflow is also triggered on pushes to `main` so the first upload automatically starts a build.
