# OTOSİNYAL V7.23 — VAG engine recovery

- Reconstructed the legacy ShiftStream2 transform from the recovered managed reader.
- Confirmed the transformed adaptation databases are BSON arrays.
- Normalized 746 recovered adaptation/coding records across MQB, PQ26, PQ26 New Rapid 2020, PQ35, MLB-A4B9, MEB, MQB Camera Fusion and MQB SWaP Custom Coding.
- Added a Flutter recovered-adaptation catalog browser with platform/search filters and live UDS read.
- Added recovered option parser for direct hex and `BIT:byte:bit=value` expressions, including multi-bit expressions.
- Added guarded read-modify-write for standard DID records using 0x22/0x2E.
- Every generic recovered write captures VIN + live ECU part/software identity, stores the original full DID payload, writes, reads back, verifies, and uses the existing rollback transaction path.
- Security Access/password records and custom PreWrite/PostWrite procedures remain locked until their old dedicated flow is verified.
- Safety-critical request groups (engine, transmission, ABS/ESC, airbag, steering, ACC/front-camera) are blocked from the recovered generic writer.
- Original recovered DB hashes remain preserved; no original DB is modified.
