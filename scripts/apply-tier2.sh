#!/usr/bin/env bash
# =============================================================================
# OPPO PYC110 二级加固一键应用脚本
# 目标机型: OPPO A7 Pro Max (PYC110) / ColorOS 16 / PYC110_16.0.9.409(CN01)
# 用途: 在一台「干净」的同型号机上复现本仓库记录的整套加固
#       （禁用 21 包 + 挂起 12 包 + 权限撤销 + 广告/推荐开关 + Shizuku 通知授权）
# 用法: bash apply-tier2.sh            # 实际执行
#       bash apply-tier2.sh --dry-run  # 只打印将执行的命令
# 前置: adb 已连接（USB 或无线），且 shell 用户可用（无需 root）
# 回滚: bash rollback.sh（全量可逆）
# 生成时间: 2026-11-14
# =============================================================================
set -uo pipefail

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

run() {
  if [ "$DRY" = "1" ]; then
    echo "[dry] $*"
  else
    adb shell "$@" >/dev/null 2>&1
  fi
}

hr() { printf '%s\n' "------------------------------------------------------------------"; }
say() { printf '\n== %s ==\n' "$*"; }

# -----------------------------------------------------------------------------
# 0. 前置检查
# -----------------------------------------------------------------------------
say "0. 设备检查"
adb devices | sed -n '2,$p'
MODEL=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo "model = $MODEL"
if [ "$MODEL" != "PYC110" ]; then
  echo "!! 警告: 目标机型是 PYC110，当前是 '$MODEL'，继续执行可能不适用。"
  [ "$DRY" = "0" ] && read -r -p "仍要继续? [y/N] " a && [ "$a" = "y" ] || { [ "$DRY" = "0" ] && exit 1; }
fi

# -----------------------------------------------------------------------------
# 1. 禁用（pm disable-user → enabled=3）
#    注意: ColorOS 对部分包会把 disable 降级为 suspended，回读可能是
#    "new state: default"，此时看 dumpsys 的 suspended=true 才是真值。
# -----------------------------------------------------------------------------
DISABLE=(
  com.mobiletools.systemhelper          # 联通 OMA-DM 终端管理, 上报 dm.wo.com.cn
  com.coloros.regservice                # 移动 DM 注册, 上报 a.fxltsl.com
                                        # 注意: pm list packages -d 漏报这个包，只有 dumpsys 看得到
  com.qualcomm.qti.devicestatisticsservice
  com.oplus.apprecover                  # 应用恢复 MDSService（非 OTA）
  com.oplus.logtrial                    # 日志回传
  com.oplus.metis                       # 云控/大数据
  com.oplus.nas                         # 网络助手
  com.oplus.nhs                         # 云服务
  com.oplus.obrain                      # 端侧 AI 云控
  com.oplus.ovoicemanager               # 语音助手
  com.oplus.ovoicemanager.wakeup
  com.oplus.qualityprotect              # 质量保护上报
  com.oplus.sauhelper                   # 系统升级辅助
  com.oplus.stdsp                       # 统计
  com.oplus.thirdkit                    # 三方推送聚合
  com.oplus.vdc                         # 虚拟设备云控
  com.heytap.cloud                      # 云同步
  com.heytap.speechassist               # 语音助手
  com.coloros.digitalwellbeing          # 数字健康（用量采集）
  com.coloros.remoteguardservice        # 远程守护
  com.android.virtualization.terminal   # 终端。注意: 该包 manifest 内即声明 disabled，
                                        # disable 会回 "new state: default"，enabled 恒为 0
)

say "1. 禁用 ${#DISABLE[@]} 个包"
for p in "${DISABLE[@]}"; do
  printf '  disable %-46s' "$p"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r=$(adb shell pm disable-user --user 0 "$p" 2>&1 | tr -d '\r')
    echo "$r"
  fi
done

# -----------------------------------------------------------------------------
# 1b. 卸载（pm uninstall --user 0 → installed=false，比禁用更彻底，但留数据壳）
#     注意: 卸载残留的壳在 dumpsys 里仍显示 enabled=3，会被误算进"禁用数"。
# -----------------------------------------------------------------------------
REMOVE=(
  com.oplus.onetrace                    # 全链路埋点/追踪上报
  com.oppo.instant.local.service        # 快应用本地服务（实测可卸，卸完 enabled 归 0）
                                        # 平台本体 com.nearme.instant.platform 在保护名单里，
                                        # 三种删法全失败，只能挂在 SUSPEND 里
)

