#!/system/bin/sh
# gamed.sh daemon|stop|status|revert
MODDIR=${0%/*}
SYS=${SYSROOT:-/sys}; PROC=${PROCROOT:-/proc}; CPUSET=${CPUSETROOT:-/dev/cpuset}
DATA=${GB_DATA:-/data/local/tmp}
CONF=${GB_CONF:-/data/adb/modulehub_game_boost.conf}
LOG=$DATA/modulehub_game_boost.log
ORIG=$DATA/modulehub_gb_orig
STATE=$DATA/modulehub_gb_state
PIDF=$DATA/modulehub_gb_daemon.pid
AUTORES=$DATA/modulehub_gb_autores
SETORIG=$DATA/modulehub_gb_setorig
KG=$SYS/class/kgsl/kgsl-3d0
PACE_EVERY=${PACE_EVERY:-2}
. $MODDIR/common.sh

load_conf() {
  MASTER=1; GAMES=""; POLL_SECS=3; PACE=1; PACE_TARGET_C=62; PACE_MIN_PCT=60
  GPU_FLOOR_PCT=0; GPU_ADRENOBOOST=default; SCHED_RATE_US=default
  GAME_SWAPPINESS=default; KILL_BG=0; GAME_RES_PCT=100; GAME_FOCUS=0; GAME_DND=0; GAME_PROFILE=custom; BAT_TEMP_LIMIT_C=45; SOC_TEMP_HARD_C=80
  [ -f "$CONF" ] && . "$CONF"
  case "$POLL_SECS" in 2|3|4|5|6|8|10) ;; *) POLL_SECS=3 ;; esac
}
log() { echo "$(date +%H:%M:%S) $*" >> $LOG; }

wr() {
  if [ ! -w "$2" ]; then log "SKIP $2"; return 1; fi
  grep -q "^$2|" $ORIG 2>/dev/null || echo "$2|$(cat $2)" >> $ORIG
  if echo "$1" > "$2" 2>/dev/null; then log "OK   $2 = $1"; return 0; fi
  log "FAIL $2"; return 1
}
maxof() { m=""; for x in "$@"; do if [ -z "$m" ] || [ "$x" -gt "$m" ]; then m=$x; fi; done; echo "$m"; }
avail_sorted() {
  f="$(cat $1/scaling_available_frequencies 2>/dev/null)"
  if [ -z "$f" ] && [ -f $1/stats/time_in_state ]; then while read a b; do f="$f $a"; done < $1/stats/time_in_state; fi
  for x in $f; do echo "$x"; done | sort -n | tr '\n' ' '
}
next_lower() { cur=$1; shift; r=""; for x in "$@"; do [ "$x" -lt "$cur" ] && r=$x; done; echo "$r"; }
next_higher() { cur=$1; shift; for x in "$@"; do [ "$x" -gt "$cur" ] && { echo "$x"; return; }; done; }

read_bat_temp() {
  for f in $SYS/class/power_supply/battery/temp $SYS/class/power_supply/Battery/temp; do
    if [ -f "$f" ]; then read t < "$f"; case "$t" in ''|*[!0-9]*) ;; *) [ "$t" -gt 150 ] && t=$((t/10)); echo "$t"; return ;; esac; fi
  done
}
read_soc_temp() {
  m=""
  for z in $SYS/class/thermal/thermal_zone*; do
    [ -f "$z/type" ] || continue; read ty < "$z/type"
    case "$(lc "$ty")" in *cpu*|*tsens*|*soc*|*cluster*|*gpu*|*apc*|*mtk*) ;; *) continue ;; esac
    read v < "$z/temp" 2>/dev/null || continue
    case "$v" in ''|*[!0-9]*) continue ;; esac
    [ "$v" -gt 1000 ] && v=$((v/1000))
    if [ "$v" -gt 0 ] && [ "$v" -lt 150 ]; then if [ -z "$m" ] || [ "$v" -gt "$m" ]; then m=$v; fi; fi
  done
  echo "$m"
}

fg_game() {
  [ -n "$GAMES" ] || return
  if [ -r "$CPUSET/top-app/cgroup.procs" ]; then
    for pid in $(cat $CPUSET/top-app/cgroup.procs); do
      [ -r "$PROC/$pid/cmdline" ] || continue
      cmd=""; read -r cmd < "$PROC/$pid/cmdline"
      [ -n "$cmd" ] || continue
      for g in $GAMES; do [ "$cmd" = "$g" ] && { echo "$g"; return; }; done
    done
  else
    l="$(dumpsys window 2>/dev/null | grep -m1 'mCurrentFocus')"
    p="$(echo "$l" | sed -n 's/.*Window{[^ ]* u[0-9]* \([^/ }]*\).*/\1/p')"
    for g in $GAMES; do [ "$p" = "$g" ] && { echo "$g"; return; }; done
  fi
}

