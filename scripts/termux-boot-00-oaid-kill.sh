#!/data/data/com.termux/files/usr/bin/sh
# OPPO PYC110: 开机后自动压制 OAID 出口（无 root，借 Shizuku 的 shell 权限）
# 由 Termux:Boot 在 BOOT_COMPLETED 后自动执行，全程无需人工操作。
#
# 实测链路（04 次重启与 05 次重启各抓到一次，日志见仓库 OPPOA7ProMax-PYC110.md 附五 §8）：
#   com.android.launcher 查 AssistantConfigProvider
#     -> 拉起 com.coloros.assistantscreen（负一屏）进程
#          -> 约 4 分钟后查 com.nearme.instant.card.CardStatusProvider
#               -> 拉起 com.nearme.instant.platform:provider（快应用平台，已挂起也照起）
#                    -> 它再查 com.heytap.openid 的 OAIDStatusProvider
#                         -> OAID 出口上线
#
# 关键结论:
#   1) pm suspend 对 ContentResolver.query 完全不设防（宿主侧、调用方侧都是）。
#   2) 组件级 pm disable 被保护名单拒绝: Shell cannot change component state ... to 2。
#   3) 【反例，务必不要再犯】不要把 com.coloros.assistantscreen 加进击杀名单。
#      桌面 com.android.launcher 对它持有 bindService(AssistantKeepAliveService)，
#      杀掉后桌面立刻重新绑定、进程秒起，而它起来第一件事就是查 OAIDStatusProvider。
#      实测: 只杀 openid+instant 时每轮开机唤醒 1 次（存活约 6.8 秒）；
#            加上杀 assistantscreen 后变成每 15~16 秒唤醒 1 次（06 次重启实测）。
#      所以负一屏只能「挂起」（挡 UI），不能「反复杀」（会变成反向加压）。
# 因此击杀名单固定为两个: openid + instant.platform。
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

# 阶段1: 前 5 分钟每 15 秒双杀一次
#   为什么不是只在开机瞬间杀一刀: 复活发生在开机后约 4 分钟（负一屏延迟查询），
#   砍早了没用；15 秒一轮能把「被拉活到被杀」的窗口压到 15 秒以内（实测 6.8 秒）。
n=0
while [ $n -lt 20 ]; do
  rish -c "$KILL" >/dev/null 2>&1
  n=$((n+1)); sleep 15
done
echo "[$(date +%T)] phase1 done ($n 轮双杀)"

# 阶段2: 稀疏兜底。20 分钟、每 30 秒一次（共 40 次）。
#   数据来源（八次重启）: openid 被唤醒的时刻是 T+3.9 / 3.9 / 3.95 / **12.3** 分钟
#   —— 第四次（08 次重启）晚了整整 8 分钟，说明这个时机不是固定值，
#   跟负一屏/OTA 界面被拉起的节奏有关，会随手机会话而变化。
#   两次教训:
#     ① 砍到 5 分钟会直接漏掉 T+12min 那种情况 -> 窗口必须比已观测值宽。
#     ② 稀疏到 60 秒代价太大: 那一轮 openid 存活了 80 秒（15 秒档只有 3.4~6.8 秒）。
#   所以选 30 秒档: 活口上限 30 秒，总窗口覆盖到 T+25 分钟，Termux 常驻约 25 分钟。
m=0
while [ $m -lt 40 ]; do
  sleep 30
  if [ -n "$(rish -c 'pidof com.heytap.openid')" ]; then
    echo "[$(date +%T)] 复活，再双杀"
    rish -c "$KILL" >/dev/null 2>&1
  fi
  m=$((m+1))
done
echo "[$(date +%T)] phase2 done ($m 轮兜底)"

PID=$(rish -c 'pidof com.heytap.openid' 2>/dev/null)
PROV=$(rish -c 'dumpsys activity providers | grep -c ids_provider' 2>/dev/null)
echo "[$(date +%T)] final: openid_pid=[$PID] ids_provider=[$PROV]"

# 到此脚本结束 -> Termux:Boot 启动的 TermuxService 停止 -> com.termux 进程被系统回收。
# 不需要手动 force-stop: 用 force-stop 会把 com.termux 置为 stopped 状态，
# 反而给下一次 Termux:Boot 触发埋隐患。Shizuku server 是独立进程，不受影响。
echo "[$(date +%T)] script exit"
