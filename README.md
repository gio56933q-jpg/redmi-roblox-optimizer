# POCO F6 Pro Roblox 120 Hz profile

A small, reversible Android-shell profile for Roblox on a **POCO F6 Pro**. Run it through a shell-capable tool such as Shizuku, AXManager, or QuickShell:

```sh
sh poco_f6_pro_roblox_120_low_latency.sh apply
sh poco_f6_pro_roblox_120_low_latency.sh verify
sh poco_f6_pro_roblox_120_low_latency.sh restore
```

## Hard limits

- The POCO F6 Pro display is 120 Hz. It cannot visibly present 200 FPS, regardless of an FPS counter or a shell command.
- The script requests a 120 FPS GameManager cap and 120 Hz refresh. Roblox, the specific experience, Android/HyperOS support, GPU load, temperature, and server conditions determine the delivered frame rate and latency.
- Touch delay cannot be reduced to zero from Android shell. Touch-controller sampling, display scan-out, Android input dispatch, engine simulation, and network/server time remain in the path.

## What `apply` changes

- Requests Roblox GameManager custom mode at **120 FPS** and native render scale.
- Requests 120 Hz through the standard Android/HyperOS refresh settings.
- Disables Android UI animations and Battery Saver.
- Recompiles Roblox using `speed-profile`.
- Saves every changed setting only on the first apply, so repeated runs retain a correct restore point.

## What it intentionally does not do

It does not fake thermal state, modify `/sys`/`/proc`, inject vendor performance calls, set speculative `debug.*` input properties, or promise impossible 200+ visible FPS/zero-touch-delay results. Those approaches are either unsupported from Shizuku shell, unsafe, or cannot produce the claimed hardware outcome.

## Testing correctly

1. Restart Roblox after applying.
2. Use the same Roblox experience and graphics quality for every test.
3. Test for at least 15 minutes, unplugged and at a fixed brightness; heat throttling invalidates short tests.
4. Check frame-time consistency, not only the FPS peak. If performance degrades, lower the Roblox graphics preset before abandoning 120 Hz.
5. Run `restore` to revert the saved Android settings and reset Roblox GameManager settings.