sput() { # sput namespace key nilai  (menyimpan nilai asli sekali)
  grep -q "^$1|$2|" $SETORIG 2>/dev/null || echo "$1|$2|$(settings get $1 $2 2>/dev/null)" >> $SETORIG
  if settings put $1 $2 $3 >/dev/null 2>&1; then log "OK   settings $1 $2 = $3"; else log "FAIL settings $1 $2"; fi
}
srestore() {
  [ -s "$SETORIG" ] || return
  while IFS='|' read ns k v; do
    if [ -z "$v" ] || [ "$v" = "null" ]; then settings delete $ns $k >/dev/null 2>&1; else settings put $ns $k "$v" >/dev/null 2>&1; fi
  done < "$SETORIG"
  : > "$SETORIG"; log "revert: pengaturan sistem dikembalikan"
}

# profil: per game (GP_<PAKET>) menang atas profil global (GAME_PROFILE); "custom" memakai nilai tab Boost
apply_profile() {
  key="$(echo "$1" | tr 'a-z.' 'A-Z_' | tr -cd 'A-Z0-9_')"
  gp=""; eval "gp=\$GP_$key"
  [ -n "$gp" ] && [ "$gp" != "default" ] || gp="$GAME_PROFILE"
  case "$gp" in
    saver)       PACE=1; PACE_TARGET_C=55; PACE_MIN_PCT=50; GPU_FLOOR_PCT=0; GPU_ADRENOBOOST=default; SCHED_RATE_US=default; KILL_BG=0 ;;
    balanced)    PACE=1; PACE_TARGET_C=62; PACE_MIN_PCT=60; GPU_FLOOR_PCT=0; GPU_ADRENOBOOST=default; SCHED_RATE_US=default ;;
    performance) PACE=1; PACE_TARGET_C=66; PACE_MIN_PCT=70; GPU_FLOOR_PCT=30; GPU_ADRENOBOOST=1; SCHED_RATE_US=2000; GAME_SWAPPINESS=40 ;;
    *) gp=custom ;;
  esac
  log "profil: ${gp}"
}

set_state() { echo "$active|$gpkg|$((${CAP:-0}/1000))|$1" > $STATE; }

find_big() {
  BIGP=""; mx=0
  for p in $SYS/devices/system/cpu/cpufreq/policy*; do
    [ -r "$p/cpuinfo_max_freq" ] || continue; read h < "$p/cpuinfo_max_freq"
    if [ "$h" -gt "$mx" ]; then mx=$h; BIGP=$p; fi
  done
}

enter_game() {
  load_conf; apply_profile "$1"
  gpkg="$1"; : > $ORIG; log "=== GAME $gpkg ==="
  find_big; BIGFREQS="$(avail_sorted $BIGP)"; TOP="$(maxof $BIGFREQS)"; CAP="${TOP:-0}"
  FLOOR="$(pick_ge $(( ${TOP:-0} * PACE_MIN_PCT / 100 )) $BIGFREQS)"; [ -n "$FLOOR" ] || FLOOR=$CAP
  # GPU
  dv=$KG/devfreq
  if [ "$GPU_FLOOR_PCT" -gt 0 ] 2>/dev/null && [ -f "$dv/available_frequencies" ]; then
    gf="$(cat $dv/available_frequencies)"; gmax="$(maxof $gf)"; gcap="$(cat $dv/max_freq 2>/dev/null)"
    v="$(pick_ge $((gmax * GPU_FLOOR_PCT / 100)) $gf)"
    [ -n "$v" ] && [ "$v" -le "${gcap:-$gmax}" ] && wr "$v" $dv/min_freq
  fi
  case "$GPU_ADRENOBOOST" in 0|1|2|3) for n in $KG/adrenoboost $dv/adrenoboost; do [ -w "$n" ] && { wr "$GPU_ADRENOBOOST" $n; break; }; done ;; esac
  # respons CPU
  case "$SCHED_RATE_US" in ''|default) ;; *[!0-9]*) ;; *)
    if [ "$SCHED_RATE_US" -ge 500 ] && [ "$SCHED_RATE_US" -le 20000 ]; then
      for p in $SYS/devices/system/cpu/cpufreq/policy*; do
        for n in up_rate_limit_us rate_limit_us; do [ -w "$p/schedutil/$n" ] && { wr "$SCHED_RATE_US" "$p/schedutil/$n"; break; }; done
      done
    fi ;;
  esac
  # memori
  case "$GAME_SWAPPINESS" in ''|default|*[!0-9]*) ;; *) wr "$GAME_SWAPPINESS" $PROC/sys/vm/swappiness ;; esac
  [ "$GAME_FOCUS" = "1" ] && sput global heads_up_notifications_enabled 0
  [ "$GAME_DND" = "1" ] && sput global zen_mode 1
  if [ "$KILL_BG" = "1" ]; then am kill-all >/dev/null 2>&1 && log "app latar dibersihkan"; fi
  case "$GAME_RES_PCT" in ''|100|*[!0-9]*) ;; *)
    if [ "$GAME_RES_PCT" -ge 60 ] && [ "$GAME_RES_PCT" -lt 100 ]; then
      sh $MODDIR/display.sh set "$GAME_RES_PCT" >/dev/null 2>&1 && { touch "$AUTORES"; log "resolusi diturunkan ke ${GAME_RES_PCT}%"; }
    fi ;;
  esac
  active=1; set_state 1
}

