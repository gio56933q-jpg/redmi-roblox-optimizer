#!/system/bin/sh
# Redmi Roblox v9.2 Adaptive
# Device target: Redmi 15 4G / HyperOS 3 / Android 16 / Snapdragon 685 / Adreno 610
# Access target: Shizuku UID 2000 shell only. No root.
#
# Default full profile:
# - Roblox com.roblox.client
# - GameManager custom mode, downscale 0.25, FPS 120
# - 120 Hz refresh settings
# - max_events_per_sec 1600
# - input resampling false, touch prediction false, velocitytracker impulse
# - debug.tp.grip_enable 90
# - aggressive SurfaceFlinger low-wait props
# - Roblox AppOps allow, DeviceIdle whitelist, standby active
# - compact Roblox PID if running
#
# Hard exclusions:
# No /sys writes, no /proc writes, no device_config writes, no raw service calls,
# no thermal spoofing, no background_process_limit=2, no am kill-all,
# no ANGLE/developer graphics forcing, no GMS/Play Store/Discord/pedometer/ChatGPT changes.

BASE="/storage/emulated/0/Download"
GAME="com.roblox.client"
SCRIPT_NAME="redmi_roblox_v9_2_adaptive.sh"

LOG="$BASE/redmi_roblox_v9_2_adaptive.log"
STATE="$BASE/redmi_roblox_v9_2_adaptive.state"
PIDFILE="$BASE/redmi_roblox_v9_2_adaptive.pid"

DOWN_FULL="0.25"
FPS_FULL="120"
FPS_SAVER="60"
EVENTS_FULL="1600"
EVENTS_SAVER="480"
GRIP_DEFAULT="0"

RB_NULL="__RB_NULL__"
RB_EMPTY="__RB_EMPTY__"

# Safe hog list only. Do not add Discord, cloned Discord, pedometer, ChatGPT, GMS, Play Store.
HOGS_USER0="com.zhiliaoapp.musically com.brave.browser com.google.android.googlequicksearchbox com.xiaomi.aicr com.miui.mediaeditor com.miui.analytics"

PROPS_SAVE="
debug.inputdispatcher.max_events_per_sec
debug.input.resampling
debug.input.touch_prediction
debug.velocitytracker.strategy
debug.input.interceptdispatchtimeout_ms
debug.input.multitouch_min_distance
debug.input.quiet_interval
debug.input.touch_smooth
debug.input.filter
debug.inputdispatcher.vsync
debug.inputreader.lsq2_enabled
debug.tp.grip_enable
debug.sf.disable_backpressure
debug.sf.enable_gl_backpressure
debug.sf.latch_unsignaled
debug.sf.auto_latch_unsignaled
debug.sf.set_idle_timer_ms
debug.sf.predict_hwc_composition_strategy
debug.sf.enable_adpf_cpu_hint
debug.sf.frame_rate_multiple_threshold
debug.sf.compbypass.enable
debug.hwui.renderer
debug.hwui.render_backend
debug.hwui.use_hint_manager
debug.hwui.skip_empty_damage
debug.hwui.use_buffer_age
debug.hwui.use_partial_updates
debug.hwui.use_gpu_pixel_buffers
debug.hwui.render_dirty_regions
debug.renderengine.backend
debug.vulkan.enabled
debug.egl.hw
persist.sys.perf_turbo_type
"

SETTINGS_SAVE="
global:low_power
global:low_power_sticky
system:min_refresh_rate
system:peak_refresh_rate
system:user_refresh_rate
system:miui_refresh_rate
"

mkdir -p "$BASE" 2>/dev/null

log() {
    echo "$(date +%F_%T) $*" | tee -a "$LOG"
}

try() {
    "$@" >> "$LOG" 2>&1 || true
}

rotate_log() {
    [ -f "$LOG" ] || return 0
    SZ="$(wc -c < "$LOG" 2>/dev/null)"
    [ -n "$SZ" ] || return 0
    if [ "$SZ" -gt 1048576 ]; then
        mv "$LOG" "$LOG.old" 2>/dev/null || true
    fi
}

