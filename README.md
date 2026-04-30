# redmi-roblox-optimizer

No-root Roblox optimization script for Redmi 15 4G (HyperOS 3 / Android 16) using Shizuku shell access (UID 2000).

## aShell You / AXManager usage

1. Copy `redmi_roblox_v9_2_adaptive.sh` to `/storage/emulated/0/Download/`.
2. Open a shell through aShell You or AXManager with Shizuku enabled.
3. Run:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh engage`
4. Verify readback:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh verify`
5. Restore baseline when done:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh stop`
6. If state or daemon files are stale (for example after interrupted runs), reset safely:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh --fresh`

## Modes

- `engage` (default full adaptive profile)
- `saver` (60 FPS + lower input event rate)
- `events480` / `events1600` / `events9999`
- `scale025` / `scale035`
- `grip90` / `grip120` / `grip150`
- `verify`
- `stop` / `restore`
- `fresh` / `--fresh` (clear stale v9.2 state/pid files, then save new baseline and engage)

## Notes

- Uses safe PID-file daemon logic and periodic Roblox whitelist/standby reapply.
- Restores only saved values changed by the script.
- Excludes root-only or blocked commands by design.
