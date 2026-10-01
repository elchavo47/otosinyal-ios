# OtoSinyal V7.39 — OBD-Droid Live Core

- Multi-ECU supported PID bitmaps are merged.
- PID discovery follows 00/20/40/60/80/A0/C0/E0 continuation blocks.
- Every discovered Mode 01 PID is actively probed.
- Common SAE PIDs are decoded into readable values.
- Unknown-but-responsive PIDs remain visible as RAW HEX.
- Existing fast RPM/speed lane remains.
- Existing VAG DID discovery remains positive-response-only.
- Clone ELM fallback probes remain.
