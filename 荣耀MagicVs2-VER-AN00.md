# 荣耀 Magic Vs2（VER-AN00）

> 本系列第二台设备。**无 root、BL 锁定**，因此比第一台设备少了两整层手段（hosts 与 iptables 都做不了），
> 只能靠 `pm` + `settings`。也正是从这台开始确认：**跨品牌没有可复用的规则，只有方法论可复用。**

## 型号参数版本

| 项 | 值 | 来源 |
|---|---|---|
| 品牌 / 型号 | HONOR `VER-AN00` = 荣耀 Magic Vs2 | `ro.product.model` + 荣耀官网「设备型号」栏 |
| 形态 | 折叠屏，内屏 7.92″ / 外屏 6.43″，2023-10 上市 | 官网规格 |
| 系统 | Android 13 / SDK 33 · MagicOS `7.2.0.125(C00E122R5P5)` | `ro.build.display.id` |
| Root | **无**。`ro.boot.verifiedbootstate=green`，`su` 不存在 | `getprop` / `which su` |
| Bootloader | 锁定 | 同上 |
| 禁用总数 | 157 → **172**（差值正好 15，无附带改动） | `pm list packages -d` |

## 目标

屏蔽荣耀侧的云控。结构与小米**同构**（四条链路），但承载实体**完全不同**，命名零重叠：

| 链路 | 荣耀的承载 | 证据 |
|---|---|---|
| 日志采集 | **三层**：vendor HAL `vendor.honor.hardware.hwhiview@1.0-service` → native `/system/bin/hiview` → 应用 `com.hihonor.hiview` | `ps` 实测三个进程并存 |
| 日志上传 | `com.hihonor.hiviewtunnel`、`com.hihonor.hiviewpush` | 包名语义 + XDA 对 MagicOS 10 的审计结论一致 |
| 分析上报 | `metrics-drcn.dt.hihonorcloud.com:443` | `settings get global com.hihonor.android.pushagent.analytics_server_url` 直接读到 |
| 广告与推荐 | `com.hihonor.search`（Branch Search）、`com.hihonor.hiboard`（负一屏）、`com.hihonor.magazine`（杂志锁屏）、`com.hihonor.servicecenter`（服务中心） | 包名 + 同上公开审计 |

## 已落地方案

### 15 个包 —— 全部 `pm disable-user --user 0`，状态 `enabled=3`

`pm enable` 秒级恢复，改动写入 `/data/system/users/0/package-restrictions.xml`，重启不丢。

| 包 | 作用 | 代价 |
|---|---|---|
| `com.hihonor.hiview` | 日志采集引擎 | 无（用户不可见） |
| `com.hihonor.hiviewtunnel` | 日志上传隧道 | 无 |
| `com.hihonor.hiviewpush` | 日志推送 | 无 |
| `com.hihonor.android.chr` | 远程诊断 / 体验报告 | 无 |
| `com.hihonor.detectrepair` | 售后检测（持 READ_CONTACTS、READ_PHONE_STATE、GET_INSTALLED_APPS、RECEIVE_BOOT_COMPLETED） | 失去「我的荣耀」自助检测 |
| `com.hihonor.magazine` | 杂志锁屏（广告位） | 锁屏只剩静态壁纸 |
| `com.hihonor.hiboard` | 负一屏 | 负一屏空白 |
| `com.hihonor.search` | 全局搜索（Branch Search 广告 SDK） | 桌面下滑搜索不可用 |
| `com.hihonor.searchservice` | 搜索后台服务 | 同上 |
| `com.hihonor.servicecenter` | 服务中心（推荐位） | 快服务卡片不可用 |
| `com.hihonor.awareness` | 情景感知（场景 / 位置 / 活动状态持续采集） | YOYO 建议失去上下文 |
| `com.hihonor.suggestion` | YOYO 建议 | 建议卡片不再出现 |
| `com.hihonor.sceneservice` | 场景服务 | 自动场景不触发 |
| `com.hihonor.aipluginengine` | AI 插件引擎 | 部分 AI 卡片失效 |
| `com.hihonor.msdp` | 运动 / 姿态感知（uid 1000） | 手势与活动识别精度下降 |

### settings 层只写一个键

```bash
adb shell settings put global limit_ad_tracking 1
```

其余四个原本就是关闭状态，无需处理：

```
user_experience_involved=0          用户体验改进计划：已关
hn_collect_state=0                  采集开关：已关
intelli_user_experience_enabled=0   智能体验：已关
oaid                                pps_oaid 全零，已重置
```

### 验证

