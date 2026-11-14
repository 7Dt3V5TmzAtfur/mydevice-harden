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
#   4) 开机那第一刀永远拦不住: 09 次重启实测 19:59:18.697，com.android.launcher
#      直接查 openid 的 OAIDStatusProvider，比 Termux:Boot 启动（19:59:40）还早 22 秒。
#      本脚本买的是「每次复活只活几秒」，不是「不复活」。
#   5) 09 次重启还抓到两条新边: instant 的 InstantProvider 被 com.oplus.notificationmanager
#      拉起（不经过负一屏）；openid 被 com.heytap.pictorial 拉起（新调用方）。
# 因此击杀名单固定为两个: openid + instant.platform。
#
# 【v2 变更，2026-11-14 夜，第 16 次重启实验】加 wakelock 试图活过 T+115 秒
#   第 10~15 次重启（21:10 / 21:14 / 21:20 / 21:37 / 21:43）里本脚本全部只跑到
#   「rish ready」就被 ColorOS 在 T+113~115 秒干掉，phase1 一次都没写完：
#     11-14 21:45:40 I am_kill: [0,10095,com.termux,200,stop com.termux due to o-stop(35),...]
#   而 18:52~19:59 那六次全部跑完 phase1。两者差异排除了这些：
#     - 不是冻结器（cached_apps_freezer=null 时照样被杀，见附八 §5）
#     - 不是自启动拦截（BootCompleteReceiver 每轮都在 LOCKED_BOOT_COMPLETED 就被拉起）
#     - 不是 standby bucket（实测 am get-standby-bucket = 10 = ACTIVE）
#     - 不是残留的「完全允许后台行为」（第 15 次已改回智能优化，boot_clear 标记消失，
#       但 force-stop 照旧，且 dumpsys 显示 com.termux stopped=true）
#   剩下的解释是它当时是 cached 进程。所以本轮用 termux-wake-lock 把 TermuxService
#   抬成前台服务（常驻通知），看 adj 能不能躲过这一刀。成则阶段2 可跑，败则阶段2
#   在本机无 root 下结构性不可实现。
#   注意: 必须在等 rish 之前就加锁 —— 那一刀就落在 T+115 秒，等 rish 可能已经来不及。
# 2026-11-14
H=/data/data/com.termux/files/home
LOG=$H/boot-oaid.log
exec >>"$LOG" 2>&1
echo "===== $(date '+%F %T') boot ====="
export RISH_APPLICATION_ID=com.termux
export PATH=$H:$PATH

# 第一件事就是抢 wakelock：ColorOS 的清扫落在 T+113~115 秒，比抢锁晚就白搭。
# termux-wake-lock -> am startservice -a com.termux.service_wake_lock
#   -> TermuxService.setWakeLock(true) -> PARTIAL_WAKE_LOCK + 常驻通知 -> 前台服务 adj
termux-wake-lock 2>/dev/null
echo "[$(date +%T)] wakelock requested (rc=$?)"

KILL="am force-stop com.heytap.openid; am force-stop com.nearme.instant.platform"

# 等 Shizuku server 起来（开机自动启动，与本脚本有先后竞争）。最长等 15 分钟。
#
# 【重要，别给自己虚假信心】非 root 下 Shizuku 自启是「概率事件」，不是保证：
#   07 次重启及之前全部 attempt 0~1（开机 1~17 秒就拿到 shell）；
#   09 次开机时 BootCompleteReceiver 照样在 LOCKED_BOOT_COMPLETED 被拉起（callingUid=1000），
#   但 shizuku_server 整整 10 分钟没起来，最后是人点 Shizuku 界面「启动」后才通。
#   排除过：doze 白名单本来就有、RUN_IN_BACKGROUND=allow、WiFi 在线、
#           无线调试实际在听 192.168.50.170:44253 —— 都不是原因。
#   真实原因更像「慢启动 + ColorOS 冻结」：那次 load 19.5，Shizuku 进程起来 37 秒后
#   就被 am_freeze，连无线调试/spawn server 都没走完，而它 resume 时不会重试。
#
#   所以这里只能等，不能替它启动：启动链是
#     moe.shizuku.starter.ServiceStarter --token=  + StarterActivity
#   发起方必须是 shell(2000)，Termux 是 10292 且无 su，做不了。
#   也试过但无效: 熄屏时 am start 主界面（45s 无反应）、setprop persist.adb.tls_server.enable（SELinux 拒）。
T0=$(date +%s)
i=0
while [ $i -lt 60 ]; do
  if rish -c "id" 2>/dev/null | grep -q "uid=2000"; then
    echo "[$(date +%T)] rish ready (attempt $i, 等待 $(( $(date +%s) - T0 ))s)"
    break
  fi
  i=$((i+1)); sleep 15
