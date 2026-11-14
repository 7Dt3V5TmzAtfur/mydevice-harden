#!/usr/bin/env bash
# =============================================================================
# OPPO PYC110 二级加固「一键复原」脚本（全量可逆）
# 用途: 把 apply-tier2.sh 造成的所有改动还原到接近出厂状态
# 用法: bash rollback.sh              # 复原全部加固改动，保留 Shizuku 可用性
#       bash rollback.sh --strict     # 连 Shizuku 的通知授权/白名单也一并撤掉
#       bash rollback.sh --dry-run    # 只打印将执行的命令
# 原理: 设置项用 settings delete（删除覆盖值→回落到系统默认），而不是猜默认值；
#       包状态用 pm unsuspend + pm default-state / pm enable 还原。
# 注意: 复原后 OTA 自动更新、云控组件、运营商 DM 上报都会恢复。
# =============================================================================
set -uo pipefail

DRY=0
STRICT=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --strict)  STRICT=1 ;;
  esac
done

run() {
  if [ "$DRY" = "1" ]; then echo "  [dry] adb shell $*"; else adb shell "$@" >/dev/null 2>&1; fi
}
say() { printf '\n== %s ==\n' "$*"; }
hr()  { printf '%s\n' "------------------------------------------------------------------"; }

DISABLE=(
  com.mobiletools.systemhelper
  com.coloros.regservice
  com.oppo.instant.local.service
  com.qualcomm.qti.devicestatisticsservice
  com.oplus.apprecover
  com.oplus.logtrial
  com.oplus.metis
  com.oplus.nas
  com.oplus.nhs
  com.oplus.obrain
  com.oplus.ovoicemanager
  com.oplus.ovoicemanager.wakeup
  com.oplus.qualityprotect
  com.oplus.sauhelper
  com.oplus.stdsp
  com.oplus.thirdkit
  com.oplus.vdc
  com.heytap.cloud
  com.heytap.speechassist
  com.coloros.digitalwellbeing
  com.coloros.remoteguardservice
  com.android.virtualization.terminal
)

SUSPEND=(
  com.opos.ads
  com.heytap.pictorial
  com.heytap.browser
  com.heytap.quicksearchbox
  com.heytap.htms
  com.heytap.tas
  com.heytap.openid
  com.oplus.pantanal.ums
  com.oplus.themestore
  com.nearme.instant.platform
  com.oplus.cota
  com.oplus.romupdate
)

# -----------------------------------------------------------------------------
say "0. 设备检查"
adb devices | sed -n '2,$p'
echo "model = $(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')"

# -----------------------------------------------------------------------------
say "1. 解除挂起（${#SUSPEND[@]} 个）"
for p in "${SUSPEND[@]}"; do
  printf '  unsuspend %-46s' "$p"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r1=$(adb shell pm unsuspend --user 0 "$p" 2>&1 | tr -d '\r')
    r2=$(adb shell pm default-state --user 0 "$p" 2>&1 | tr -d '\r')
    st=$(adb shell dumpsys package "$p" 2>/dev/null | grep -m1 "User 0:" | grep -o 'suspended=[a-z]*\|enabled=[0-9]*' | tr '\n' ' ')
    echo "$st"
  fi
done

# -----------------------------------------------------------------------------
say "2. 恢复禁用（${#DISABLE[@]} 个）"
for p in "${DISABLE[@]}"; do
  printf '  enable %-49s' "$p"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    adb shell pm enable --user 0 "$p" >/dev/null 2>&1
    st=$(adb shell dumpsys package "$p" 2>/dev/null | grep -m1 "User 0:" | grep -o 'suspended=[a-z]*\|enabled=[0-9]*' | tr '\n' ' ')
    echo "$st"
  fi
done

# -----------------------------------------------------------------------------
say "2b. 恢复被用户级卸载的包"
for p in com.oplus.onetrace; do
  printf '  install-existing %-38s' "$p"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r=$(adb shell pm install-existing --user 0 "$p" 2>&1 | tr -d '\r')
    echo "$r"
  fi
done

# -----------------------------------------------------------------------------
say "3. 恢复敏感权限"
grant() {
  printf '  grant %-43s %-40s' "$1" "$2"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r=$(adb shell pm grant "$1" "$2" 2>&1 | tr -d '\r')
    [ -z "$r" ] && r="(ok)" || r="!! $r"
    echo "$r"
  fi
}
for p in com.coloros.weather.service com.coloros.weather2 com.heytap.tas com.heytap.browser; do
  grant "$p" android.permission.ACCESS_FINE_LOCATION
  grant "$p" android.permission.ACCESS_COARSE_LOCATION
  grant "$p" android.permission.ACCESS_BACKGROUND_LOCATION
done
grant com.heytap.music     android.permission.POST_NOTIFICATIONS
grant com.coloros.weather2 android.permission.POST_NOTIFICATIONS

# -----------------------------------------------------------------------------
say "4. 删除设置项覆盖（回落到系统默认）"
del() {
  printf '  delete %-8s %-56s' "$1" "$2"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    adb shell settings delete "$1" "$2" >/dev/null 2>&1
    echo "→ now=$(adb shell settings get "$1" "$2" 2>/dev/null | tr -d '\r')"
  fi
}
del global ota_disable_automatic_update
del secure oplus_custom_ota_dot_on_launcher
del secure com.oplus.opex.detected_status
del system com.oplus.opex.downloaded_status
del secure ad_defender_switch
del secure key_recommend_service
del secure recommend_permission_enabled
del secure recommend_support
del secure recommend_notification_status
del secure key_com_opos_ads_user_permission
del secure key_heytap_market_strengthen_service
del secure key_enhance_service_browser
del secure com.heytap.market.settings.pref.show.new.user.notification
del global recommend_notify_interval
del global hotword_detection_enabled
del global wifi_scan_always_enabled

# -----------------------------------------------------------------------------
if [ "$STRICT" = "1" ]; then
  say "5. (--strict) 撤销 Shizuku 通知授权与 doze 白名单"
  run pm revoke moe.shizuku.privileged.api android.permission.POST_NOTIFICATIONS
  run dumpsys deviceidle whitelist -moe.shizuku.privileged.api
  echo "  done"
else
  say "5. 保留 Shizuku 通知授权与 doze 白名单（如需撤销加 --strict）"
fi

# -----------------------------------------------------------------------------
if [ "$DRY" = "1" ]; then hr; echo "dry-run 结束，未做任何修改。"; exit 0; fi

say "6. 验证"
DIS_CNT=$(adb shell dumpsys package | grep 'User 0: ceDataInode' | grep -c 'enabled=3')
SUS_CNT=$(adb shell dumpsys package | awk '/^  Package \[/{p=$2} /suspended=true/{print p}' | sort -u | wc -l)
echo "禁用标记数: $DIS_CNT   (复原后应为 0；若残留 1，多为 manifest 自带 disabled 的包)"
echo "挂起包数:   $SUS_CNT   (复原后应为 0)"
echo
echo "抽查:"
for p in com.heytap.openid com.opos.ads com.heytap.browser com.mobiletools.systemhelper com.heytap.market; do
  st=$(adb shell dumpsys package "$p" 2>/dev/null | grep -m1 "User 0:" | grep -o 'suspended=[a-z]*\|enabled=[0-9]*' | tr '\n' ' ')
  printf '  %-38s %s\n' "$p" "$st"
done
hr
echo "完成。建议重启一次，确认 OTA/云控组件恢复且无异常通知。"
