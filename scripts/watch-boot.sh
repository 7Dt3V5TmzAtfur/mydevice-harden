#!/bin/bash
# watch-boot.sh <label> - 重启后观测 Shizuku 自启
export MSYS_NO_PATHCONV=1
LBL="${1:-boot}"
LOG="/d/1/device-harden/devices/.tmp/${LBL}.log"
: > "$LOG"

echo "[$(date +%H:%M:%S)] reboot issued ($LBL)" | tee -a "$LOG"
adb reboot
adb wait-for-device
T0=$(date +%s)
BOOTID=$(adb shell "cat /proc/sys/kernel/random/boot_id" 2>/dev/null | tr -d '\r')
echo "[$(date +%H:%M:%S)] online, boot_id=$BOOTID" | tee -a "$LOG"
echo "[$(date +%H:%M:%S)] freezer=$(adb shell settings get global cached_apps_freezer 2>/dev/null | tr -d '\r')" | tee -a "$LOG"

i=0
while [ $i -lt 60 ]; do
  NOW=$(( $(date +%s) - T0 ))
  SRV=$(adb shell "pidof shizuku_server" 2>/dev/null | tr -d '\r')
  APP=$(adb shell "pidof moe.shizuku.privileged.api" 2>/dev/null | tr -d '\r')
  echo "[$(date +%H:%M:%S) +${NOW}s] attempt=$i server=${SRV:-none} app=${APP:-none}" | tee -a "$LOG"
  if [ -n "$SRV" ]; then
    echo "[$(date +%H:%M:%S) +${NOW}s] *** SERVER UP ***" | tee -a "$LOG"
    break
  fi
  i=$((i+1))
  sleep 15
done
[ $i -ge 60 ] && echo "[$(date +%H:%M:%S)] TIMEOUT 15min" | tee -a "$LOG"

echo "=== freeze 事件 ===" | tee -a "$LOG"
adb logcat -d 2>/dev/null | grep -E "freezing|unfroze" | grep -i shizuku | tail -15 | tee -a "$LOG"
echo "=== ShizukuShellLoader ===" | tee -a "$LOG"
adb logcat -d 2>/dev/null | grep -E "ShizukuShellLoader|Binder not received|System.exit" | tail -10 | tee -a "$LOG"
echo "=== done ===" | tee -a "$LOG"
