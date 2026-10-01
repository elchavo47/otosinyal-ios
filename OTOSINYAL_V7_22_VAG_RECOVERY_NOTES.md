# OTOSİNYAL V7.22 — VAG Recovery Bridge

This release starts the actual migration of the recovered legacy VAG application into the current OTOSİNYAL engine.

## Integrated now

- Recovered `VAG.db` converted deterministically into `assets/data/vag_recovered/vag_dtc_catalog_v1.json`.
  - 9,137 records recovered from the supplied file.
  - DTC screen now prefers this recovered description when a matching code exists, then falls back to the existing dictionary.
- Recovered `vagplatforms.db` converted to normalized JSON.
  - 8 platform records.
- MQB light-function table recovered.
  - 81 values.
- MQB light-type table recovered.
  - 48 values.
- Recovery manifest stores hashes for the source ZIP, `CarScannerMaui.dll`, and opaque adaptation DBs.
- Coding screen shows the recovered-catalog bridge/status.
- A reproducible offline recovery script was added under `tools/vag_recovery/`.

## Coding model hardening for the recovered catalog

`VagCodingRecipe` now supports:

- ECU part-number allowlists
- software-version allowlists
- ASAM dataset/version allowlists
- explicit read/write UDS services
- diagnostic session
- security-access metadata/provider id
- source resource/revision/provenance
- recovered flag

Before any write, OTOSİNYAL now additionally requires an exact recipe identity allowlist match. A recipe without an allowlist cannot be written even if somebody accidentally marks it write-enabled.

## Still under recovery

The following resources are preserved and fingerprinted, but not guessed:

- `mqbadaptations.db`
- `pq26adaptations.db`
- `pq26newrapid2020.db`
- `pq35adaptations.db`
- `a4b9adaptations.db`
- `vagmeb.db`
- `mqb_camera_fusion.db`
- `mqb_swap_custom_coding.db`
- `vagmodelcodes_crypto.db`
- `micro.vag`
- `strings.vag`

The recovered managed DLL contains the expected reader anchors (`LoadVAG_MQB`, `OpenFileCryptoStream2`, `ShiftStream2`, compressed crypto deserialization, MQB adaptation template classes). These databases stay write-disabled until that reader chain is reconstructed deterministically and converted offline.

## Safety rule

No guessed DID, byte, bit, seed/key or adaptation address is introduced by this release. Existing backup -> write -> read-back verify -> rollback behavior remains in force.
