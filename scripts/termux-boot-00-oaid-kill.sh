#!/data/data/com.termux/files/usr/bin/sh
# OPPO PYC110: 开机后自动让 OAID 归零（无 root，借 Shizuku 的 shell 权限）
# 由 Termux:Boot 在 BOOT_COMPLETED 后自动执行，全程无需人工操作。
# 原理: com.nearme.instant.platform(快应用平台) 开机会查 OAIDStatusProvider，
#       把 com.heytap.openid 拉活；所以必须在开机后几分钟内反复「双杀」压掉竞态窗口。
# 2026-11-14
H=/data/data/com.termux/files/home
LOG=$H/boot-oaid.log
exec >>"$LOG" 2>&1
echo "===== $(date '+%F %T') boot ====="
export RISH_APPLICATION_ID=com.termux
export PATH=$H:$PATH

KILL="am force-stop com.heytap.openid; am force-stop com.nearme.instant.platform"

# 等 Shizuku server 起来（开机自动启动，与本脚本有先后竞争）。最长等 10 分钟。
i=0
while [ $i -lt 40 ]; do
  if rish -c "id" 2>/dev/null | grep -q "uid=2000"; then
    echo "[$(date +%T)] rish ready (attempt $i)"
    break
  fi
  i=$((i+1)); sleep 15
done
if [ $i -ge 40 ]; then echo "[$(date +%T)] FATAL: rish 不可用"; exit 1; fi

# 阶段1: 前 5 分钟每 15 秒双杀一次（压掉开机竞态；instant.platform 会在开机后几十秒才起来）
n=0
while [ $n -lt 20 ]; do
  rish -c "$KILL" >/dev/null 2>&1
  n=$((n+1)); sleep 15
done
echo "[$(date +%T)] phase1 done ($n 轮双杀)"

# 阶段2: 之后 30 分钟每 2 分钟巡检，发现复活再杀
m=0
while [ $m -lt 15 ]; do
  sleep 120
  if [ -n "$(rish -c 'pidof com.heytap.openid')" ]; then
    echo "[$(date +%T)] 复活，再双杀"
    rish -c "$KILL" >/dev/null 2>&1
  fi
  m=$((m+1))
done

PID=$(rish -c 'pidof com.heytap.openid' 2>/dev/null)
PROV=$(rish -c 'dumpsys activity providers | grep -c ids_provider' 2>/dev/null)
echo "[$(date +%T)] final: openid_pid=[$PID] ids_provider=[$PROV]"
