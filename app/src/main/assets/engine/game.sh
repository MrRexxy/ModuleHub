#!/system/bin/sh
# game.sh list -> PKG|nama.paket  (aplikasi pihak ketiga yang terpasang)
case "$1" in
  list) pm list packages -3 2>/dev/null | sed -n 's/^package:\(.*\)$/PKG|\1/p' | sort ;;
  *) echo "pakai: game.sh list" ;;
esac
