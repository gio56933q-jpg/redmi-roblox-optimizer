#!/system/bin/sh
# POCO F6 Pro Roblox 120 Hz profile v1.1
# Target: POCO F6 Pro, HyperOS/Android shell (AXManager, QuickShell, or Shizuku UID 2000).
#
# Reality: this phone's panel can present at most 120 distinct frames each second. Requesting
# 200+ FPS cannot make a 120 Hz panel display 200 FPS and usually wastes thermal headroom.
# Android shell cannot eliminate touch latency, alter the touch-controller scan rate, or bypass
# Roblox/game-server frame caps. This profile removes avoidable OS scheduling/display limits only.
#
# Usage: sh poco_f6_pro_roblox_120_low_latency.sh apply|verify|restore
#
# The script deliberately does not use unsupported debug input properties, thermal overrides,
# /sys or /proc writes, device_config changes, or vendor performance-service calls. Those are
# either not persistent/effective from shell or trade device safety for unmeasurable claims.

PKG="com.roblox.client"
BASE="/storage/emulated/0/Download"
NAME="poco_f6_pro_roblox_120_low_latency"
LOG="$BASE/$NAME.log"
STATE="$BASE/$NAME.state"

FPS_TARGET="120"
MIN_REFRESH="120"
PEAK_REFRESH="120"
RB_NULL="__RB_NULL__"

SETTINGS_SAVE="
system:min_refresh_rate
system:peak_refresh_rate
system:user_refresh_rate
system:miui_refresh_rate
global:window_animation_scale
global:transition_animation_scale
global:animator_duration_scale
global:low_power
global:low_power_sticky
"

mkdir -p "$BASE" 2>/dev/null

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }

run() {
    "$@" >>"$LOG" 2>&1
    rc=$?
    [ "$rc" -eq 0 ] || log "WARN[$rc]: $*"
    return "$rc"
}

state_has() {
    key="$1"
    [ -f "$STATE" ] && awk -F= -v k="$key" 'index($0,k"=")==1 { found=1 } END { exit !found }' "$STATE" 2>/dev/null
}

state_set() {
    key="$1"
    value="$2"
    [ -f "$STATE" ] || : >"$STATE"
    awk -F= -v k="$key" 'index($0,k"=")!=1 { print }' "$STATE" >"$STATE.tmp" 2>/dev/null && mv "$STATE.tmp" "$STATE"
    printf '%s=%s\n' "$key" "$value" >>"$STATE"
}

state_get() {
    key="$1"
    [ -f "$STATE" ] || return 1
    awk -F= -v k="$key" 'index($0,k"=")==1 { sub("^[^=]*=", ""); print; exit }' "$STATE" 2>/dev/null
}

# Preserve the pre-first-apply value. Re-running apply must not overwrite the restore point.
save_setting_once() {
    ns="$1"
    key="$2"
    state_key="setting.$ns.$key"
    state_has "$state_key" && return 0
    cur="$(settings get "$ns" "$key" 2>/dev/null)"
    [ "$cur" = "null" ] || [ -n "$cur" ] || cur="$RB_NULL"
    state_set "$state_key" "$cur"
}

restore_setting() {
    ns="$1"
    key="$2"
    saved="$(state_get "setting.$ns.$key")"
    [ -n "$saved" ] || return 0
    if [ "$saved" = "$RB_NULL" ]; then
        run settings delete "$ns" "$key"
    else
        run settings put "$ns" "$key" "$saved"
    fi
}

save_state() {
    for item in $SETTINGS_SAVE; do
        save_setting_once "${item%%:*}" "${item#*:}"
    done
}

check_package() {
    if ! pm path "$PKG" >/dev/null 2>&1; then
        log "ERROR: Roblox package not found: $PKG"
        exit 1
    fi
}

apply_profile() {
    log "=== POCO F6 Pro Roblox 120 Hz profile: apply ==="
    check_package
    save_state

    # 1.0 downscale retains native render resolution; do not sacrifice clarity on an 8 Gen 2
    # device unless a specific Roblox experience fails the 120-FPS stability test.
    log "Requesting GameManager custom mode: ${FPS_TARGET} FPS, native scale"
    run cmd game mode custom "$PKG"
    run cmd game set --downscale 1.0 --fps "$FPS_TARGET" "$PKG"

    log "Requesting 120 Hz and disabling Android UI animations / Battery Saver"
    run settings put system min_refresh_rate "$MIN_REFRESH"
    run settings put system peak_refresh_rate "$PEAK_REFRESH"
    run settings put system user_refresh_rate "$PEAK_REFRESH"
    run settings put system miui_refresh_rate "$PEAK_REFRESH"
    run settings put global window_animation_scale 0
    run settings put global transition_animation_scale 0
    run settings put global animator_duration_scale 0
    run settings put global low_power 0
    run settings put global low_power_sticky 0

    log "Compiling Roblox with speed-profile"
    run cmd package compile -m speed-profile -f "$PKG"

    verify_profile
    log "Applied. Validate in the same experience for 15 minutes without charging; if frame time rises, reduce Roblox graphics before lowering refresh rate."
}

restore_profile() {
    log "=== POCO F6 Pro Roblox profile: restore ==="
    for item in $SETTINGS_SAVE; do
        restore_setting "${item%%:*}" "${item#*:}"
    done
    run cmd game reset "$PKG"
    rm -f "$STATE"
    log "Restore complete. GameManager settings were reset to their platform defaults."
}

verify_profile() {
    log "=== Verify (requested values, not an FPS guarantee) ==="
    log "package:           $PKG"
    log "min_refresh_rate:  $(settings get system min_refresh_rate 2>/dev/null)"
    log "peak_refresh_rate: $(settings get system peak_refresh_rate 2>/dev/null)"
    log "user_refresh_rate: $(settings get system user_refresh_rate 2>/dev/null)"
    log "miui_refresh_rate: $(settings get system miui_refresh_rate 2>/dev/null)"
    log "battery_saver:     $(settings get global low_power 2>/dev/null)"
    log "animation_scale:   $(settings get global window_animation_scale 2>/dev/null)"
    timeout 3 dumpsys game 2>/dev/null | grep -i -A 10 "$PKG" | tee -a "$LOG" >/dev/null || log "WARN: GameManager readback unavailable. Check 'cmd game help' on this HyperOS build."
    timeout 3 dumpsys SurfaceFlinger 2>/dev/null | grep -E 'activeMode=|renderRate=|GameFrameRateOverrides' | head -20 | tee -a "$LOG" >/dev/null || log "WARN: SurfaceFlinger refresh readback unavailable."
}

case "$1" in
    apply|start|boost) apply_profile ;;
    restore|reset|stop) restore_profile ;;
    verify|status) verify_profile ;;
    *)
        echo "Usage: sh $0 apply|verify|restore"
        exit 2
        ;;
esac
