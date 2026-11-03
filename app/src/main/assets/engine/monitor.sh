#!/system/bin/sh
# monitor.sh start|stop|status|last|list|get|del
MODDIR=${0%/*}
SYS=${SYSROOT:-/sys}
DIR=${GM_DIR:-/data/local/tmp/modulehub_gb_sessions}
PIDF=$DIR/rec.pid
CUR=$DIR/current
TMP=$DIR/lat.tmp
GBSTATE=${GB_STATE:-/data/local/tmp/modulehub_gb_state}
mkdir -p "$DIR" 2>/dev/null
. $MODDIR/common.sh
KG=$SYS/class/kgsl/kgsl-3d0

okname() { case "$1" in ''|*[!A-Za-z0-9_.-]*) return 1 ;; esac; return 0; }
running() { [ -f "$PIDF" ] && read p < "$PIDF" && [ -n "$p" ] && kill -0 "$p" 2>/dev/null; }

gpu_mhz() {
  if [ -r $KG/devfreq/cur_freq ]; then read v < $KG/devfreq/cur_freq; echo $((v/1000000)); return; fi
  for d in $SYS/class/devfreq/*; do
    case "$(lc "${d##*/}")" in *gpu*|*mali*) [ -r "$d/cur_freq" ] && { read v < "$d/cur_freq"; echo $((v/1000000)); return; } ;; esac
  done
  echo -1
}
gpu_busy() {
  if [ -r $KG/gpubusy ]; then read a b < $KG/gpubusy; if [ "${b:-0}" -gt 0 ] 2>/dev/null; then echo $((a*100/b)); else echo 0; fi; else echo -1; fi
}
cpu_mhz() { # first|last
  sel=""
  for p in $SYS/devices/system/cpu/cpufreq/policy*; do [ -d "$p" ] || continue; [ "$1" = first ] && { sel=$p; break; }; sel=$p; done
  if [ -n "$sel" ] && [ -r "$sel/scaling_cur_freq" ]; then read v < "$sel/scaling_cur_freq"; echo $((v/1000)); else echo -1; fi
}
bat_t() {
  for f in $SYS/class/power_supply/battery/temp $SYS/class/power_supply/Battery/temp; do
    if [ -f "$f" ]; then read t < "$f"; case "$t" in ''|*[!0-9]*) ;; *) [ "$t" -gt 150 ] && t=$((t/10)); echo "$t"; return ;; esac; fi
  done; echo -1
}
soc_t() {
  m=""
  for z in $SYS/class/thermal/thermal_zone*; do
    [ -f "$z/type" ] || continue; read ty < "$z/type"
    case "$(lc "$ty")" in *cpu*|*tsens*|*soc*|*cluster*|*gpu*|*apc*|*mtk*) ;; *) continue ;; esac
    read v < "$z/temp" 2>/dev/null || continue
    case "$v" in ''|*[!0-9]*) continue ;; esac
    [ "$v" -gt 1000 ] && v=$((v/1000))
    if [ "$v" -gt 0 ] && [ "$v" -lt 150 ]; then if [ -z "$m" ] || [ "$v" -gt "$m" ]; then m=$v; fi; fi
  done
  echo "${m:--1}"
}

fg_pkg() {
  l="$(dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')"
  p="$(echo "$l" | sed -n 's/.*Window{[^ ]* u[0-9]* \([^/ }]*\).*/\1/p')"
  if [ -z "$p" ]; then
    l="$(dumpsys activity activities 2>/dev/null | grep -m1 'ResumedActivity')"
    p="$(echo "$l" | sed -n 's/.* u[0-9]* \([^/ ]*\)\/.*/\1/p')"
  fi
  echo "$p"
}
pick_layer() {
  [ -n "$1" ] || return
  L="$(dumpsys SurfaceFlinger --list 2>/dev/null | grep -F "$1" | grep -v -E 'Background for|Bounds for|Splash')"
  sv="$(echo "$L" | grep '^SurfaceView' | head -1)"
  if [ -n "$sv" ]; then echo "$sv"; else echo "$L" | head -1; fi
}

# fps_sample LAYER WINDOW_SECS -> FPS10 (fps x10), MAXFT (ms)
PREV_T=0
fps_sample() {
  FPS10=0; MAXFT=0
  dumpsys SurfaceFlinger --latency "$1" > "$TMP" 2>/dev/null || return
  [ -s "$TMP" ] || return
  win=$(( $2 * 1000000000 )); tmax=0
  while read a b c; do
    [ -n "$c" ] || continue
    [ "$b" = "9223372036854775807" ] && continue
    [ "$b" -gt 0 ] 2>/dev/null || continue
    [ "$b" -gt "$tmax" ] && tmax=$b
  done < "$TMP"
  [ "$tmax" -gt 0 ] || return
  if [ "$tmax" = "$PREV_T" ]; then return; fi   # tidak ada frame baru
  PREV_T=$tmax
  lo=$((tmax - win)); cnt=0; first=0; prev=0; md=0
  while read a b c; do
    [ -n "$c" ] || continue
    [ "$b" = "9223372036854775807" ] && continue
    [ "$b" -gt 0 ] 2>/dev/null || continue
    [ "$b" -ge "$lo" ] || continue
    cnt=$((cnt+1)); [ "$first" = 0 ] && first=$b
    if [ "$prev" -gt 0 ]; then d=$((b - prev)); [ "$d" -gt "$md" ] && md=$d; fi
    prev=$b
  done < "$TMP"
  if [ "$cnt" -ge 2 ] && [ "$tmax" -gt "$first" ]; then
    FPS10=$(( (cnt - 1) * 10000000000 / (tmax - first) )); MAXFT=$((md / 1000000))
  fi
}