revert_all() {
  srestore
  if [ -f "$AUTORES" ]; then sh $MODDIR/display.sh reset >/dev/null 2>&1; rm -f "$AUTORES"; log "revert: resolusi dikembalikan"; fi
  if [ -s "$ORIG" ]; then
    while IFS='|' read p v; do case "$p" in *min_freq) echo "$v" > "$p" 2>/dev/null ;; esac; done < "$ORIG"
    while IFS='|' read p v; do case "$p" in *min_freq) ;; *) echo "$v" > "$p" 2>/dev/null ;; esac; done < "$ORIG"
    : > "$ORIG"; log "revert: semua nilai dikembalikan"
  fi
}
exit_game() { revert_all; active=0; log "=== game ditutup ==="; CAP=0; gpkg=""; set_state 0; }

tick() {
  bt="$(read_bat_temp)"; st="$(read_soc_temp)"
  if { [ -n "$bt" ] && [ "$bt" -ge "$BAT_TEMP_LIMIT_C" ]; } || { [ -n "$st" ] && [ "$st" -ge "$SOC_TEMP_HARD_C" ]; }; then
    log "PROTEKSI: bat=${bt}C soc=${st}C melewati batas, profil dibatalkan sampai dingin"
    revert_all; active=0; cool=1; set_state 2; return
  fi
  [ "$PACE" = "1" ] && [ -n "$BIGP" ] && [ -n "$st" ] || return
  tickn=$((tickn+1)); [ $((tickn % PACE_EVERY)) -eq 0 ] || return
  if [ "$st" -ge "$PACE_TARGET_C" ]; then
    n="$(next_lower $CAP $BIGFREQS)"
    if [ -n "$n" ] && [ "$n" -ge "$FLOOR" ]; then
      smin="$(cat $BIGP/scaling_min_freq 2>/dev/null)"; [ -n "$smin" ] && [ "$n" -lt "$smin" ] && wr "$n" $BIGP/scaling_min_freq
      CAP=$n; wr "$CAP" $BIGP/scaling_max_freq; log "pacing: SoC ${st}C >= ${PACE_TARGET_C}C -> cap CPU $((CAP/1000)) MHz"; set_state 1
    fi
  elif [ "$st" -le $((PACE_TARGET_C - 4)) ] && [ "$CAP" -lt "${TOP:-0}" ]; then
    n="$(next_higher $CAP $BIGFREQS)"
    if [ -n "$n" ]; then CAP=$n; wr "$CAP" $BIGP/scaling_max_freq; log "pacing: SoC ${st}C -> cap CPU naik $((CAP/1000)) MHz"; set_state 1; fi
  fi
}

daemon() {
  echo $$ > $PIDF
  srestore
  load_conf
  if [ "$MASTER" != "1" ]; then log "MASTER=0, daemon tidak aktif"; rm -f $PIDF; exit 0; fi
  [ -n "$GAMES" ] || log "belum ada game dipilih"
  active=0; gpkg=""; cool=0; leave=0; tickn=0; CAP=0
  log "daemon mulai (game: ${GAMES:-kosong}, poll ${POLL_SECS}s)"; set_state 0
  while :; do
    sleep $POLL_SECS
    [ -f "$MODDIR/disable" ] && { revert_all; rm -f $PIDF; exit 0; }
    g="$(fg_game)"
    if [ -n "$g" ]; then
      leave=0
      if [ "$active" = 0 ] && [ "$cool" = 0 ]; then enter_game "$g"
      elif [ "$active" = 1 ]; then tick
      elif [ "$cool" = 1 ]; then
        bt="$(read_bat_temp)"; st="$(read_soc_temp)"
        if { [ -z "$bt" ] || [ "$bt" -le $((BAT_TEMP_LIMIT_C - 4)) ]; } && { [ -z "$st" ] || [ "$st" -le $((SOC_TEMP_HARD_C - 10)) ]; }; then cool=0; log "suhu turun, profil boleh aktif lagi"; fi
      fi
    else
      cool=0
      if [ "$active" = 1 ]; then leave=$((leave+1)); [ "$leave" -ge 2 ] && exit_game
      else load_conf; [ "$MASTER" = "1" ] || { log "MASTER=0, daemon berhenti"; rm -f $PIDF; exit 0; }; fi
    fi
  done
}

case "$1" in
  daemon) daemon ;;
  stop)
    if [ -f "$PIDF" ]; then read p < "$PIDF"; [ -n "$p" ] && kill "$p" 2>/dev/null; rm -f "$PIDF"; fi
    revert_all; echo "0||0|0" > $STATE; log "daemon dihentikan, nilai dikembalikan" ;;
  revert) revert_all; echo "0||0|0" > $STATE ;;
  status)
    run=0; [ -f "$PIDF" ] && read p < "$PIDF" && kill -0 "$p" 2>/dev/null && run=1
    s="0||0|0"; [ -f "$STATE" ] && read s < "$STATE"
    echo "GB|$run|$s|$(read_bat_temp)|$(read_soc_temp)" ;;
  *) echo "pakai: gamed.sh daemon|stop|status|revert" ;;
esac
