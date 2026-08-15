#!/system/bin/sh
# POCO F6 Pro Roblox 120 Hz Low-Latency Profile v2.1 MAX
# Target device: POCO F6 Pro / Snapdragon 8 Gen 2-class / HyperOS / Android shell
# Target access: AXManager, QuickShell, Shizuku UID 2000. No root required.
#
# AXManager/on-phone file directory:
# - Save this file as:
#     /storage/emulated/0/Download/poco_f6_pro_roblox_120_low_latency.sh
# - In AXManager/QuickShell, run:
#     cd /storage/emulated/0/Download
#     sh ./poco_f6_pro_roblox_120_low_latency.sh apply
# - To check or undo later, run:
#     sh ./poco_f6_pro_roblox_120_low_latency.sh verify
#     sh ./poco_f6_pro_roblox_120_low_latency.sh restore
# - No PC adb command is required. These are phone-local shell commands.
#
# Goal:
# - Push an aggressive competitive 120 FPS/120 Hz Roblox profile where Android/GameManager supports it.
# - Prefer lower render load, lower input delay, higher scheduler/performance hints, and less UI overhead.
# - Add POCO/HyperOS/Game Turbo style keys that shell can write, while still saving values for restore.
# - Shrink gesture interception zones and lower tap/touch delays as much as shell settings allow.
#
# Usage from the saved directory above:
#   sh ./poco_f6_pro_roblox_120_low_latency.sh apply
#   sh ./poco_f6_pro_roblox_120_low_latency.sh verify
#   sh ./poco_f6_pro_roblox_120_low_latency.sh restore
#
# Notes:
# - Shell/Shizuku cannot guarantee true 120 FPS. Roblox, the game place, thermal headroom,
#   display mode, and OEM GameManager support decide the final result.
# - This is intentionally more aggressive than a plain safe script. It uses selected SurfaceFlinger,
#   input, HyperOS/Game Turbo, refresh-rate, and power-mode hints that can be written from shell.
# - It still avoids /sys and /proc writes, app-killing sprees, accessibility/location disabling,
#   captive-portal/network hacks, and permanent thermal spoofing.

PKG="com.roblox.client"
SCRIPT_DIR="/storage/emulated/0/Download"
SCRIPT_FILE="$SCRIPT_DIR/poco_f6_pro_roblox_120_low_latency.sh"
BASE="$SCRIPT_DIR"
NAME="poco_f6_pro_roblox_120_low_latency"
LOG="$BASE/$NAME.log"
STATE="$BASE/$NAME.state"

FPS_TARGET="120"
DOWNSCALE_TARGET="0.75"
MIN_REFRESH="120"
PEAK_REFRESH="120"
TOUCH_EVENTS="1000"
TOUCH_STALE_NS="50000000"

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
system:cloud_turbo_sched_allow_list
system:cloud_turbo_sched_enable
system:cloud_schedboost_enable
global:miui_game_performance_mode
system:performance_mode_enable
system:high_performance_mode_on
system:power_mode
system:gpu_perf_mode
global:gpu_perf_mode
system:xiaomi_touch_sensitivity
system:touchscreen_sensitivity_mode
system:qti.inputopts.movetouchslop
system:view.touch_slop
system:touch_responsiveness
system:touch_boost_threshold
system:touch_response_rate
system:display.disable_dynamic_fps
system:display.disable_mitigated_fps
system:display.defer_fps_frame_count
system:display.enable_idle_content_fps_hint
system:back_gesture_inset_scale_left
system:back_gesture_inset_scale_right
system:back_gesture_inset
system:back_gesture_inset_left
system:back_gesture_inset_right
global:swipe_up_to_switch_apps_enabled
system:one_handed_mode_enabled
system:miui_one_handed_mode_type
system:one_handed_mode_factor
system:gesture_assist_enabled
system:edge_suppression_size
system:edge_touch_suppression
system:touchpanel_edge_filter
system:touchscreen_min_press_time
system:long_press_timeout
system:multi_press_timeout
system:double_tap_timeout
secure:long_press_timeout
"