state_put() {
    KEY="$1"
    VAL="$2"
    [ -f "$STATE" ] || : > "$STATE"
    awk -F= -v k="$KEY" 'index($0,k"=")!=1{print}' "$STATE" > "$STATE.tmp" 2>/dev/null && mv "$STATE.tmp" "$STATE"
    printf "%s=%s\n" "$KEY" "$VAL" >> "$STATE"
}

state_get() {
    KEY="$1"
    [ -f "$STATE" ] || return 0
    awk -F= -v k="$KEY" 'index($0,k"=")==1{sub("^[^=]*=",""); print; exit}' "$STATE" 2>/dev/null
}

state_has() {
    KEY="$1"
    [ -f "$STATE" ] || return 1
    awk -F= -v k="$KEY" 'index($0,k"=")==1{found=1} END{exit !found}' "$STATE" 2>/dev/null
}

save_prop_once() {
    KEY="$1"
    state_has "prop:$KEY" && return 0
    VAL="$(getprop "$KEY" 2>/dev/null)"
    [ -z "$VAL" ] && VAL="$RB_EMPTY"
    state_put "prop:$KEY" "$VAL"
}

restore_prop() {
    KEY="$1"
    VAL="$(state_get "prop:$KEY")"
    [ -z "$VAL" ] && return 0
    [ "$VAL" = "$RB_EMPTY" ] && VAL=""
    try setprop "$KEY" "$VAL"
}

save_setting_once() {
    NS="$1"
    KEY="$2"
    state_has "setting:$NS:$KEY" && return 0
    VAL="$(settings get "$NS" "$KEY" 2>/dev/null)"
    case "$VAL" in ""|null) VAL="$RB_NULL" ;; esac
    state_put "setting:$NS:$KEY" "$VAL"
}

restore_setting() {
    NS="$1"
    KEY="$2"
    VAL="$(state_get "setting:$NS:$KEY")"
    [ -z "$VAL" ] && return 0
    if [ "$VAL" = "$RB_NULL" ]; then
        try settings delete "$NS" "$KEY"
    else
        try settings put "$NS" "$KEY" "$VAL"
    fi
}

pkg_exists_user() {
    U="$1"
    P="$2"
    cmd package list packages --user "$U" "$P" 2>/dev/null | grep -Fxq "package:$P"
}

appop_mode() {
    U="$1"
    P="$2"
    OP="$3"
    OUT="$(appops get --user "$U" "$P" "$OP" 2>/dev/null)"
    echo "$OUT" | awk -v op="$OP" '$1==op":" {gsub(";","",$2); print $2; found=1} END{if(!found) print "default"}'
}

save_appop_once() {
    U="$1"
    P="$2"
    OP="$3"
    state_has "appop:$U:$P:$OP" && return 0
    MODE="$(appop_mode "$U" "$P" "$OP")"
    [ -z "$MODE" ] && MODE="default"
    state_put "appop:$U:$P:$OP" "$MODE"
}

restore_appop() {
    U="$1"
    P="$2"
    OP="$3"
    MODE="$(state_get "appop:$U:$P:$OP")"
    [ -z "$MODE" ] && return 0
    pkg_exists_user "$U" "$P" || return 0
    try appops set --user "$U" "$P" "$OP" "$MODE"
}

is_whitelisted() {
    P="$1"
    cmd deviceidle whitelist 2>/dev/null | sed 's/^[[:space:]]*//' | grep -Fxq "$P"
}

save_game_state_once() {
    state_has "game:mode" && return 0

    MODE="$(cmd game list-modes "$GAME" 2>/dev/null | sed -n 's/.*current mode: \([^,]*\).*/\1/p' | head -1)"
    [ -z "$MODE" ] && MODE="unknown"

    LINE="$(cmd game list-modes "$GAME" 2>/dev/null | grep -i "Name:$GAME" | head -1)"
    [ -z "$LINE" ] && LINE="$(dumpsys game 2>/dev/null | grep -i "Name:$GAME" | head -1)"

    SCALE="$(echo "$LINE" | sed -n 's/.*Scaling:\([^,}]*\).*/\1/p')"
    GFPS="$(echo "$LINE" | sed -n 's/.*Fps:\([^,}]*\).*/\1/p')"

    [ -z "$SCALE" ] && SCALE="$RB_EMPTY"
    [ -z "$GFPS" ] && GFPS="0"

    state_put "game:mode" "$MODE"
    state_put "game:scale" "$SCALE"
    state_put "game:fps" "$GFPS"
}

