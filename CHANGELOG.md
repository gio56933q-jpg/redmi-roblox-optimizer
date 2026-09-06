# Changelog

## POCO F6 Pro profile v1.1
- Reworked the POCO F6 Pro profile around the device's 120 Hz display ceiling and native-resolution 120-FPS request.
- Removed speculative input-property and background/AppOps tuning that could not guarantee lower touch latency.
- Made settings capture idempotent so repeated `apply` runs no longer overwrite the original restore point.
- Added explicit verification output and documentation of hardware, Roblox, thermal, and network limits.
