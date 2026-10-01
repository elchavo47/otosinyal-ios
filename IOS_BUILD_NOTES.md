# OtoSinyal iOS icon and build preparation

- Original V7.39 source retained; app icon replaced with the user-approved red OBD2/OtoSinyal artwork across all existing iOS AppIcon sizes.
- App Store marketing icon is 1024 x 1024 opaque RGB PNG.
- pubspec version changed from 7.34.0+40 to 1.0.0+4 to match the previously discussed App Store Connect 1.0.0 (3) build. IMPORTANT: confirm the existing App Store version/build before uploading; change if necessary.
- Existing Info.plist permission descriptions retained.
- No Flutter/Xcode/macOS toolchain is available here. No IPA build, CocoaPods resolution, simulator or real-device test was performed.
- iOS Bluetooth Classic SPP and USB OTG cannot be assumed supported; test BLE/Wi-Fi adapters on physical iPhone.
- Do not claim App Store approval or real-vehicle functionality without tests.