| 项 | 结果 |
|---|---|
| 15 个包状态 | 全部 `enabled=3` |
| 禁用总数 | 157 → 172，差值正好 15 |
| `system_server` / SystemUI / 桌面 / 电话 | PID 未变（2470 / 3484 / 3837 / 3771），全部存活 |
| 新增 FATAL EXCEPTION | 0（crash buffer 唯一一条是 11-04 的旧记录） |
| awareness / suggestion / search / hiboard | 进程已消失 |
| `com.hihonor.hiview` | 进程仍在（uid 1000），**重启也不退出** |

### 刻意保留

| 包 | 理由 |
|---|---|
| `com.huawei.hwid` | 荣耀账号。禁了应用市场、云服务、查找设备全部失效 |
| `com.huawei.android.pushagent` / `com.hihonor.android.pushagent` | 推送通道。禁了收不到任何通知 |
| `com.hihonor.hncloud` / `com.huawei.hicloud` | 云同步，与第一台同一取舍：功能价值高于隐私代价 |
| `com.hihonor.brain` | AI 基础能力，影响相机慧眼与语音 |
| `com.hihonor.iaware` / `com.hihonor.powergenie` | 性能与功耗调度 |
| `com.hihonor.assistant` | YOYO 本体（建议逻辑已随 awareness / suggestion 停掉） |
| `com.hihonor.systemserver` / `com.hihonor.devicemanager` | 系统核心 |

### 使用

```bash
bash scripts/honor_harden.sh      # 幂等执行：15 个包 + 广告跟踪开关
bash scripts/honor_rollback.sh    # 全部恢复
```

## 踩过的坑

### ① hiview 是三层结构，禁用应用层只关掉三分之一

```
vendor HAL  vendor.honor.hardware.hwhiview@1.0-service   PID 1598
native      /system/bin/hiview                            PID 2149
应用层      com.hihonor.hiview
```

native 与 vendor 两层由 **init 拉起**，`pm` 层根本管不到；`am force-stop` 对 uid 1000 的进程也无效
——实测 force-stop 后 PID 3764 原样不动。这与第一台设备的 `com.miui.daemon` 问题同构，
**区别是这次没有 root 可以升级到 `uninstall --user 0`，所以无解。**

能做的只是：应用层禁用后采集入口只剩 native 一条，而上传通道已经断了，日志只能积压在本地。

### ② Private DNS 在国内这条路是死的

MagicOS 7.2 把「设置 → 网络和互联网 → 私人 DNS」**藏掉了**，界面上找不到。
但设置项本身存在且可写（adb shell 持有 `WRITE_SECURE_SETTINGS`）：

```bash
adb shell settings put global private_dns_mode hostname
adb shell settings put global private_dns_specifier 74b9df.dns.nextdns.io
```

| 配置 | 结果 |
|---|---|
| NextDNS `74b9df.dns.nextdns.io` | **直接断网**。`hostname` 是强制模式，DoT 连不上则全部解析失败（`ping baidu.com: unknown host`）。ICMP 可达（45.11.104.186，202 ms），但 `curl https://…:853` 与 `:443` 均 `rc=35`（TLS 被 reset）→ 域名级阻断 |
| 阿里 `dns.alidns.com`（对照） | **正常**。证明 853 端口、机制、设置项都没问题，问题在目标服务器 |
| AdGuard `dns.adguard.com` | 可达但不可接受：三次未缓存解析 **1.21 s / 2.13 s / 0.87 s**，基线 **0.032 / 0.025 / 0.047 s**，慢 20–85 倍 |

**关键机制**：`private_dns_mode=hostname` 是**严格模式**，DoT 握手失败**不会回退**到明文 DNS，
而是整体解析失败。这一条在第四台设备（OPPO）上又被独立验证了一次。

### ③ RethinkDNS 看起来在工作，实际把整机打到断网

`logcat` 里 `RethinkDnsVpn` 正常处理 `10.111.222.1` 的报文，一切看起来正常。实测相反：

| 测试 | 结果 |
|---|---|
| `ping www.163.com` / `www.jd.com` / `api.weixin.qq.com` | `unknown host` |
| `curl https://www.baidu.com` | `code=000`，**12.03 s** |
| `curl https://www.qq.com` | `code=000`，12.02 s |

根因在 logcat：

```
Firestack: doh: fetch https://sky.rethinkdns.com/rec ...
  dial tcp 104.26.14.30:443: i/o timeout | 172.67.70.254:443: i/o timeout
```

上游 DoH（Cloudflare 承载）在国内不可达。缓存命中的域名还能解析，未命中的一律失败。

