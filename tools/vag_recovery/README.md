# VAG legacy recovery tool — V7.23

The legacy database reader has now been reconstructed for the recovered adaptation DB family.

## Recovered decoder

The supplied `mqbadaptations.db` family is not random ciphertext. The legacy DLL reader chain uses a byte-position transform (`ShiftStream2`) and the result is a BSON array. The recovery tool now reproduces that transformation offline and emits neutral JSON assets.

Recovered catalog families in this build:

- MQB: 346
- PQ26: 80
- PQ26 New Rapid 2020: 62
- PQ35: 15
- MLB-A4B9: 194
- MEB: 44
- MQB Camera Fusion: 4
- MQB SWaP Custom Coding: 1
- Total normalized records: 746

Fields such as UID, DID/address (`AD`), request/response CAN IDs (`RQH`/`RSH`), start byte (`SBI`), data length (`DL`), multiplier/offset, password/security metadata, options and `BIT:x:y=z` value expressions are preserved exactly in JSON.

## Runtime policy

Standard 2-byte DID records can be read through UDS `0x22`. For recovered selectable records that do not request Security Access/custom procedures and are not in safety-critical ECU groups, OTOSİNYAL can perform read-modify-write using `0x2E`, with live ECU identity capture, backup, read-back verification and rollback.

Engine, transmission, ABS/ESC, airbag, steering, ACC/front-camera groups are intentionally write-locked in the recovered generic writer. Records with `PWD/PWH`, `PreWrite/PostWrite`, free numeric values, or non-standard write methods remain visible/readable but locked until their dedicated legacy procedure is reconstructed and verified.

## Rebuild assets

```bash
python tools/vag_recovery/recover_vag_assets.py \
  /path/to/recovered_folder \
  assets/data/vag_recovered \
  --source-zip /path/to/APK_VAG_KURTARMA.zip
```

Never modify the original recovery ZIP/DB bytes in place. Keep the SHA-256 inventory.
