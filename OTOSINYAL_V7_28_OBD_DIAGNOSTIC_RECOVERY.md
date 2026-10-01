# OtoSinyal V7.28 - OBD Diagnostic Recovery

- AndrOBD-style compact CAN response compatibility added for header-on ELM replies such as `7E8064100...`.
- Compact 29-bit ISO-TP CAN responses are normalized before UDS/OBD parsing.
- OBD-Droid-style bounded retry added for transient `STOPPED`, `?`, empty, `BUFFER FULL`, `RX ERROR`, and `DATA ERROR` diagnostic replies.
- Retry path applied to ECU probing, supported PID discovery, readiness, freeze frame, Mode 06, VIN Mode 09, MIL status, and DTC reads.
- ECU responder discovery and Mode 09 ECU info parsing now accept both spaced and compact CAN headers.
- VIN-success UI separates the OBD Lottie animation and vehicle-brand logo into independent layout areas to prevent overlap.
- Added parser regression tests for compact 11-bit/29-bit CAN replies and multi-frame UDS VIN decoding.