done
if [ $i -ge 60 ]; then
  echo "[$(date +%T)] FATAL: rish 15 分钟内不可用 —— Shizuku 这轮没自启"
  echo "  人工补救: 解锁屏幕 -> 打开 Shizuku -> 点「启动」 -> 重跑本脚本"
  exit 1
fi

# 拿到 shell 身份后立刻先杀一刀，别等第一轮循环：
# 开机 5 秒时 com.android.launcher 就已经直接查过 OAIDStatusProvider（09 次重启实测
# 19:59:18.697，比 Termux 启动早 22 秒），openid 大概率已经在跑。
rish -c "$KILL" >/dev/null 2>&1

# 阶段1: 前 5 分钟每 15 秒双杀一次
#   为什么不是只在开机瞬间杀一刀: 复活发生在开机后约 4 分钟（负一屏延迟查询），
#   砍早了没用；15 秒一轮能把「被拉活到被杀」的窗口压到 15 秒以内（实测 6.8 秒）。
n=0
while [ $n -lt 20 ]; do
  rish -c "$KILL" >/dev/null 2>&1
  n=$((n+1))
  # 每 5 轮留一个进度点：被杀在哪一轮、还是压根没跑，一眼能分开
  case $n in 5|10|15) echo "[$(date +%T)] phase1 进度 $n/20" ;; esac
  sleep 15
done
echo "[$(date +%T)] phase1 done ($n 轮双杀)"

# 阶段2: 稀疏兜底，跑到「开机后 PHASE2_END 秒」为止，每 30 秒巡检一次。
#   数据来源（十次重启）: openid 被唤醒的时刻（从开机算）是
#     T+3.9 / 3.9 / 3.95 / 12.3 分钟，以及第 17 次实测的 T+19min45s 与 T+32min02s。
#   两次教训:
#     ① 砍到 5 分钟会直接漏掉 T+12min 那种情况 -> 窗口必须比已观测值宽。
#     ② 稀疏到 60 秒代价太大: 那一轮 openid 存活了 80 秒（15 秒档只有 3.4~6.8 秒）。
#   所以选 30 秒档。
#
# 【v3 关键改动，2026-11-14 夜】窗口锚点从「脚本启动」改成「开机时刻」
#   旧版是固定 40 轮 = 20 分钟，而脚本起点会漂移：实测最快开机后 2 秒拿到 shell，
#   最慢 469 秒（Shizuku 没自启，人工点「启动」后才通）。于是"总窗口"实际是
#   漂移的，第 17 次就是因为白等了 8 分钟才勉强接住 T+32min 那次复活——是运气不是设计。
#   现在改成读 /proc/uptime，跑到开机后 PHASE2_END 秒为止，与漂移无关：
#     若脚本在 T+2s 起来 -> 阶段2 跑约 35 分钟；
#     若在 T+469s 起来 -> 约 32 分钟；若已过 PHASE2_END，则阶段2 直接跳过。
#   选 2400（T+40min）的理由: 最大已观测复活是 T+32min02s，留 8 分钟余量。
PHASE2_END=2400
m=0
while :; do
  NOW=$(cut -d. -f1 /proc/uptime 2>/dev/null)
  case "$NOW" in ''|*[!0-9]*) NOW=0 ;; esac
  if [ "$NOW" -ge "$PHASE2_END" ]; then
    echo "[$(date +%T)] phase2 到点退出 (uptime ${NOW}s >= ${PHASE2_END}s)"
    break
  fi
  if [ $m -ge 80 ]; then
    echo "[$(date +%T)] phase2 触到安全上限 80 轮 (uptime ${NOW}s)"
    break
  fi
  sleep 30
  if [ -n "$(rish -c 'pidof com.heytap.openid')" ]; then
    echo "[$(date +%T)] 复活，再双杀 (uptime ${NOW}s)"
    rish -c "$KILL" >/dev/null 2>&1
  fi
  m=$((m+1))
done
echo "[$(date +%T)] phase2 done ($m 轮兜底)"

PID=$(rish -c 'pidof com.heytap.openid' 2>/dev/null)
PROV=$(rish -c 'dumpsys activity providers | grep -c ids_provider' 2>/dev/null)
echo "[$(date +%T)] final: openid_pid=[$PID] ids_provider=[$PROV]"

# 自己解锁，别把通知留在通知栏上（锁没释放的话会一直挂着）
termux-wake-unlock 2>/dev/null
echo "[$(date +%T)] wakelock released"

# 到此脚本结束 -> Termux:Boot 启动的 TermuxService 停止 -> com.termux 进程被系统回收。
# 不需要手动 force-stop: 用 force-stop 会把 com.termux 置为 stopped 状态，
# 反而给下一次 Termux:Boot 触发埋隐患。Shizuku server 是独立进程，不受影响。
echo "[$(date +%T)] script exit"
