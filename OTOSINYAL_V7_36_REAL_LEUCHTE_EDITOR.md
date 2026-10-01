# OTOSINYAL V7.36 — REAL MQB LEUCHTE EDITOR

- Replaced the previous generic light-adaptation launcher with a real MQB Leuchte channel editor.
- Recovered MQB channel DIDs 0550..0572 (Leuchte 0..34) from the legacy assembly strings.
- Recovered light payload field order:
  LampType, FunctionA, FunctionB, DimmwertAB, LightControlAB, FunctionC, FunctionD,
  DimmwertCD, DimmingDirectionCD, FunctionE, FunctionF, DimmwertEF, FunctionG,
  FunctionH, DimmwertGH, DimmingDirectionGH, DimmingDirectionEF.
- Uses the recovered 81-function `mqb_light_functions` catalog and 48-entry `mqb_light_types` catalog.
- Reads live values from 09 BCM using UDS ReadDataByIdentifier (0x22).
- Writes the selected Leuchte DID using UDS WriteDataByIdentifier (0x2E).
- Uses recovered BCM addressing 70E/778 and recovered Security Access code 31347.
- Existing CodingTransactionService provides backup, read-back verification and rollback on mismatch/failure.
- UI exposes Lasttyp, Lichtfunktion A-H, Dimmwert AB/CD/EF/GH and advanced raw LightControl/DimmingDirection bytes.
- Channel examples include rear indicators, brake lights and reverse lights with recovered labels/hints.