PROPS_SAVE="
debug.inputdispatcher.max_events_per_sec
debug.input.resampling
debug.input.touch_prediction
debug.velocitytracker.strategy
debug.inputdispatcher.vsync
debug.inputdispatcher.stale_event_timeout_ns
debug.input.interceptdispatchtimeout_ms
debug.input.multitouch_min_distance
debug.input.quiet_interval
debug.input.touch_smooth
debug.input.filter
debug.inputreader.lsq2_enabled
debug.sf.disable_backpressure
debug.sf.enable_gl_backpressure
debug.sf.latch_unsignaled
debug.sf.auto_latch_unsignaled
debug.sf.predict_hwc_composition_strategy
debug.sf.enable_adpf_cpu_hint
debug.sf.frame_rate_multiple_threshold
debug.sf.set_idle_timer_ms
debug.hwui.skip_empty_damage
debug.hwui.use_partial_updates
debug.hwui.use_hint_manager
debug.hwui.render_ahead
debug.egl.swap_interval
debug.input.tap_timeout_ms
debug.input.long_press_timeout_ms
debug.input.double_tap_timeout_ms
debug.input.edge_rejection
debug.touch.pressure.scale
persist.sys.perf_turbo_type
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
    if [ -s "$STATE" ]; then
        log "Existing restore state found at $STATE; not overwriting original values."
        return 0
    fi
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

append_setting_csv() {
    ns="$1"
    key="$2"
    value="$3"
    cur="$(settings get "$ns" "$key" 2>/dev/null)"
    case "$cur" in
        *"$value"*) return 0 ;;
        ""|"null") run settings put "$ns" "$key" "$value" ;;
        *) run settings put "$ns" "$key" "$cur,$value" ;;
    esac
}

check_package() {
    if ! pm path "$PKG" >/dev/null 2>&1; then
        log "ERROR: Roblox package not found: $PKG"
        exit 1
    fi
}