restore_game() {
    MODE="$(state_get "game:mode")"
    SCALE="$(state_get "game:scale")"
    GFPS="$(state_get "game:fps")"
    [ -z "$MODE" ] && MODE="standard"

    case "$MODE" in
        custom)
            if [ -n "$SCALE" ] && [ "$SCALE" != "$RB_EMPTY" ]; then
                [ -z "$GFPS" ] && GFPS="0"
                try cmd game set --downscale "$SCALE" --fps "$GFPS" "$GAME"
            fi
            try cmd game mode custom "$GAME"
            ;;
        standard)
            try cmd game mode standard "$GAME"
            ;;
        *)
            try cmd game mode standard "$GAME"
            ;;
    esac
}

stop_pidfile() {
    PF="$1"
    [ -f "$PF" ] || return 0
    PID="$(cat "$PF" 2>/dev/null)"
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        if [ "$PID" != "$$" ]; then
            kill "$PID" 2>/dev/null || true
            sleep 1
            kill -9 "$PID" 2>/dev/null || true
        fi
    fi
    rm -f "$PF"
}

stop_legacy_pidfiles() {
    stop_pidfile "$BASE/redmi_roblox_v9_adaptive.pid"
    stop_pidfile "$BASE/redmi_roblox_v9_1_adaptive.pid"
    stop_pidfile "$BASE/rb_battery_adaptive.pid"
    rm -f "$BASE/redmi_roblox_v8.lock" 2>/dev/null
}

save_all_once() {
    rotate_log
    [ -f "$STATE" ] || : > "$STATE"

    save_game_state_once

    for K in $PROPS_SAVE; do
        save_prop_once "$K"
    done

    for ITEM in $SETTINGS_SAVE; do
        NS="${ITEM%%:*}"
        KEY="${ITEM#*:}"
        save_setting_once "$NS" "$KEY"
    done

    for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK START_FOREGROUND; do
        save_appop_once 0 "$GAME" "$OP"
    done

    BUCKET="$(am get-standby-bucket "$GAME" 2>/dev/null | head -1)"
    [ -z "$BUCKET" ] && BUCKET="$RB_EMPTY"
    state_put "standby:$GAME" "$BUCKET"

    if is_whitelisted "$GAME"; then
        state_put "deviceidle_added:$GAME" "0"
    else
        state_put "deviceidle_added:$GAME" "1"
    fi

    for P in $HOGS_USER0; do
        pkg_exists_user 0 "$P" || continue
        for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK; do
            save_appop_once 0 "$P" "$OP"
        done
    done
}

apply_refresh_120() {
    try settings put global low_power 0
    try settings put global low_power_sticky 0
    try settings put system min_refresh_rate 120.0
    try settings put system peak_refresh_rate 120.0
    try settings put system user_refresh_rate 120.0
    try settings put system miui_refresh_rate 120
}

apply_touch_common() {
    try setprop debug.input.resampling false
    try setprop debug.input.touch_prediction false
    try setprop debug.velocitytracker.strategy impulse
    try setprop debug.input.interceptdispatchtimeout_ms 0
    try setprop debug.input.multitouch_min_distance 0
    try setprop debug.input.quiet_interval 0
    try setprop debug.input.touch_smooth 0
    try setprop debug.input.filter 0
    try setprop debug.inputdispatcher.vsync 0
    try setprop debug.inputreader.lsq2_enabled 0
}

apply_events() {
    VAL="$1"
    try setprop debug.inputdispatcher.max_events_per_sec "$VAL"
}

apply_grip() {
    VAL="$1"
    # debug.tp.grip_enable is the writable/usable prop observed in testing.
    try setprop debug.tp.grip_enable "$VAL"
}

apply_sf_low_wait() {
    try setprop debug.sf.disable_backpressure 1
    try setprop debug.sf.enable_gl_backpressure 0
    try setprop debug.sf.latch_unsignaled 1
    try setprop debug.sf.auto_latch_unsignaled 1
    try setprop debug.sf.set_idle_timer_ms 0
    try setprop debug.sf.predict_hwc_composition_strategy 0
    try setprop debug.sf.enable_adpf_cpu_hint 1
    try setprop debug.sf.frame_rate_multiple_threshold 0
    try setprop debug.sf.compbypass.enable 1
}

