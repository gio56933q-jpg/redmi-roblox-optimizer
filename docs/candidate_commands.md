# Candidate commands (UID 2000-safe) for probe only

Status labels:
- **Confirmed**: already proven in device logs.
- **Candidate**: safe to probe for availability/readback.
- **Rejected/Blocked**: do not add to engage profile.

## Confirmed baseline (already in v9.2)
- `cmd game set --downscale 0.25 --fps 120 com.roblox.client`
- `cmd game mode custom com.roblox.client`
- `setprop debug.inputdispatcher.max_events_per_sec <480|1600|9999>`
- `setprop debug.input.resampling false`
- `setprop debug.input.touch_prediction false`
- `setprop debug.velocitytracker.strategy impulse`
- `setprop debug.tp.grip_enable 90`
- Roblox priority: appops allow + standby active + deviceidle whitelist
- optional `am compact <pid>` when Roblox PID exists

## Candidate probe set (not performance claims)
1. `cmd game` capability surface:
   - `cmd game help`
   - `cmd game list-modes com.roblox.client`
2. Display/readback stability:
   - `settings get system min_refresh_rate`
   - `settings get system peak_refresh_rate`
   - `settings get system user_refresh_rate`
   - `dumpsys SurfaceFlinger` readback for `activeMode=` and `GameFrameRateOverrides`
3. Input property writability/readback (temporary + restore):
   - `debug.inputdispatcher.max_events_per_sec`
   - `debug.input.resampling`
   - `debug.input.touch_prediction`
   - `debug.velocitytracker.strategy`
   - `debug.tp.grip_enable`
4. Memory/trim capability check only:
   - `am compact <pid>` if PID exists
   - `am send-trim-memory` help/readability only (no destructive global action)

## Rejected/Blocked (do not use)
- `device_config put/delete`
- thermal spoofing
- ANGLE/developer_graphics_driver forcing
- game driver substitution
- raw `service call`
- `/sys` or `/proc` writes
- ZRAM/sysctl/cgroup/uclamp/IRQ tuning
- `background_process_limit=2`
- broad `am kill-all`
- GMS/Play Store/Discord/cloned Discord/pedometer/ChatGPT modifications
