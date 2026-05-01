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

GAME_OK=0

GAME_HELP_OUT="$(cmd game help 2>&1)"
echo "$GAME_HELP_OUT" >> "$LOG"
if echo "$GAME_HELP_OUT" | grep -qi "Failed transaction"; then
  unk "cmd game help (Failed transaction)"
elif [ -n "$GAME_HELP_OUT" ]; then
  pass "cmd game help"
else
  unk "cmd game help (empty output)"
fi

LIST_OUT="$(cmd game list-modes "$GAME" 2>&1)"
echo "$LIST_OUT" >> "$LOG"
if echo "$LIST_OUT" | grep -qi "$GAME"; then
  pass "cmd game list-modes $GAME"
  GAME_OK=1
elif echo "$LIST_OUT" | grep -qi "Failed transaction"; then
  unk "cmd game list-modes $GAME (Failed transaction)"
else
  unk "cmd game list-modes $GAME"
fi

GAME_DUMP="$(dumpsys game 2>/dev/null | grep -A6 -i "$GAME")"
echo "$GAME_DUMP" >> "$LOG"
if [ -n "$GAME_DUMP" ]; then
  pass "dumpsys game readback for $GAME"
  GAME_OK=1
else
  unk "dumpsys game readback for $GAME"
fi

SF_GAME="$(dumpsys SurfaceFlinger 2>/dev/null | grep -E 'GameFrameRateOverrides|10490|renderRate=|activeMode=' | head -50)"
echo "$SF_GAME" >> "$LOG"
if [ -n "$SF_GAME" ]; then
  pass "SurfaceFlinger game markers"
else
  unk "SurfaceFlinger game markers"
fi

if [ "$GAME_OK" -eq 1 ]; then
  pass "game manager capability (at least one Roblox readback succeeded)"
elif [ -n "$SF_GAME" ]; then
  unk "game manager capability (no list-modes/dumpsys game hit, but SurfaceFlinger has markers)"
else
  fail "game manager capability (all game readbacks failed)"
fi

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
