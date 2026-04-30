# redmi-roblox-optimizer

No-root Roblox optimizer for Redmi 15 4G (HyperOS 3 / Android 16) with Shizuku shell (UID 2000).

## Install / run (aShell You / AXManager)
1. Put `redmi_roblox_v9_2_adaptive.sh` in `/storage/emulated/0/Download/`.
2. Optional probe pack: copy `scripts/rb_capability_probe_v1.sh` to `/storage/emulated/0/Download/scripts/`.
3. Run full adaptive engage:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh engage`
4. Verify readback:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh verify`
5. Stop + restore baseline:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh stop`
6. If state/pid is stale after interrupted sessions:
   - `sh /storage/emulated/0/Download/redmi_roblox_v9_2_adaptive.sh --fresh`

## Key A/B modes
- `events1600` (current default full baseline)
- `events9999` (optional A/B test)
- `scale025` / `scale035`
- `grip90` / `grip120` / `grip150`

## Other modes
- `events480`, `events1200`
- `saver`, `full`
- `probe`, `diag`, `gfx`, `thermal`

## Safe probe usage
- Run probe only for capability/readback checks:
  - `sh /storage/emulated/0/Download/scripts/rb_capability_probe_v1.sh`
- Probe prints PASS/FAIL/UNKNOWN and restores temporary prop tests.
- Probe is not a performance claim; use A/B logs before promoting candidates.
