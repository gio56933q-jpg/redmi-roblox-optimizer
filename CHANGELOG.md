# Changelog

## v9.2.3
- Tightened README conflict-resolution instructions for Termux users who only have `main` locally and no `work` branch.
- Added a copy/paste-safe branch recovery flow (`fetch`/`ff-only pull`/new branch/commit/push/PR) to avoid repeated "This branch has conflicts" loops on GitHub.
- Added explicit note to use PAT for HTTPS pushes and avoid concatenated command typos.

## v9.2.2
- Added a Termux GitHub sync troubleshooting section to `README.md` with exact conflict-recovery commands (`fetch`, `merge origin/main`) and commit identity setup guidance.
- Clarified common command-entry mistake handling (accidental concatenated commands on a single line) to reduce false merge/push failures.

## v9.2.1
- Changed default full event profile from `9999` to `1600` based on latest on-device A/B evidence.
- Kept `events9999` as optional test mode.
- Hardened event test modes (`events480`, `events1200`, `events1600`, `events9999`) to reapply confirmed input baseline (`resampling=false`, `touch_prediction=false`, `velocitytracker=impulse`, `grip=90`) plus Roblox priority stack.
- Updated daemon maintenance loop to reassert active lightweight input/profile state each cycle (full=1600 or saver=480) plus Roblox priority, without invoking heavy hog cleanup/compaction each loop.
- Added optional read-only/diagnostic modes: `probe`, `diag`, `gfx`, `thermal`.
- Added `docs/candidate_commands.md` and `scripts/rb_capability_probe_v1.sh` for safe capability probing only.

## v9.2
- Added stable mode set: `engage`, `saver`, `events480`, `events1600`, `events9999`, `scale025`, `scale035`, `grip90`, `grip120`, `grip150`, `verify`, and `stop/restore`.
- Added state capture/restore for props, settings, appops, game mode/scaling/fps, standby bucket, and deviceidle whitelist entries changed by the script.
- Kept daemon logic PID-file based and avoided broad kill patterns.
- Added periodic reapply of Roblox `active` standby bucket and `deviceidle` whitelist while daemon is active.
- Included verify readbacks for identity, power, game mode/overrides, SurfaceFlinger, input props, whitelist, appops, standby bucket, and gfxinfo when Roblox is running.
- Excluded risky or blocked classes of commands (root-only writes, `device_config` mutations, unsupported driver forcing, thermal spoofing, and broad background kill behavior).