say "1b. 卸载 ${#REMOVE[@]} 个包（用户级）"
for p in "${REMOVE[@]}"; do
  printf '  uninstall %-46s' "$p"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r=$(adb shell pm uninstall --user 0 "$p" 2>&1 | tr -d '\r')
    echo "$r"
  fi
done

# -----------------------------------------------------------------------------
# 2. 挂起（pm suspend → suspended=true, enabled=0）
#    挂起比禁用更"轻"：仍可见于应用列表但无法运行，适合要保留图标/可恢复的包。
#    重要: 挂起后原进程不会自动退出，必须补 am force-stop（见第 3 步）。
# -----------------------------------------------------------------------------
SUSPEND=(
  com.opos.ads                          # 广告 SDK 服务
  com.heytap.pictorial                  # 锁屏画报（广告位）
  com.heytap.browser                    # 浏览器（信息流）
  com.heytap.quicksearchbox             # 全局搜索（含热搜推荐）
  com.heytap.htms                       # 互联网服务聚合
  com.heytap.tas                        # 应用统计（含 NFC 场景）
  com.heytap.openid                     # OAID 提供方 → 归零 OAID
  com.oplus.pantanal.ums                # 用户画像/画像标签
  com.oplus.themestore                  # 主题商店
  com.nearme.instant.platform           # 快应用平台（保护名单，卸不掉，只能挂）
                                        # 卸掉本地服务 + 本包挂起后，openid 不再被拉活
  com.oplus.cota                        # OTA（挂起失败属正常，见文档「OTA 硬墙」）
  com.oplus.romupdate                   # OTA（同上）
)

say "2. 挂起 ${#SUSPEND[@]} 个包"
for p in "${SUSPEND[@]}"; do
  printf '  suspend %-46s' "$p"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r=$(adb shell pm suspend --user 0 "$p" 2>&1 | tr -d '\r')
    [ -z "$r" ] && r="(ok)"
    echo "$r"
  fi
done

# -----------------------------------------------------------------------------
# 3. 强制停止（挂起不杀进程，ColorOS 尤其明显）
# -----------------------------------------------------------------------------
say "3. force-stop 全部处理过的包"
for p in "${DISABLE[@]}" "${SUSPEND[@]}" "${REMOVE[@]}"; do
  run am force-stop "$p"
done
# 关键: com.nearme.instant.platform(快应用平台) 会用残留 binder 连接把
# com.heytap.openid 吊回来(实测: 两分钟内不死)，必须补一轮「客户端+服务端」同杀。
# 判定是否干净: dumpsys activity providers | grep -c ids_provider 应为 0。
for p in com.heytap.openid com.nearme.instant.platform; do
  run am force-stop "$p"
done
echo "  done（openid 需与 instant.platform 同杀，否则被 binder 吊回）"

# -----------------------------------------------------------------------------
# 4. 撤销敏感权限（定位/通知）
#    背景: 天气服务默认持有 ACCESS_FINE_LOCATION + ACCESS_BACKGROUND_LOCATION
#          (GRANTED_BY_DEFAULT|RESTRICTION_SYSTEM_EXEMPT)，实测每天多次上传经纬度。
# -----------------------------------------------------------------------------
say "4. 撤销敏感权限"
revoke() {
  printf '  revoke %-42s %-40s' "$1" "$2"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    r=$(adb shell pm revoke "$1" "$2" 2>&1 | tr -d '\r')
    [ -z "$r" ] && r="(ok)"
    echo "$r"
  fi
}
for p in com.coloros.weather.service com.coloros.weather2 com.heytap.tas com.heytap.browser; do
  revoke "$p" android.permission.ACCESS_FINE_LOCATION
  revoke "$p" android.permission.ACCESS_COARSE_LOCATION
  revoke "$p" android.permission.ACCESS_BACKGROUND_LOCATION
done
revoke com.heytap.music      android.permission.POST_NOTIFICATIONS
revoke com.coloros.weather2  android.permission.POST_NOTIFICATIONS