apply_profile() {
    log "=== POCO F6 Pro Roblox 120 Hz low-latency apply ==="
    log "AXManager directory: save/run this script from $SCRIPT_FILE"
    log "Log file: $LOG"
    log "Restore state file: $STATE"
    check_package
    save_state

    log "Keeping Roblox active in the background and idle whitelist"
    run appops set "$PKG" RUN_IN_BACKGROUND allow
    run appops set "$PKG" RUN_ANY_IN_BACKGROUND allow
    run appops set "$PKG" WAKE_LOCK allow
    run am set-standby-bucket "$PKG" active
    run cmd deviceidle whitelist +"$PKG"

    log "Applying Android GameManager MAX target: ${FPS_TARGET} FPS, ${DOWNSCALE_TARGET} downscale"
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

    log "Applying aggressive POCO/HyperOS Game Turbo and performance hints"
    append_setting_csv system cloud_turbo_sched_allow_list "$PKG"
    run settings put system cloud_turbo_sched_enable 1
    run settings put system cloud_schedboost_enable 1
    run settings put global miui_game_performance_mode 1
    run settings put system performance_mode_enable 1
    run settings put system high_performance_mode_on 1
    run settings put system power_mode 1
    run settings put system gpu_perf_mode 1
    run settings put global gpu_perf_mode 1
    run setprop persist.sys.perf_turbo_type 1

    log "Applying aggressive input/touch latency hints"
    run setprop debug.inputdispatcher.max_events_per_sec "$TOUCH_EVENTS"
    run setprop debug.inputdispatcher.stale_event_timeout_ns "$TOUCH_STALE_NS"
    run setprop debug.input.interceptdispatchtimeout_ms 0
    run setprop debug.input.multitouch_min_distance 0
    run setprop debug.input.quiet_interval 0
    run setprop debug.input.touch_smooth 0
    run setprop debug.input.filter 0
    run setprop debug.inputreader.lsq2_enabled 1
    run setprop debug.input.resampling false
    run setprop debug.input.touch_prediction false
    run setprop debug.velocitytracker.strategy impulse
    run setprop debug.inputdispatcher.vsync 0
    run settings put system xiaomi_touch_sensitivity 3
    run settings put system touchscreen_sensitivity_mode 1
    run settings put system qti.inputopts.movetouchslop 0
    run settings put system view.touch_slop 6
    run settings put system touch_responsiveness 5
    run settings put system touch_boost_threshold 1
    run settings put system touch_response_rate 2
    run settings put system touchscreen_min_press_time 0
    run settings put system long_press_timeout 250
    run settings put secure long_press_timeout 250
    run settings put system multi_press_timeout 120
    run settings put system double_tap_timeout 160
    run setprop debug.input.tap_timeout_ms 0
    run setprop debug.input.long_press_timeout_ms 250
    run setprop debug.input.double_tap_timeout_ms 160
    run setprop debug.touch.pressure.scale 0.001
    run settings put system show_touches 0
    run settings put system pointer_location 0
    run settings put system haptic_feedback_enabled 0
    run settings put system vibrate_on_touch 0

    log "Killing gesture/edge interception that can steal Roblox touches"
    run settings put system back_gesture_inset_scale_left 0
    run settings put system back_gesture_inset_scale_right 0
    run settings put system back_gesture_inset 0
    run settings put system back_gesture_inset_left 0
    run settings put system back_gesture_inset_right 0
    run settings put global swipe_up_to_switch_apps_enabled 0
    run settings put system one_handed_mode_enabled 0
    run settings put system miui_one_handed_mode_type 0
    run settings put system one_handed_mode_factor 0
    run settings put system gesture_assist_enabled 0
    run settings put system edge_suppression_size 0
    run settings put system edge_touch_suppression 0
    run settings put system touchpanel_edge_filter 0
    run setprop debug.input.edge_rejection 0

    log "Applying selected compositor/render latency hints"
    run setprop debug.sf.disable_backpressure 1
    run setprop debug.sf.enable_gl_backpressure 0
    run setprop debug.sf.latch_unsignaled 1
    run setprop debug.sf.auto_latch_unsignaled 1
    run setprop debug.sf.predict_hwc_composition_strategy 1
    run setprop debug.sf.enable_adpf_cpu_hint 1
    run setprop debug.sf.frame_rate_multiple_threshold 0
    run setprop debug.sf.set_idle_timer_ms 0
    run setprop debug.hwui.skip_empty_damage 1
    run setprop debug.hwui.use_partial_updates 1
    run setprop debug.hwui.use_hint_manager true
    run setprop debug.hwui.render_ahead 0
    run setprop debug.egl.swap_interval 0
    run settings put system display.disable_dynamic_fps 1
    run settings put system display.disable_mitigated_fps 1
    run settings put system display.defer_fps_frame_count 0
    run settings put system display.enable_idle_content_fps_hint 0

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
    rm -f "$STATE" 2>/dev/null
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
    log "stale_timeout_ns:        $(getprop debug.inputdispatcher.stale_event_timeout_ns 2>/dev/null)"
    log "cloud_turbo_sched:       $(settings get system cloud_turbo_sched_enable 2>/dev/null)"
    log "turbo_allow_list:        $(settings get system cloud_turbo_sched_allow_list 2>/dev/null)"
    log "miui_game_perf:          $(settings get global miui_game_performance_mode 2>/dev/null)"
    log "gpu_perf_mode_sys:       $(settings get system gpu_perf_mode 2>/dev/null)"
    log "sf_disable_backpressure: $(getprop debug.sf.disable_backpressure 2>/dev/null)"
    log "back_gesture_left:       $(settings get system back_gesture_inset_scale_left 2>/dev/null)"
    log "back_gesture_right:      $(settings get system back_gesture_inset_scale_right 2>/dev/null)"
    log "min_press_time:         $(settings get system touchscreen_min_press_time 2>/dev/null)"
    log "long_press_timeout:     $(settings get system long_press_timeout 2>/dev/null)"
    log "edge_rejection:         $(getprop debug.input.edge_rejection 2>/dev/null)"
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
        echo "AXManager/on-phone directory:"
        echo "  Save this script as: $SCRIPT_FILE"
        echo ""
        echo "Run from AXManager/QuickShell:"
        echo "  cd $SCRIPT_DIR"
        echo "  sh ./poco_f6_pro_roblox_120_low_latency.sh apply"
        echo ""
        echo "Other modes:"
        echo "  sh ./poco_f6_pro_roblox_120_low_latency.sh verify"
        echo "  sh ./poco_f6_pro_roblox_120_low_latency.sh restore"
        echo ""
        echo "Log:   $LOG"
        echo "State: $STATE"
        exit 2
        ;;
esac
