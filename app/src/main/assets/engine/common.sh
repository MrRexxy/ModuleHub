#!/system/bin/sh
lc() { echo "$1" | tr 'A-Z' 'a-z'; }
prop() { for k in "$@"; do v="$(getprop "$k")"; [ -n "$v" ] && { echo "$v"; return; }; done; }

detect_brand() {
  B="$(lc "$(prop ro.product.brand ro.product.manufacturer ro.product.vendor.brand)")"
  case "$B" in
    xiaomi|redmi|poco) BRAND=xiaomi ;;
    samsung) BRAND=samsung ;;
    oppo|realme|oneplus) BRAND=oppo ;;
    vivo|iqoo) BRAND=vivo ;;
    infinix|tecno|itel) BRAND=transsion ;;
    google) BRAND=google ;;
    motorola|lenovo) BRAND=motorola ;;
    asus) BRAND=asus ;;
    *) BRAND="${B:-unknown}" ;;
  esac
  MODEL="$(prop ro.product.model ro.product.vendor.model)"
  DEVICE="$(lc "$(prop ro.product.device ro.product.vendor.device)")"
}

detect_chipset() {
  ALL="$(lc "$(prop ro.soc.manufacturer) $(prop ro.board.platform) $(prop ro.hardware) $(prop ro.hardware.chipname) $(prop ro.soc.model) $(prop ro.product.board) $(prop ro.boot.hardware)")"
  case "$ALL" in
    *mt[0-9]*|*mediatek*) CHIP=mediatek ;;
    *exynos*|*universal[0-9]*|*s5e[0-9]*) CHIP=exynos ;;
    *ums[0-9]*|*unisoc*|*spreadtrum*|*ud710*|*sp[0-9][0-9][0-9][0-9]*|*sc[0-9][0-9][0-9][0-9]*) CHIP=unisoc ;;
    *qcom*|*qualcomm*|*msm*|*sdm*|*sm[0-9]*|*bengal*|*trinket*|*lito*|*kona*|*lahaina*|*atoll*|*holi*|*kalama*|*taro*|*parrot*|*crow*|*scuba*|*khaje*) CHIP=qualcomm ;;
    *) CHIP=unknown ;;
  esac
  SOCNAME="$(prop ro.soc.model ro.hardware.chipname ro.board.platform)"
}

read_meminfo() {
  MT=0; MA=0; ST=0; SF=0
  while read k v u; do
    case "$k" in
      MemTotal:) MT=$v ;; MemAvailable:) MA=$v ;;
      SwapTotal:) ST=$v ;; SwapFree:) SF=$v ;;
    esac
  done < /proc/meminfo
}

# pick_le TARGET list... -> OPP tertinggi yang <= TARGET
pick_le() {
  t=$1; shift; best=""
  for f in "$@"; do
    if [ "$f" -le "$t" ] 2>/dev/null; then
      if [ -z "$best" ] || [ "$f" -gt "$best" ]; then best=$f; fi
    fi
  done
  echo "$best"
}
# pick_ge TARGET list... -> OPP terendah yang >= TARGET
pick_ge() {
  t=$1; shift; best=""
  for f in "$@"; do
    if [ "$f" -ge "$t" ] 2>/dev/null; then
      if [ -z "$best" ] || [ "$f" -lt "$best" ]; then best=$f; fi
    fi
  done
  echo "$best"
}

detect_all() {
  detect_brand; detect_chipset; read_meminfo
  ANDROID="$(getprop ro.build.version.release)"
  SDK="$(getprop ro.build.version.sdk)"
  KERNEL="$(uname -r)"
  RAM_MB=$((MT/1024))
}

has_word() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; }
