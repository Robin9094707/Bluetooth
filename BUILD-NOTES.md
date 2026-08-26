# Build Notes

- XcodeGen project source: `project.yml`
- Scheme: `RJBluetoothUltra`
- Bundle ID: `eu.rjuhas.bluetoothultra`
- Deployment target: iOS 26.0
- CI runner: `xcode-27` (GitHub public preview as of August 2026)
- Signing disabled in CI
- Output: `RJ-Bluetooth-Ultra-unsigned.ipa`
- Failure artifact: `RJ-Bluetooth-Ultra-build-log`

The app intentionally avoids private frameworks and private Find My APIs.
