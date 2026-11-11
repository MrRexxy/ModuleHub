#!/system/bin/sh
# game.sh list -> PKG|nama.paket  (aplikasi pihak ketiga yang terpasang)
case "$1" in
  list) pm list packages -3 2>/dev/null | sed -n 's/^package:\(.*\)$/PKG|\1/p' | sort ;;
  launch)
    pkg="$2"; case "$pkg" in ''|*[!A-Za-z0-9._]*) echo "ERR|paket tidak valid"; exit 1 ;; esac
    if monkey -p "$pkg" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; then echo "OK|dibuka"; else echo "ERR|gagal membuka"; fi ;;
  *) echo "pakai: game.sh list|launch PAKET" ;;
esac
