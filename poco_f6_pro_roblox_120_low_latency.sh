#!/system/bin/sh
# POCO F6 Pro Roblox 120 Hz Low-Latency Profile v1.0
# Target device: POCO F6 Pro / Snapdragon 8 Gen 2-class / HyperOS / Android shell
# Target access: AXManager, QuickShell, Shizuku UID 2000. No root required.
#
# Goal:
# - Prefer a stable 120 FPS/120 Hz Roblox session where Android GameManager supports it.
# - Reduce input and UI latency without spoofing thermals or writing kernel/vendor nodes.
# - Save changed settings so they can be restored later.
#
# Usage:
#   sh poco_f6_pro_roblox_120_low_latency.sh apply
#   sh poco_f6_pro_roblox_120_low_latency.sh verify
#   sh poco_f6_pro_roblox_120_low_latency.sh restore
#
# Notes:
# - Shell/Shizuku cannot guarantee true 120 FPS. Roblox, the game place, thermal headroom,
#   display mode, and OEM GameManager support decide the final result.
# - This script intentionally avoids thermalservice override-status, device_config mutation,
#   broad debug.sf/HWUI prop packs, network validation hacks, accessibility/location disabling,
#   and any /sys or /proc writes.

PKG="com.roblox.client"
BASE="/storage/emulated/0/Download"
NAME="poco_f6_pro_roblox_120_low_latency"
LOG="$BASE/$NAME.log"
STATE="$BASE/$NAME.state"

FPS_TARGET="120"
DOWNSCALE_TARGET="0.85"
MIN_REFRESH="120"
PEAK_REFRESH="120"
TOUCH_EVENTS="360"

RB_NULL="__RB_NULL__"
RB_EMPTY="__RB_EMPTY__"

SETTINGS_SAVE="
system:min_refresh_rate
system:peak_refresh_rate
system:user_refresh_rate
system:miui_refresh_rate
global:window_animation_scale
global:transition_animation_scale
global:animator_duration_scale
system:haptic_feedback_enabled
system:vibrate_on_touch
system:show_touches
system:pointer_location
global:low_power
global:low_power_sticky
"

PROPS_SAVE="
debug.inputdispatcher.max_events_per_sec
debug.input.resampling
debug.input.touch_prediction
debug.velocitytracker.strategy
debug.inputdispatcher.vsync
"

mkdir -p "$BASE" 2>/dev/null

log() {
    echo "$(date '+%F %T') $*" | tee -a "$LOG"
}

run() {
    "$@" >>"$LOG" 2>&1
    rc=$?
    [ "$rc" -ne 0 ] && log "WARN[$rc]: $*"
    return 0
}

state_set() {
    key="$1"
    value="$2"
    [ -f "$STATE" ] || : >"$STATE"
    awk -F= -v k="$key" 'index($0,k"=")!=1{print}' "$STATE" >"$STATE.tmp" 2>/dev/null && mv "$STATE.tmp" "$STATE"
    printf '%s=%s\n' "$key" "$value" >>"$STATE"
}

state_get() {
    key="$1"
    [ -f "$STATE" ] || return 1
    awk -F= -v k="$key" 'index($0,k"=")==1{sub("^[^=]*=",""); print; exit}' "$STATE" 2>/dev/null
}

save_setting() {
    ns="$1"
    key="$2"
    cur="$(settings get "$ns" "$key" 2>/dev/null)"
    [ "$cur" = "null" ] && cur="$RB_NULL"
    [ -z "$cur" ] && cur="$RB_EMPTY"
    state_set "setting.$ns.$key" "$cur"
}

restore_setting() {
    ns="$1"
    key="$2"
    saved="$(state_get "setting.$ns.$key")"
    [ -z "$saved" ] && return 0
    case "$saved" in
        "$RB_NULL") run settings delete "$ns" "$key" ;;
        "$RB_EMPTY") run settings put "$ns" "$key" "" ;;
        *) run settings put "$ns" "$key" "$saved" ;;
    esac
}

save_prop() {
    key="$1"
    cur="$(getprop "$key" 2>/dev/null)"
    [ -z "$cur" ] && cur="$RB_EMPTY"
    state_set "prop.$key" "$cur"
}

restore_prop() {
    key="$1"
    saved="$(state_get "prop.$key")"
    [ -z "$saved" ] && return 0
    if [ "$saved" = "$RB_EMPTY" ]; then
        run setprop "$key" ""
    else
        run setprop "$key" "$saved"
    fi
}

save_state() {
    log "Saving current settings/properties to $STATE"
    for item in $SETTINGS_SAVE; do
        ns="${item%%:*}"
        key="${item#*:}"
        save_setting "$ns" "$key"
    done
    for key in $PROPS_SAVE; do
        save_prop "$key"
    done
}

check_package() {
    if ! pm path "$PKG" >/dev/null 2>&1; then
        log "ERROR: Roblox package not found: $PKG"
        exit 1
    fi
}