run() {
  f="$1"; interval="$2"; maxs=$(( $3 * 60 ))
  echo "$f" > "$CUR"
  t0=$(date +%s); i=0; pkg=""; layer=""; zero=0
  while [ ! -f "$DIR/stop" ]; do
    now=$(date +%s); el=$((now - t0))
    [ "$el" -ge "$maxs" ] && break
    if [ $((i % 3)) = 0 ] || [ "$zero" -ge 3 ]; then
      np="$(fg_pkg)"
      if [ "$np" != "$pkg" ] || [ "$zero" -ge 3 ]; then pkg="$np"; layer="$(pick_layer "$pkg")"; zero=0; PREV_T=0; fi
    fi
    FPS10=0; MAXFT=0
    [ -n "$layer" ] && fps_sample "$layer" "$interval"
    if [ "$FPS10" -le 0 ]; then zero=$((zero+1)); else zero=0; fi
    ba=0; bc=-1; [ -f "$GBSTATE" ] && IFS="|" read ba bp bc bm < "$GBSTATE"
    [ "$ba" = "1" ] || bc=-1
    echo "$el,$pkg,$FPS10,$MAXFT,$(gpu_mhz),$(gpu_busy),$(cpu_mhz first),$(cpu_mhz last),$(soc_t),$(bat_t),${ba:-0},${bc:--1}" >> "$f"
    i=$((i+1)); sleep "$interval"
  done
  echo "#end=$(date +%s)" >> "$f"
  rm -f "$PIDF" "$CUR" "$DIR/stop" "$TMP"
}

case "$1" in
  run) run "$2" "$3" "$4" ;;
  start)
    label="$2"; interval="${3:-2}"; maxmin="${4:-30}"
    okname "$label" || { echo "ERR|nama sesi tidak valid"; exit 1; }
    case "$interval" in 1|2|3|4|5) ;; *) interval=2 ;; esac
    case "$maxmin" in ''|*[!0-9]*) maxmin=30 ;; esac
    [ "$maxmin" -ge 1 ] && [ "$maxmin" -le 120 ] || maxmin=30
    running && { echo "ERR|sudah merekam"; exit 1; }
    rm -f "$DIR/stop"
    f="$DIR/$(date +%Y%m%d-%H%M%S)_${label}.csv"
    {
      echo "#label=$label"; echo "#start=$(date +%s)"; echo "#interval=$interval"
      echo "#device=$(getprop ro.product.model)"; echo "#kernel=$(uname -r)"
      echo "#cols=t,pkg,fps10,maxft_ms,gpu_mhz,gpu_busy,cpu_l_mhz,cpu_b_mhz,soc_c,bat_c,boost,cap_mhz"
    } > "$f"
    if command -v setsid >/dev/null 2>&1; then setsid sh "$0" run "$f" "$interval" "$maxmin" >/dev/null 2>&1 </dev/null &
    else nohup sh "$0" run "$f" "$interval" "$maxmin" >/dev/null 2>&1 </dev/null &
    fi
    echo $! > "$PIDF"
    echo "OK|${f##*/}" ;;
  stop)
    if running; then
      touch "$DIR/stop"; read p < "$PIDF"; k=0
      while kill -0 "$p" 2>/dev/null && [ "$k" -lt 12 ]; do sleep 1; k=$((k+1)); done
      kill -0 "$p" 2>/dev/null && kill "$p" 2>/dev/null
      rm -f "$DIR/stop" "$PIDF" "$CUR"
      echo "OK|dihentikan"
    else rm -f "$PIDF" "$CUR" "$DIR/stop"; echo "OK|tidak sedang merekam"; fi ;;
  status)
    if running; then
      f=""; [ -f "$CUR" ] && read f < "$CUR"
      st=0; [ -n "$f" ] && st="$(sed -n 's/^#start=//p' "$f" | head -1)"
      echo "REC|1|${f##*/}|$(( $(date +%s) - ${st:-0} ))"
    else echo "REC|0"; fi ;;
  last) f=""; [ -f "$CUR" ] && read f < "$CUR"; [ -n "$f" ] && grep -v '^#' "$f" | tail -1 ;;
  list)
    for f in $(ls -1t $DIR/*.csv 2>/dev/null); do
      n="${f##*/}"; lb="${n#*_}"; lb="${lb%.csv}"
      st="$(sed -n 's/^#start=//p' "$f" | head -1)"
      rows="$(grep -vc '^#' "$f")"
      dur="$(grep -v '^#' "$f" | tail -1 | cut -d, -f1)"
      echo "S|$n|$lb|${st:-0}|$rows|${dur:-0}"
    done ;;
  get) okname "${2%.csv}" || exit 1; [ -f "$DIR/$2" ] && cat "$DIR/$2" ;;
  del) okname "${2%.csv}" || exit 1; rm -f "$DIR/$2"; echo "OK|dihapus" ;;
  *) echo "pakai: monitor.sh start|stop|status|last|list|get|del" ;;
esac
