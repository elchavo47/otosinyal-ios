# iOS Build 10 — Cockpit and live diagnostics layout

- Home speed and RPM telemetry cards rebuilt with a restrained automotive instrument face, animated needle, major/minor ticks, scale labels and centered values. Home card height increased to 224 logical pixels.
- Live diagnostics starts with three direct shortcuts: full unit scan, graph/record, vehicle analysis. Live metrics appear before the long advanced tool catalogs. VIN/OEM/maintenance and the full smart tool catalog remain available through collapsed sections.
- Version set to 1.0.0+10. Existing OBD provider and diagnostic routines unchanged.

## Verification required

Flutter and Xcode are unavailable in this environment. Run `flutter analyze`, `flutter build ios --no-codesign`, and test small-screen iPhone layouts and real OBD sessions before TestFlight. This package does not claim to fix unrelated PDF export or sharing failures.