apply_hwui_profile() {
    try setprop debug.hwui.renderer skiavkthreaded
    try setprop debug.hwui.render_backend skiavk
    try setprop debug.renderengine.backend skiavkthreaded
    try setprop debug.hwui.use_hint_manager true
    try setprop debug.hwui.skip_empty_damage true
    try setprop debug.hwui.use_buffer_age true
    try setprop debug.hwui.use_partial_updates true
    try setprop debug.hwui.use_gpu_pixel_buffers true
    try setprop debug.hwui.render_dirty_regions 0
    try setprop debug.vulkan.enabled 1
    try setprop debug.egl.hw 1
    try setprop persist.sys.perf_turbo_type 19
}

apply_roblox_game() {
    SCALE="$1"
    FPS="$2"
    try cmd game set --downscale "$SCALE" --fps "$FPS" "$GAME"
    try cmd game mode custom "$GAME"
}

apply_roblox_priority() {
    for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK; do
        try appops set --user 0 "$GAME" "$OP" allow
    done
    try am set-inactive "$GAME" false
    try am set-standby-bucket "$GAME" active
    if ! is_whitelisted "$GAME"; then
        try cmd deviceidle whitelist +"$GAME"
    fi
}

apply_safe_hog_cleanup() {
    log "Safe hog cleanup: Discord, pedometer, ChatGPT, GMS, Play Store untouched"
    for P in $HOGS_USER0; do
        pkg_exists_user 0 "$P" || continue
        try appops set --user 0 "$P" RUN_IN_BACKGROUND deny
        try appops set --user 0 "$P" RUN_ANY_IN_BACKGROUND deny
        try appops set --user 0 "$P" WAKE_LOCK deny
        case "$P" in
            com.miui.analytics) ;;
            *) try am force-stop "$P" ;;
        esac
    done
}

compact_roblox() {
    PID="$(pidof "$GAME" 2>/dev/null | awk '{print $1}')"
    [ -n "$PID" ] || return 0
    log "Compacting Roblox pid=$PID"
    try am compact "$PID"
}

apply_full_profile() {
    log "Applying FULL profile: scale=$DOWN_FULL fps=$FPS_FULL events=$EVENTS_FULL grip=$GRIP_DEFAULT"
    apply_refresh_120
    apply_touch_common
    apply_events "$EVENTS_FULL"
    apply_grip "$GRIP_DEFAULT"
    apply_sf_low_wait
    apply_hwui_profile
    apply_roblox_game "$DOWN_FULL" "$FPS_FULL"
    apply_roblox_priority
    apply_safe_hog_cleanup
    compact_roblox
}

apply_saver_profile() {
    log "Applying SAVER profile: scale=$DOWN_FULL fps=$FPS_SAVER events=$EVENTS_SAVER"
    apply_touch_common
    apply_events "$EVENTS_SAVER"
    apply_grip "$GRIP_DEFAULT"
    apply_roblox_game "$DOWN_FULL" "$FPS_SAVER"
    apply_roblox_priority
}

apply_profile_for_power() {
    LP="$(settings get global low_power 2>/dev/null)"
    if [ "$LP" = "1" ]; then
        apply_saver_profile
    else
        apply_full_profile
    fi
}

daemon_running() {
    [ -f "$PIDFILE" ] || return 1
    PID="$(cat "$PIDFILE" 2>/dev/null)"
    [ -n "$PID" ] || return 1
    kill -0 "$PID" 2>/dev/null
}

daemon_loop() {
    echo $$ > "$PIDFILE"
    trap 'rm -f "$PIDFILE"; exit 0' INT TERM EXIT
    LAST=""
    log "v9.2 daemon started"

    while true; do
        LP="$(settings get global low_power 2>/dev/null)"
        [ -z "$LP" ] && LP="0"

        if [ "$LP" = "1" ]; then
            apply_touch_common
            apply_events "$EVENTS_SAVER"
            apply_grip "$GRIP_DEFAULT"
        else
            apply_touch_common
            apply_events "$EVENTS_FULL"
            apply_grip "$GRIP_DEFAULT"
        fi
        LAST="$LP"

        sleep 15
    done
}

