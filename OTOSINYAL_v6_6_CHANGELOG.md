# OTOSİNYAL v6.6 – ECU Discovery & Flight Recorder

- Diagnostic Flight Recorder: TX/RX, timeout, latency, raw ELM/UDS data, responder discovery and identity results.
- JSON + TXT log export/share from Aracımı Analiz Et.
- Engine ECU UDS identity requests are explicitly routed through 7E0/7E8 instead of depending on stale/default ELM headers.
- Added standard identity reads: VIN, part number, software, hardware, serial, ASAM/ODX dataset, ASAM version and ECU system name.
- Full scan automatically starts and closes a detailed diagnostic session.
- Turbo Tracking no longer reports "measurement condition suitable" when target boost is unavailable; it explicitly reports that ECU target pressure is missing.
- Existing generic OBD fallback/live data remains intact.

Important: OEM-specific live measurement DIDs are only used when verified. This build does not invent target boost values for unsupported ECUs.