> **最危险的地方**：端侧表现与「拦截成功」**完全一致**——目标域名 NXDOMAIN、耗时 12 s。
> 如果只看"广告域名解析失败了"，会误判为规则生效。必须有**功能对照**（baidu/qq 能否正常访问）才能区分。
>
> 同时排除了一个诱因：`settings put secure always_on_vpn_app com.celzero.bravedns`
> 写入后故障不变、删除后故障依旧，已回滚为 `null`。

替代方案换成 **FlClash + 纯本地 YAML 规则**：不向云端取名单、DNS 走系统解析，不引入外部依赖。

### ④ `limit_ad_tracking` 写入成功 ≠ 生效

这是 AOSP 键，荣耀实际用的是 `oaid_limit_state`（当前空值）。
写入不报错不代表 ROM 真的读它，**必须去「设置 → 隐私 → 广告与隐私」核对界面状态**。

### ⑤ Shizuku 不是 root，它的能力边界就是 adb shell

```
$ ps -A -o PID,USER,NAME | grep shizuku
14550 shell        shizuku_server          ← uid 2000(shell)
25059 u0_a458      moe.shizuku.privileged.api
```

| 能做 | 不能做 |
|---|---|
| 给应用授予 `WRITE_SECURE_SETTINGS`、`MANAGE_APP_OPS_MODES`、`DUMP` 等签名级权限 | 写 `/system`、改 hosts |
| 代执行 `pm` / `settings` / `appops` / `cmd` | `iptables`、nftables |
| 让手机端应用（冰箱、App Ops）在拔线后维持控制 | 读 `/data`、`/data/adb` |
| | 杀 uid 1000 的进程（如 native `hiview`） |

所以那 15 项禁用与 Shizuku **无关**，靠的是 adb shell 本身；反过来 Shizuku 也补不上 hosts 与 native 两个缺口。
**真正的分界线是 bootloader 是否解锁，不是 Shizuku 是否在跑。**

### ⑥ Shizuku 开机自启：五次开机只成功 2 次（40%）

两处手工开关做完后连开五次，原始日志见 `evidence/shizuku-reboot-test.txt`：

| # | 关机前 `adb_wifi_enabled` | 开机后写入 | `shizuku_server` | 结果 |
|---|---|---|---|---|
| 1 | 0 | 0→1（约 20 s） | 未出现 | 失败（TLS 已起，搜不到服务） |
| 2 | 1 | 0→1（约 30 s） | PID 11526 | 成功 |
| 3 | 1 | 1 | PID 6433 | 成功 |
| 4 | 1 | **未写** | 未出现 | 失败 |
| 5 | 0 | **未写** | 未出现 | 失败 |

**成功率与关机前开关状态无关**（第 4 次关机前是 1，照样失败）。失败有两种形态：

- **形态 A（4、5 次）**：可信 WLAN 检查没通过。Shizuku 只写了 `adb_enabled`，没写 `adb_wifi_enabled`。
  同一时刻 `dumpsys wifi` 显示仍在 `DISCONNECTED` / `INTERFACE_DISABLED` 之间抖动——开机 20 秒时 Wi-Fi 尚未关联。
  自启条件正是"当前 WLAN 在可信列表内"，网络没就绪，`adb_wifi_enabled` 那一步根本没执行。
- **形态 B（第 1 次）**：过了检查，但 adbd 的 mDNS 注册失效。TLS 监听存在（`*:39603`），Shizuku 搜了 9 分钟搜不到。
  手动关→开无线调试，端口变 43357，5 秒内连上。

**根因**：开机时三个事件没有固定先后顺序——Shizuku 自启、Wi-Fi 关联、adbd 起 TLS。
无 root 时没有任何一方能等待另一方的信号，只能碰运气。

兜底（不需要电脑）：形态 A 直接点「启动」即可（它会自己写回 1）；形态 B 必须先把「无线调试」关掉再打开。
两者都是两次点击，比跑 adb 命令省事。

### ⑦ 两台设备的规则完全不可复用

| | Xiaomi M2105K81AC | HONOR VER-AN00 |
|---|---|---|
| 命名空间 | `com.miui.*` / `com.xiaomi.*` | `com.hihonor.*` / `com.huawei.*` |
| 云控宿主 | `com.miui.daemon`（PERSISTENT，走 `uninstall --user 0`） | 三层 hiview，只有应用层可禁 |
| 域名层 | hosts 24,936 行 + iptables | **完全不可写** |
| 处置手段 | hosts + pm + iptables + 开机校准 | 仅 pm + settings |

**可复用的只有方法论**：先分层定位承载实体，再逐层选手段，最后用进程与状态复核——而不是照搬包名清单。