start_daemon() {
    if daemon_running; then
        log "Daemon already running pid=$(cat "$PIDFILE" 2>/dev/null)"
        return 0
    fi

    sh "$BASE/$SCRIPT_NAME" daemon_loop >/dev/null 2>&1 &
    echo $! > "$PIDFILE"
    log "Daemon launched pid=$(cat "$PIDFILE" 2>/dev/null)"
}

stop_daemon_only() {
    stop_pidfile "$PIDFILE"
    rm -f "$PIDFILE"
}

restore_all() {
    log "Restoring saved baseline"

    restore_game

    for K in $PROPS_SAVE; do
        restore_prop "$K"
    done

    for ITEM in $SETTINGS_SAVE; do
        NS="${ITEM%%:*}"
        KEY="${ITEM#*:}"
        restore_setting "$NS" "$KEY"
    done

    for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK START_FOREGROUND; do
        restore_appop 0 "$GAME" "$OP"
    done

    BUCKET="$(state_get "standby:$GAME")"
    if [ -n "$BUCKET" ] && [ "$BUCKET" != "$RB_EMPTY" ]; then
        try am set-standby-bucket "$GAME" "$BUCKET"
    fi

    ADDED="$(state_get "deviceidle_added:$GAME")"
    if [ "$ADDED" = "1" ]; then
        try cmd deviceidle whitelist -"$GAME"
    fi

    for P in $HOGS_USER0; do
        for OP in RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND WAKE_LOCK; do
            restore_appop 0 "$P" "$OP"
        done
    done
}

engage() {
    rotate_log
    stop_legacy_pidfiles

    if [ ! -f "$STATE" ]; then
        log "Saving baseline state"
        save_all_once
    else
        log "Existing state found; using saved baseline. Use --fresh if stale."
    fi

    apply_profile_for_power
    start_daemon
    verify
}

fresh_reset() {
    log "Fresh reset: stopping daemon and clearing stale v9.2 runtime/state files"
    stop_daemon_only
    stop_legacy_pidfiles
    rm -f "$STATE"
    rm -f "$STATE.tmp"
    rm -f "$PIDFILE"
    engage
}

stop_all() {
    stop_daemon_only
    if [ -f "$STATE" ]; then
        restore_all
        rm -f "$STATE"
    else
        log "No v9.2 state file found; nothing to restore"
    fi
    verify
}

ensure_state_for_mode() {
    [ -f "$STATE" ] || save_all_once
}

mode_events() {
    ensure_state_for_mode
    apply_touch_common
    apply_events "$1"
    apply_grip "$GRIP_DEFAULT"
    apply_roblox_priority
    verify
}

mode_scale() {
    ensure_state_for_mode
    SCALE="$1"
    apply_roblox_game "$SCALE" "$FPS_FULL"
    compact_roblox
    verify
}

mode_grip() {
    ensure_state_for_mode
    apply_grip "$1"
    verify
}

mode_diag() {
    verify
}

mode_gfx() {
    PID="$(pidof "$GAME" 2>/dev/null | awk '{print $1}')"
    if [ -n "$PID" ]; then
        dumpsys gfxinfo "$GAME" 2>/dev/null | grep -E 'Total frames rendered|Janky frames|90th percentile|95th percentile|99th percentile|Number High input latency|Number Missed Vsync' | head -40
    else
        echo "Roblox not running; gfxinfo skipped."
    fi
}

mode_thermal() {
    dumpsys thermalservice 2>/dev/null | head -120
}

mode_probe() {
    if [ -f "$BASE/scripts/rb_capability_probe_v1.sh" ]; then
        sh "$BASE/scripts/rb_capability_probe_v1.sh"
    elif [ -f "./scripts/rb_capability_probe_v1.sh" ]; then
        sh "./scripts/rb_capability_probe_v1.sh"
    else
        echo "probe script not found: scripts/rb_capability_probe_v1.sh"
    fi
}

