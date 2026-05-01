#!/system/bin/sh
# Readback-only capability probe for Roblox optimizer candidates (UID 2000-safe)
BASE="/storage/emulated/0/Download"
LOG="$BASE/rb_capability_probe_v1.log"
GAME="com.roblox.client"

pass(){ echo "PASS: $1" | tee -a "$LOG"; }
fail(){ echo "FAIL: $1" | tee -a "$LOG"; }
unk(){ echo "UNKNOWN: $1" | tee -a "$LOG"; }
run(){ "$@" >> "$LOG" 2>&1; }

mkdir -p "$BASE" 2>/dev/null
: > "$LOG"
echo "=== rb_capability_probe_v1 ===" | tee -a "$LOG"
id | tee -a "$LOG"

# cmd game help: do not hard-fail when binder transaction fails
GH="$(cmd game help 2>&1)"
printf "%s\n" "$GH" >> "$LOG"
if printf "%s" "$GH" | grep -qi "Failed transaction"; then
  unk "cmd game help (Failed transaction)"
elif [ -n "$GH" ]; then
  pass "cmd game help"
else
  unk "cmd game help (no output)"
fi

# GameManager multi-readback verdict
LM_OUT="$(cmd game list-modes "$GAME" 2>&1)"
DG_OUT="$(dumpsys game 2>/dev/null | grep -A6 -i "$GAME")"
SF_OUT="$(dumpsys SurfaceFlinger 2>/dev/null | grep -E 'GameFrameRateOverrides|renderRate=|activeMode=' | head -40)"

printf "%s\n" "$LM_OUT" >> "$LOG"
printf "%s\n" "$DG_OUT" >> "$LOG"
printf "%s\n" "$SF_OUT" >> "$LOG"

LM_OK=0
DG_OK=0
SF_OK=0
printf "%s" "$LM_OUT" | grep -qi "$GAME" && LM_OK=1
[ -n "$DG_OUT" ] && DG_OK=1
[ -n "$SF_OUT" ] && SF_OK=1

if [ "$LM_OK" -eq 1 ] || [ "$DG_OK" -eq 1 ]; then
  pass "GameManager readbacks (list-modes/dumpsys game)"
elif [ "$SF_OK" -eq 1 ]; then
  unk "GameManager readbacks (only SurfaceFlinger markers)"
else
  fail "GameManager readbacks (all failed)"
fi

for K in min_refresh_rate peak_refresh_rate user_refresh_rate miui_refresh_rate; do
  V="$(settings get system "$K" 2>/dev/null)"
  [ -n "$V" ] && [ "$V" != "null" ] && pass "settings get system $K=$V" || unk "settings get system $K"
done

for K in low_power low_power_sticky; do
  V="$(settings get global "$K" 2>/dev/null)"
  [ -n "$V" ] && [ "$V" != "null" ] && pass "settings get global $K=$V" || unk "settings get global $K"
done

for P in debug.inputdispatcher.max_events_per_sec debug.input.resampling debug.input.touch_prediction debug.velocitytracker.strategy debug.tp.grip_enable; do
  O="$(getprop "$P" 2>/dev/null)"
  [ -z "$O" ] && O=""
  case "$P" in
    debug.inputdispatcher.max_events_per_sec) T="1600" ;;
    debug.input.resampling) T="false" ;;
    debug.input.touch_prediction) T="false" ;;
    debug.velocitytracker.strategy) T="impulse" ;;
    debug.tp.grip_enable) T="0" ;;
  esac
  setprop "$P" "$T" 2>/dev/null
  N="$(getprop "$P" 2>/dev/null)"
  if [ "$N" = "$T" ]; then
    pass "setprop/getprop $P=$T"
  else
    unk "setprop/getprop $P (wanted=$T got=${N:-empty})"
  fi
  setprop "$P" "$O" 2>/dev/null
done

if cmd package resolve-activity --brief "$GAME" >/dev/null 2>&1; then
  PID="$(pidof "$GAME" 2>/dev/null | awk '{print $1}')"
  if [ -n "$PID" ]; then
    run am compact "$PID" && pass "am compact $PID" || unk "am compact $PID"
  else
    unk "am compact (Roblox not running)"
  fi
else
  unk "package resolve-activity $GAME"
fi

echo "Probe complete. Log: $LOG" | tee -a "$LOG"
