# OtoSinyal V7.31 – Performance Trigger Fix

- Performance timing source is now stable: OBD is preferred when alive; GPS is used as fallback instead of switching frame-by-frame.
- 0-100 launch detection tolerates stationary GPS jitter up to roughly 6 km/h.
- 60-100 / 80-120 / 100-200 rolling tests use a wider arming window and upward-motion threshold so skipped sensor samples do not prevent the timer from starting.
- If OBD speed is stuck at zero while GPS clearly shows motion, timing automatically falls back to GPS.
- Existing automatic finish and history autosave remain unchanged.
