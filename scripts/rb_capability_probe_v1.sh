#!/system/bin/sh
BASE="/storage/emulated/0/Download"
GAME="com.roblox.client"
LOG="$BASE/rb_capability_probe_v1.log"

pass(){ echo "PASS: $1" | tee -a "$LOG"; }
fail(){ echo "FAIL: $1" | tee -a "$LOG"; }
unk(){ echo "UNKNOWN: $1" | tee -a "$LOG"; }

run(){ "$@" >>"$LOG" 2>&1; return $?; }

echo "=== rb_capability_probe_v1 ===" > "$LOG"
id >> "$LOG" 2>&1

run cmd game help && pass "cmd game help" || fail "cmd game help"
run cmd game list-modes "$GAME" && pass "cmd game list-modes" || fail "cmd game list-modes"

for K in min_refresh_rate peak_refresh_rate user_refresh_rate; do
  V="$(settings get system "$K" 2>/dev/null)"
  [ -n "$V" ] && pass "settings get system $K => $V" || unk "settings get system $K"
done

if dumpsys SurfaceFlinger 2>/dev/null | grep -Eq 'activeMode=|GameFrameRateOverrides'; then
  pass "SurfaceFlinger readback markers"
else
  unk "SurfaceFlinger readback markers"
fi

for P in debug.inputdispatcher.max_events_per_sec debug.input.resampling debug.input.touch_prediction debug.velocitytracker.strategy debug.tp.grip_enable; do
  OLD="$(getprop "$P" 2>/dev/null)"
  case "$P" in
    debug.inputdispatcher.max_events_per_sec) T="1600" ;;
    debug.input.resampling) T="false" ;;
    debug.input.touch_prediction) T="false" ;;
    debug.velocitytracker.strategy) T="impulse" ;;
    debug.tp.grip_enable) T="90" ;;
  esac
  run setprop "$P" "$T"
  NEW="$(getprop "$P" 2>/dev/null)"
  [ "$NEW" = "$T" ] && pass "setprop/getprop $P" || unk "setprop/getprop $P (readback=$NEW)"
  run setprop "$P" "$OLD"
done

PID="$(pidof "$GAME" 2>/dev/null | awk '{print $1}')"
if [ -n "$PID" ]; then
  run am compact "$PID" && pass "am compact $PID" || fail "am compact $PID"
else
  unk "am compact (Roblox not running)"
fi

run am help && pass "am help" || unk "am help"
echo "Log: $LOG"