# -----------------------------------------------------------------------------
# 5. 广告 / 推荐 / 统计开关
#    说明: 多数开关在本机出厂即为 0，这里全部显式写一遍，保证在别的机上也能复现。
#    已知写不进去的: network_recommendations_enabled（被系统立即写回 1）
# -----------------------------------------------------------------------------
say "5. 关闭广告/推荐/统计开关"
put() {
  printf '  put %-8s %-56s = %-6s' "$1" "$2" "$3"
  if [ "$DRY" = "1" ]; then echo "[dry]"; else
    adb shell settings put "$1" "$2" "$3" >/dev/null 2>&1
    v=$(adb shell settings get "$1" "$2" 2>/dev/null | tr -d '\r')
    if [ "$v" = "$3" ]; then echo "ok"; else echo "!! 回读=$v"; fi
  fi
}
# OTA 相关
put global ota_disable_automatic_update        1
put secure oplus_custom_ota_dot_on_launcher    0
put secure com.oplus.opex.detected_status      0
put system com.oplus.opex.downloaded_status    0
# 广告/推荐
put secure ad_defender_switch                  0
put secure key_recommend_service               0
put secure recommend_permission_enabled        0
put secure recommend_support                   0
put secure recommend_notification_status       0
put secure key_com_opos_ads_user_permission    0
put secure key_heytap_market_strengthen_service 0
put secure key_enhance_service_browser         0
put secure com.heytap.market.settings.pref.show.new.user.notification false
put global recommend_notify_interval           0
put global hotword_detection_enabled           0
# 扫描/隐私
put global wifi_scan_always_enabled            0

# -----------------------------------------------------------------------------
# 6. Shizuku：允许发通知（否则点「配对」只弹"请允许发布通知"，二维码不出现）
# -----------------------------------------------------------------------------
say "6. Shizuku 通知授权 + doze 白名单"
printf '  grant POST_NOTIFICATIONS'
if [ "$DRY" = "1" ]; then echo " [dry]"; else
  adb shell pm grant moe.shizuku.privileged.api android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
  adb shell cmd appops set moe.shizuku.privileged.api POST_NOTIFICATION allow >/dev/null 2>&1
  echo " ok"
fi
printf '  deviceidle whitelist +moe.shizuku.privileged.api'
if [ "$DRY" = "1" ]; then echo " [dry]"; else
  adb shell dumpsys deviceidle whitelist +moe.shizuku.privileged.api >/dev/null 2>&1
  echo " ok"
fi

# -----------------------------------------------------------------------------
# 7. 验证
# -----------------------------------------------------------------------------
if [ "$DRY" = "1" ]; then
  hr; echo "dry-run 结束，未做任何修改。"; exit 0
fi

say "7. 验证"
# 口径说明（三个命令结果互不相等，只信 dumpsys）:
#   dumpsys  enabled=3     → 21  = 20 真禁用 + 1 卸载残留壳(com.oplus.onetrace)
#   pm list packages -d    → 21  = 19 真禁用 + 2 假阳性 - 漏报 1 个(见下)
#   pm list packages -d -u → 22  = 上面 21 + onetrace
#
#   两处必须知道的偏差:
#     (a) 漏报: com.coloros.regservice 是真的 enabled=3，但 pm -d 不列它。
#     (b) 假阳性: com.android.virtualization.terminal(manifest 自带 enabled=false)
#         和 com.oplus.customize.coreapp(实际 enabled=2，只是有子组件被禁)
#         都会被 pm -d 列进来，但 dumpsys 里根本不算禁用。
#   结论: 只有 `dumpsys package | grep 'User 0:' | grep -c enabled=3` 可信。
DIS_CNT=$(adb shell dumpsys package | grep 'User 0: ceDataInode' | grep -c 'enabled=3')
SUS_CNT=$(adb shell dumpsys package | awk '/^  Package \[/{p=$2} /suspended=true/{print p}' | sort -u | wc -l)
echo "禁用/卸载标记数: $DIS_CNT  (预期 21 = 20 真禁用 + 1 卸载壳 onetrace)"
echo "挂起包数:        $SUS_CNT  (预期 12)"
echo
echo "关键状态:"
for p in com.heytap.openid com.opos.ads com.heytap.browser com.mobiletools.systemhelper; do
  st=$(adb shell dumpsys package "$p" 2>/dev/null | grep -m1 "User 0:" | grep -o 'suspended=[a-z]*\|enabled=[0-9]*' | tr '\n' ' ')
  printf '  %-38s %s\n' "$p" "$st"
done
echo
echo "设置项:"
for kv in "global ota_disable_automatic_update" "secure key_enhance_service_browser" "global wifi_scan_always_enabled" "secure ad_defender_switch"; do
  set -- $kv
  printf '  %-46s = %s\n' "$2" "$(adb shell settings get "$1" "$2" | tr -d '\r')"
done
hr
echo "完成。建议: 重启后用 rollback.sh 反向验证，或按文档《附四》逐项核对。"
