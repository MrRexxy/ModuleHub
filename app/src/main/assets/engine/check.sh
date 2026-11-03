#!/system/bin/sh
MODDIR=${0%/*}
SYS=${SYSROOT:-/sys}; PROC=${PROCROOT:-/proc}; CPUSET=${CPUSETROOT:-/dev/cpuset}
. $MODDIR/common.sh
detect_all >/dev/null 2>&1
KG=$SYS/class/kgsl/kgsl-3d0
c() { echo "CHK|$1|$2|$3"; }
if [ -r $CPUSET/top-app/cgroup.procs ]; then c ok "Deteksi game" "cpuset top-app tersedia (cepat, tanpa dumpsys)"
else c warn "Deteksi game" "cpuset top-app tidak ada, memakai dumpsys (sedikit lebih berat)"; fi
np=0; nw=0; for p in $SYS/devices/system/cpu/cpufreq/policy*; do [ -d "$p" ] || continue; np=$((np+1)); [ -w "$p/scaling_max_freq" ] && nw=$((nw+1)); done
if [ "$nw" -gt 0 ]; then c ok "Pacing CPU" "$nw dari $np cluster bisa diatur"; else c bad "Pacing CPU" "scaling_max_freq tidak bisa ditulis, pacing tidak jalan"; fi
sr=0; for p in $SYS/devices/system/cpu/cpufreq/policy*; do [ -w "$p/schedutil/up_rate_limit_us" ] || [ -w "$p/schedutil/rate_limit_us" ] && sr=$((sr+1)); done
if [ "$sr" -gt 0 ]; then c ok "Respons CPU (schedutil)" "rate limit tersedia di $sr cluster"; else c info "Respons CPU (schedutil)" "tidak tersedia (governor bukan schedutil atau tunable tidak dibuka)"; fi
if [ -f $KG/devfreq/min_freq ]; then c ok "Lantai GPU" "tersedia"; else c info "Lantai GPU" "devfreq GPU tidak ada, opsi dilewati"; fi
if [ -w $KG/adrenoboost ] || [ -w $KG/devfreq/adrenoboost ]; then c ok "Adrenoboost" "tersedia"; else c info "Adrenoboost" "tidak ada di kernel ini"; fi
[ -w $PROC/sys/vm/swappiness ] && c ok "Swappiness" "bisa diatur" || c warn "Swappiness" "tidak bisa ditulis"
command -v wm >/dev/null 2>&1 && c ok "Resolusi (wm)" "tersedia" || c warn "Resolusi (wm)" "perintah wm tidak ditemukan"
command -v am >/dev/null 2>&1 && c ok "Bersihkan app latar (am)" "tersedia" || c info "am" "tidak ditemukan"
bt=""; [ -f $SYS/class/power_supply/battery/temp ] && read bt < $SYS/class/power_supply/battery/temp
if [ -n "$bt" ]; then c ok "Sensor suhu baterai" "terbaca"; else c bad "Sensor suhu baterai" "tidak terbaca, pengaman suhu tidak bekerja"; fi
c info "Chipset" "$CHIP ($SOCNAME), RAM ${RAM_MB:-?} MB"
