#!/system/bin/sh
CONF=/data/adb/modulehub_game_boost.conf
[ -f "$CONF" ] || : > "$CONF"
rc=0
for kv in "$@"; do
  k="${kv%%=*}"; v="${kv#*=}"
  case "$k" in ""|*[!A-Z0-9_]*) echo "key tidak valid: $k"; rc=1; continue ;; esac
  case "$v" in *[!A-Za-z0-9._\ -]*) echo "nilai tidak valid untuk $k"; rc=1; continue ;; esac
  if grep -q "^$k=" "$CONF"; then sed -i "s|^$k=.*|$k=\"$v\"|" "$CONF"; else echo "$k=\"$v\"" >> "$CONF"; fi
done
exit $rc
