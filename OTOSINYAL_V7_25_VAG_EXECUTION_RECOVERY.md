# OTOSINYAL V7.25 — VAG execution/security recovery

- Recovered legacy VAG UDS Security Access flow: `27 03` seed -> big-endian 32-bit seed + decimal access code -> `27 04` key, wrapping to 32 bits.
- Added recovered PreWrite/PostWrite command executor.
- Procedure executor supports raw UDS commands, temporary `HEADER:COMMAND` syntax, DID snapshots (`22xxxx`) and replay writes (`2Exxxx` with no inline payload).
- Catalog records with a concrete recovered PWD can now perform security access instead of being blanket-locked.
- Records containing only password hints remain locked: hints are never guessed automatically to avoid ECU lockout timers.
- Existing VIN, adapter-quality, ECU identity read, backup, write, read-back verify and rollback chain remains enabled.
- SFD/online authorization is not bypassed; ECUs requiring it will return their normal negative response.
