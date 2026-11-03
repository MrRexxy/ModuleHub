#!/system/bin/sh
MODDIR=${0%/*}
case "$1" in
  restart) sh $MODDIR/gamed.sh stop >/dev/null 2>&1
    if command -v setsid >/dev/null 2>&1; then setsid sh $MODDIR/gamed.sh daemon >/dev/null 2>&1 </dev/null &
    else nohup sh $MODDIR/gamed.sh daemon >/dev/null 2>&1 </dev/null &
    fi
    echo "OK|daemon dimulai" ;;
  stop) sh $MODDIR/gamed.sh stop; echo "OK|dihentikan dan dikembalikan ke bawaan" ;;
  *) echo "pakai: tools.sh restart|stop" ;;
esac
