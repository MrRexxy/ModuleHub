#!/system/bin/sh
# display.sh set PERSEN | reset | status   (menurunkan resolusi dan kerapatan secara proporsional)
FLAG=/data/adb/modulehub_gb_wm
case "$1" in
  set)
    p="$2"; case "$p" in ''|*[!0-9]*) echo "ERR|persen tidak valid"; exit 1 ;; esac
    [ "$p" -ge 50 ] && [ "$p" -le 100 ] || { echo "ERR|persen 50-100"; exit 1; }
    sz="$(wm size 2>/dev/null | sed -n 's/^Physical size: //p' | head -1)"
    den="$(wm density 2>/dev/null | sed -n 's/^Physical density: //p' | head -1)"
    w="${sz%x*}"; h="${sz#*x}"
    case "$w$h$den" in ''|*[!0-9]*) echo "ERR|tidak bisa membaca ukuran layar ($sz / $den)"; exit 1 ;; esac
    nw=$(( w * p / 100 / 2 * 2 )); nh=$(( h * p / 100 / 2 * 2 )); nd=$(( den * p / 100 ))
    echo "$sz|$den" > "$FLAG"
    wm size ${nw}x${nh} && wm density $nd && echo "OK|${nw}x${nh} @ ${nd}dpi" ;;
  reset) wm size reset 2>/dev/null; wm density reset 2>/dev/null; rm -f "$FLAG"; echo "OK|resolusi dikembalikan" ;;
  status)
    sz="$(wm size 2>/dev/null | tr '\n' ' ')"; den="$(wm density 2>/dev/null | tr '\n' ' ')"
    echo "DISP|$sz|$den|$([ -f "$FLAG" ] && echo 1 || echo 0)" ;;
  *) echo "pakai: display.sh set N|reset|status" ;;
esac