apply_profile() {
    log "=== POCO F6 Pro Roblox 120 Hz low-latency apply ==="
    check_package
    save_state

    log "Keeping Roblox active in the background and idle whitelist"
    run appops set "$PKG" RUN_IN_BACKGROUND allow
    run appops set "$PKG" RUN_ANY_IN_BACKGROUND allow
    run appops set "$PKG" WAKE_LOCK allow
    run am set-standby-bucket "$PKG" active
    run cmd deviceidle whitelist +"$PKG"

    log "Applying Android GameManager performance target: ${FPS_TARGET} FPS, ${DOWNSCALE_TARGET} downscale"
    run cmd game mode performance "$PKG"
    run cmd game set --downscale "$DOWNSCALE_TARGET" --fps "$FPS_TARGET" "$PKG"

    log "Requesting fixed 120 Hz display and disabling launcher/UI animations"
    run settings put system min_refresh_rate "$MIN_REFRESH"
    run settings put system peak_refresh_rate "$PEAK_REFRESH"
    run settings put system user_refresh_rate "$PEAK_REFRESH"
    run settings put system miui_refresh_rate "$PEAK_REFRESH"
    run settings put global window_animation_scale 0
    run settings put global transition_animation_scale 0
    run settings put global animator_duration_scale 0
    run settings put global low_power 0
    run settings put global low_power_sticky 0

    log "Applying conservative input latency hints"
    run setprop debug.inputdispatcher.max_events_per_sec "$TOUCH_EVENTS"
    run setprop debug.input.resampling false
    run setprop debug.input.touch_prediction false
    run setprop debug.velocitytracker.strategy impulse
    run setprop debug.inputdispatcher.vsync 1
    run settings put system show_touches 0
    run settings put system pointer_location 0
    run settings put system haptic_feedback_enabled 0
    run settings put system vibrate_on_touch 0

    log "Compiling Roblox with speed-profile"
    run cmd package compile -m speed-profile -f "$PKG"

    log "Resetting any previous thermal spoof instead of overriding thermals"
    run cmd thermalservice reset

    verify_profile
    log "Apply complete. For best stability: use a cooler/fan, avoid charging, lower brightness, and test the same Roblox place for 10+ minutes."
}

restore_profile() {
    log "=== POCO F6 Pro Roblox restore ==="
    for item in $SETTINGS_SAVE; do
        ns="${item%%:*}"
        key="${item#*:}"
        restore_setting "$ns" "$key"
    done
    for key in $PROPS_SAVE; do
        restore_prop "$key"
    done
    run cmd game reset "$PKG"
    run cmd deviceidle whitelist -"$PKG"
    run am set-standby-bucket "$PKG" working_set
    run cmd thermalservice reset
    log "Restore complete."
}

verify_profile() {
    log "=== Verify ==="
    log "package:                 $PKG"
    log "standby_bucket:          $(am get-standby-bucket "$PKG" 2>/dev/null)"
    log "RUN_IN_BACKGROUND:       $(appops get "$PKG" RUN_IN_BACKGROUND 2>/dev/null)"
    log "RUN_ANY_IN_BACKGROUND:   $(appops get "$PKG" RUN_ANY_IN_BACKGROUND 2>/dev/null)"
    log "WAKE_LOCK:               $(appops get "$PKG" WAKE_LOCK 2>/dev/null)"
    log "min_refresh_rate:        $(settings get system min_refresh_rate 2>/dev/null)"
    log "peak_refresh_rate:       $(settings get system peak_refresh_rate 2>/dev/null)"
    log "user_refresh_rate:       $(settings get system user_refresh_rate 2>/dev/null)"
    log "miui_refresh_rate:       $(settings get system miui_refresh_rate 2>/dev/null)"
    log "animation_scale:         $(settings get global window_animation_scale 2>/dev/null)"
    log "touch_events:            $(getprop debug.inputdispatcher.max_events_per_sec 2>/dev/null)"
    log "input_resampling:        $(getprop debug.input.resampling 2>/dev/null)"
    log "touch_prediction:        $(getprop debug.input.touch_prediction 2>/dev/null)"
    log "velocity_tracker:        $(getprop debug.velocitytracker.strategy 2>/dev/null)"
    log "haptic_feedback:         $(settings get system haptic_feedback_enabled 2>/dev/null)"
    log "vibrate_on_touch:        $(settings get system vibrate_on_touch 2>/dev/null)"
    timeout 3 dumpsys game 2>/dev/null | grep -i -A 10 "$PKG" | tee -a "$LOG" >/dev/null || log "GameManager dump did not show $PKG or timed out."
}

case "$1" in
    apply|start|boost) apply_profile ;;
    restore|reset|stop) restore_profile ;;
    verify|status) verify_profile ;;
    *)
        echo "Usage: sh $0 apply|verify|restore"
        echo "Recommended first run: sh $0 apply"
        exit 2
        ;;
esac
