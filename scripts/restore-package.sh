#!/bin/bash
# restore-package.sh <包名> [包名...]
# 把 apply-tier2.sh / apply-tier3.sh 处理过的单个应用还给用户（不整体回滚）。
# 做三件事并按顺序验证：
#   1) 撤销挂起  pm unsuspend
#   2) 撤销禁用  pm enable（enabled=3 -> 0）
#   3) 拉起一次  monkey LAUNCHER，并确认进程/前台窗口
# 用法:
#   ./restore-package.sh com.heytap.browser
#   ./restore-package.sh com.heytap.browser com.coloros.alarmclock
#
# 注意: 重跑 apply-tier2.sh 会把它再次挂起/禁用。要长期保留，就别整脚本重放。
export MSYS_NO_PATHCONV=1

if [ $# -lt 1 ]; then
  echo "usage: $0 <package> [package...]"
  exit 1
fi

rc_all=0
for p in "$@"; do
  echo "===== $p ====="

  adb shell "pm unsuspend --user 0 $p" 2>&1 | tr -d '\r'
  adb shell "pm enable --user 0 $p"    2>&1 | tr -d '\r'

  STATE=$(adb shell "dumpsys package $p 2>/dev/null | grep -m1 'User 0:'" | tr -d '\r')
  case "$STATE" in
    "") echo "  !! 包不存在或未安装"; rc_all=1; continue ;;
  esac
  echo "  状态: $(echo "$STATE" | grep -oE 'suspended=[a-z]+|enabled=[0-9]+' | tr '\n' ' ')"

  echo "$STATE" | grep -q "suspended=true" && { echo "  !! 挂起未撤销"; rc_all=1; }
  echo "$STATE" | grep -q "enabled=3"      && { echo "  !! 仍处于禁用"; rc_all=1; }

  adb shell "monkey -p $p -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1
  sleep 3
  PID=$(adb shell "pidof $p" | tr -d '\r')
  FOCUS=$(adb shell "dumpsys window 2>/dev/null | grep -m1 mCurrentFocus" | tr -d '\r')
  echo "  进程: ${PID:-none}"
  echo "  前台: ${FOCUS:-unknown}"
done

exit $rc_all