verify() {
    echo "=== Redmi Roblox v9.2 Adaptive VERIFY ==="
    echo "script=$BASE/$SCRIPT_NAME"
    echo "state=$STATE"
    echo "pidfile=$PIDFILE"
    echo ""
    echo "## ID"
    id 2>&1
    echo ""
    echo "## POWER"
    echo "low_power=$(settings get global low_power 2>/dev/null)"
    echo "low_power_sticky=$(settings get global low_power_sticky 2>/dev/null)"
    echo ""
    echo "## GAME"
    cmd game list-modes "$GAME" 2>&1
    dumpsys game 2>/dev/null | grep -A6 -i "$GAME"
    echo ""
    echo "## SURFACEFLINGER"
    dumpsys SurfaceFlinger 2>/dev/null | grep -A3 -B3 -E 'GameFrameRateOverrides|10490|renderRate=|activeMode=' | head -100
    echo ""
    echo "## INPUT"
    echo "max_events=$(getprop debug.inputdispatcher.max_events_per_sec 2>/dev/null)"
    echo "resampling=$(getprop debug.input.resampling 2>/dev/null)"
    echo "touch_prediction=$(getprop debug.input.touch_prediction 2>/dev/null)"
    echo "velocitytracker=$(getprop debug.velocitytracker.strategy 2>/dev/null)"
    echo "grip_debug=$(getprop debug.tp.grip_enable 2>/dev/null)"
    echo ""
    echo "## PRIORITY"
    cmd deviceidle whitelist 2>/dev/null | grep -i "$GAME" || echo "deviceidle=no_roblox_entry"
    echo "standby_bucket=$(am get-standby-bucket "$GAME" 2>/dev/null)"
    appops get "$GAME" RUN_IN_BACKGROUND 2>&1
    appops get "$GAME" RUN_ANY_IN_BACKGROUND 2>&1
    appops get "$GAME" WAKE_LOCK 2>&1
    echo ""
    echo "## SAFETY"
    echo "background_process_limit=$(settings get global background_process_limit 2>/dev/null)"
    echo "untouched=Discord,pedometer,ChatGPT,GMS,PlayStore"
    echo ""
    echo "## GFXINFO"
    PID="$(pidof "$GAME" 2>/dev/null | awk '{print $1}')"
    if [ -n "$PID" ]; then
        dumpsys gfxinfo "$GAME" 2>/dev/null | grep -E 'Total frames rendered|Janky frames|90th percentile|95th percentile|99th percentile|Number High input latency|Number Missed Vsync' | head -40
    else
        echo "Roblox not running; gfxinfo skipped."
    fi
}

case "${1:-engage}" in
    engage|start|on)
        engage
        ;;
    --fresh|fresh)
        fresh_reset
        ;;
    daemon_loop)
        daemon_loop
        ;;
    stop|off|restore)
        stop_all
        ;;
    verify|status)
        verify
        ;;
    full)
        ensure_state_for_mode
        apply_full_profile
        verify
        ;;
    saver)
        ensure_state_for_mode
        apply_saver_profile
        verify
        ;;
    events480)
        mode_events 480
        ;;
    events1600)
        mode_events 1600
        ;;
    events9999)
        mode_events 9999
        ;;
    events1200)
        mode_events 1200
        ;;
    scale025)
        mode_scale 0.25
        ;;
    scale035)
        mode_scale 0.35
        ;;
    grip0)
        mode_grip 0
        ;;
    grip90)
        mode_grip 90
        ;;
    grip120)
        mode_grip 120
        ;;
    grip150)
        mode_grip 150
        ;;
    probe)
        mode_probe
        ;;
    diag)
        mode_diag
        ;;
    gfx)
        mode_gfx
        ;;
    thermal)
        mode_thermal
        ;;
    priority)
        ensure_state_for_mode
        apply_roblox_game "$DOWN_FULL" "$FPS_FULL"
        apply_roblox_priority
        verify
        ;;
    killdaemon)
        stop_daemon_only
        echo "daemon stopped"
        ;;
    *)
        echo "Usage:"
        echo "  sh $0 --fresh     # clear stale v9.2 state, save new baseline, engage"
        echo "  sh $0 engage      # normal full/adaptive engage"
        echo "  sh $0 stop        # stop daemon and restore saved baseline"
        echo "  sh $0 verify"
        echo "  sh $0 full|saver"
        echo "  sh $0 events480|events1200|events1600|events9999"
        echo "  sh $0 scale025|scale035"
        echo "  sh $0 grip0|grip90|grip120|grip150"
        echo "  sh $0 probe|diag|gfx|thermal|priority"
        ;;
esac

exit 0
