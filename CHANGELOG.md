# Changelog

## v9.2

- Added stable mode set: `engage`, `saver`, `events480`, `events1600`, `events9999`, `scale025`, `scale035`, `grip90`, `grip120`, `grip150`, `verify`, and `stop/restore`.
- Added state capture/restore for props, settings, appops, game mode/scaling/fps, standby bucket, and deviceidle whitelist entries changed by the script.
- Kept daemon logic PID-file based and avoided broad kill patterns.
- Added periodic reapply of Roblox `active` standby bucket and `deviceidle` whitelist while daemon is active.
- Included verify readbacks for identity, power, game mode/overrides, SurfaceFlinger, input props, whitelist, appops, standby bucket, and gfxinfo when Roblox is running.
- Excluded risky or blocked classes of commands (root-only writes, `device_config` mutations, unsupported driver forcing, thermal spoofing, and broad background kill behavior).
