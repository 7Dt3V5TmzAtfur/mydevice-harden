# Redmi K30 4G（phoenix）

> 本系列第三台设备。**BL 已解锁 + Magisk**，所以手段回到第一台的量级；
> 但这台最大的不同是方法转向：**不照抄清单，先做 APK 取证**。

## 型号参数版本

| 项 | 值 | 来源 |
|---|---|---|
| 品牌 / 型号 | Redmi `K30`（4G，国行） | `ro.product.model` |
| 代号 | `phoenix` | `ro.product.device` / `ro.product.name` |
| 系统 | Android 12（SDK 31）· MIUI 出厂 `V13.0.6.0.SGHCNXM` | `ro.build.version.release` |
| 完整指纹 | `Redmi/phoenix/phoenix:12/SKQ1.210908.001/V13.0.6.0.SGHCNXM:user/release-keys` | `ro.build.fingerprint` |
| Bootloader | **已解锁**，`anti=2` | `fastboot getvar unlocked`（**唯一可信来源**） |
| Root | **有** — Magisk `31.1 (31100)` | `su -c id` → `uid=0(root)` |
| Magisk 模块 | `miui_cloudblock` / `playintegrityfix` v19 / `zygisk_shamiko` | `/data/adb/modules/` |
| Zygisk | 开启（`zygiskd64` + `zygiskd32` 均在运行），`denylist=0` | `magisk --sqlite` |
| 包构成 | 「第三方」41 个**全部为出厂预装**（`-3` 与 `-s` 交集为空） | `pm list packages -3` |

### 一个必须先澄清的事实：这台机器没有海外固件

交叉核对 mifirm、xiaomiupdate、miuirom 三个源：`phoenix` **只有国行**（20 个版本，最新即已装版本）。
海外兄弟机型 `phoenixin` = POCO X2，只有 India/INXM，且止步 MIUI 12.5 / Android 11。**两者不可互刷。**

所以"刷欧版/美版"这个选项在这台设备上**不存在**。真实可选路径只有三条：
① 只装 Play 商店（GMS 本机已预置）；② xiaomi.eu 的 `xiaomi.eu_multi_HMK30_V13.0.6.0.SGHCNXM_v13-12.zip`；③ AOSP 类。

最终选择：**root + 精简化，不换 ROM**。

## 目标

1. 屏蔽云控（同前两台的四条链路），但**用本机证据重建清单**，不继承其它机型的结论
2. 清退出厂预装推广位，去掉系统级广告
3. 不换 ROM 的前提下拿到 root，并做**精确**的 root 隐藏

## 已落地方案

### 1. APK 取证驱动的域名清单：39 → 75

原 `packages-tier*.txt` / `blocklist-tier1.txt` 是按其它机型写的。直接套用会同时犯两个错：
关掉没证据的包（掉功能）、漏掉本机真实存在的通道。新增两个脚本：

| 脚本 | 作用 |
|---|---|
| `scripts/audit_apk_domains.py` | 解开 APK（dex 是 deflate 压缩的，**裸 grep 会漏**），按预置清单匹配 |
| `scripts/extract_apk_domains.py` | **不预设清单**，抽取 APK 内全部域名字面量，跨包比对剔除基础设施噪声 |

第二个才是关键——它会发现"没人列过"的通道。

**最严重的缺口：`tracking.miui.com` 出现在 11 个 APK 中的 8 个，而原清单完全没有它**
（只封了 `tracker.ai.xiaomi.com`）。OneTrack 是 MIUI 官方埋点主干，等于最主要的通道一直开着。

| 类别 | 新增代表 | 取证来源 |
|---|---|---|
| OneTrack 埋点 | `tracking.miui.com` 及 `.intl` `.india` `.rus` `.eu`、`staging.tracking.*`、`om.tracking.*`、`pn-tracking-bak.onetrack.mi.com` | **8/11 APK 引用** |
| 云控伴生端点 | `port.sec.miui.com`、`connect.rom.miui.com`、`preview-jupiter.sys.miui.com`、`unreleased.sys.pt.miui.com` | daemon、powerkeeper |
| MIUI 统计 | `data.mistat.xiaomi.com` 及 `.intl` `.india`、`test-idservice.data.mistat.xiaomi.com` | bugreport / powerkeeper / MSA |
| SDK 配置 | `sdkconfig.xiaomi.com` 及 `.intl` `.eu` `.rus` `.india` | analytics 为主 |
| 广告 | `api.ad.intl.xiaomi.com`、`log.ad.xiaomi.com`、`ad.game.hybrid.xiaomi.com` | analytics / hybrid |
| 反馈上报 | `feedback.miui.com` 及 `.intl` `.india` `.rus`、`bugreport.xiaomi.net` | bugreport |
| 智能助理 | `api.assistant.miui.com` | personalassistant / contentcatcher |

**明确不封**（实测命中，但属功能依赖）：`account.xiaomi.com` / `api.account.*`（登录）、
`api.xiaomi.com`（通用 API）、`file.market.xiaomi.com`（应用商店）、`*.micloud.xiaomi.net`（云同步）、
`*.amap.com` / `*.map.qq.com` / `*.map.baidu.com`（网络定位）、`*.mi-img.com`（图片 CDN）。
唯一例外是 `rttgpsreport.map.qq.com`——纯上报，已封。

### 2. 组件处置：按「打通道，不打宿主」逐项定级

| 包 | 证据 | 动作 | 代价 |
|---|---|---|---|
| `com.miui.daemon` | jupiter + ccc + port.sec + connect.rom | **uninstall**（PERSISTENT，disable 会被自愈） | `MiuiPerfService` 不可用 |
| `com.miui.analytics` | onetrack / tracking / sdkconfig | disable | 无 |
| `com.miui.systemAdSolution` | `api.ad.xiaomi.com`、`zeus.ad.xiaomi.com` | disable | 无（MSA 广告） |
| `com.xiaomi.joyose` | jupiter + api.ad | disable | 游戏加速 / 网络优化失效 |
| `com.miui.bugreport` | bugreport.xiaomi.net、feedback.*、mistat | disable | 无法在系统里提交反馈 |
| `com.bsp.catchlog` | **0 域名命中**（纯本地日志抓取） | disable | 无 |
| `com.miui.hybrid` | 211 个域名，快应用引擎 | disable | 快应用不能运行 |
| `com.miui.personalassistant` | data.sec + 大量第三方 | disable | 负一屏失效 |
| `com.xiaomi.metoknlp` | **全部是地图 SDK，无云控** | **保留** | — |
| `com.miui.contentcatcher` | micloud + 支付宝，**无云控** | **保留** | — |
| `com.miui.powerkeeper` | jupiter / ccc / mistat | **保留**（只封域名） | — |
| `com.android.updater` | 系统 OTA v7.6.8，常驻 pid 5929、30 个组件 | **uninstall**（用户点名） | 无法检查/下载系统更新 |

两个「保留」是本机与项目原有清单的主要分歧：

- **`powerkeeper` 必须留。** 卸载 daemon 后日志出现
  `can't bind to com.miui.daemon.performance.MiuiPerfService`，
  但紧接着 `PerfShielderService: Miui powerkeeper service connected!` ——
  性能调度是**通过 powerkeeper 接上的**。若连它一起关，性能调度才是真的裸奔。
  它引用的云控域名已全部封死，等于"宿主还在，通道已断"。
- **`metoknlp` 保留。** 11 个包中唯一一个域名全是高德/腾讯/百度 LBS 的，关掉直接影响无 GPS 时的定位速度与精度。它不是云控组件。

`com.android.updater` 卸载同时消除了「OTA 覆盖 boot 导致 Magisk 丢失」的风险，与 boot 已 patch 的事实相配套。

### 3. 预装清退：41 → 26

`pm list packages -3` 返回 41 个，与 `pm list packages -s` 交集是**空集**——全部落在 `/data/app/`，**没有一个用户自装**。
命名规律直接暴露来源：

| 前缀/后缀 | 含义 | 数量 |
|---|---|---|
| `partner-<pkg>_<N>` | 付费预装推广位（厂商付钱买的位置） | 8 |
| `<pkg>_<N>` | 普通预装推广 | 4 |
| `MIUI*` / `Mi*` / `com.miui.*` / `com.xiaomi.*` | 小米官方 | 26 |

清退 15 个（12 推广 + 谷歌联系人同步 + 2 输入法），剩 26 个。
全部 `pm uninstall --user 0`，回滚 `cmd package install-existing <pkg>`。

### 4. 云控载荷：桌面「推荐/热门」文件夹

`/data/data/com.miui.systemAdSolution/shared_prefs/CNCloudControlSettings.xml`
里就是「云控」在设备上的原样载荷：

```json
{"app_store_desktopfolder":{"isCloseAd":false,"isOpenXout":false,
 "preloadHotValue":2,"preloadRecValue":2,
 "queryType":"GetAdWithPageTurn","xOutProtectionInMillis":86400000},"code":0}
```

`preloadHotValue:2` / `preloadRecValue:2` 就是往「热门」「推荐」文件夹各塞 2 个推广位
——而文件夹里点开的 `全民小说` 在 `pm list packages` 里**根本不存在**，是个点下去才触发下载的假图标。

改成 `isCloseAd:true` / `preloadHotValue:0` / `preloadRecValue:0` 后重启桌面，
**两个文件夹直接消失**，第二页只剩钱包、米家、音乐、笔记、多看阅读 5 个真应用。

写文件**必须保 inode**，否则 SELinux context `u:object_r:app_data_file:s0:c512,c768` 会丢、应用读不到配置：

```bash
adb push new.xml /data/local/tmp/ccs.new
adb shell su -c 'cat /data/local/tmp/ccs.new > /data/data/com.miui.systemAdSolution/shared_prefs/CNCloudControlSettings.xml'
adb shell su -c 'rm -f .../CNCloudControlSettings.xml.bak'   # 不留 .bak，否则可能被回滚
```

用 `>` **原地覆盖**（inode 13134 前后一致），不要 `cp` / `mv`。

之所以改完能守住，是因为 `sdkconfig.ad.xiaomi.com` 早在黑名单里，MSA 拉不到新配置，只能读本地这份。

### 5. MSA 广告引擎与黑名单 75 → 80

`com.miui.systemAdSolution`（`/system/app/MSA/MSA.apk`）是开屏广告的调度中枢。
解 APK 得到的核心端点是 **`zeus.ad.xiaomi.com` / `zeus.ad.intl.xiaomi.com`**
—— 而这条主路径在原 75 条域名里**完全缺失**（`api.ad.*`、`log.ad.*`、`test.ad.*` 都在，唯独 zeus 漏了）。

禁用后的行为是**可验证的良性降级，而不是崩溃**：

```
E ActivityThread: Failed to find provider info for com.miui.systemAdSolution.adSwitch
```

调用方（实测 `com.android.thememanager`）去问 MSA「要不要弹开屏广告」，provider 已消失 →
走「无广告」分支 → 进程存活（`S` 状态），无 FATAL。
这正是期望路径：**广告请求在源头就没有决策者了。**

黑名单最终 78 → 80（补 `test.ad.intl.xiaomi.com`、`staging.sdkconfig.ad.xiaomi.srv`），
**80/80 全部解析到 `127.0.0.1`，0 条漏网**。用「审计名单 − 已封名单」求差集再筛广告特征词，结果为空。

Magisk 是把模块文件直接挂载到 `/system/etc/hosts` 的——改
`/data/adb/modules/miui_cloudblock/system/etc/hosts` 即等于改活文件，`ping` 立刻返回 `127.0.0.1`，
**不需要重启**。（`cp` 到 `/system/etc/hosts` 会报 `Read-only file system`，属正常，别被误导。）

### 6. root 隐藏：精确黑名单模式

| 项 | 值 |
|---|---|
| `zygisk` | 1（开启） |
| `denylist` | **0** —— Enforce DenyList 关闭，这是 Shamiko 进入黑名单模式的前提 |
| DenyList 内容 | `com.eg.android.AlipayGphone`、`com.ss.android.ugc.aweme`、`com.taobao.taobao`、`com.xunmeng.pinduoduo` |

> **`com.google.android.gms` 绝对不能进 DenyList。** 加了会让 Play 服务和 `playintegrityfix`
> 本身失效，反而降低完整性判定。

**怎么证明它真的在工作（而不是"装了就以为生效"）**：Shamiko 不写日志文件，
`ls /data/adb/modules/zygisk_shamiko/` 只证明模块被加载。可靠判据是 mount namespace：

```bash
PID=$(adb shell pidof com.eg.android.AlipayGphone)
adb shell su -c 'ls -l /proc/$PID/ns/mnt; ls -l /proc/1/ns/mnt'
```

| 进程 | mount namespace |
|---|---|
| 支付宝（pid 8229） | `mnt:[4026535000]` |
| init（pid 1） | `mnt:[4026534033]` |

两者不同 = Shamiko 已对目标应用 unshare 独立 mount namespace，`/data/adb` 在该进程里不可见。
同时验证：支付宝进程 maps 中 magisk 映射计数 = 0，主进程 + `:channel` 两个进程均正常运行。

包名隐藏改用 `pm hide`（这台 Magisk 没有官方的「隐藏 Magisk 应用」功能，见踩坑 ③）：

```bash
adb shell su -c 'pm hide com.topjohnwu.magisk'      # 隐藏
adb shell su -c 'pm unhide com.topjohnwu.magisk'    # 恢复
```

实测：`hidden=true`，`pm list packages | grep topjohnwu` 返回空，`su -c id` 正常，
3 个模块照常加载，`zygiskd64/32` 在跑。代价是 Magisk 图形界面从此打不开（`Activity class does not exist`），
但日常管理全部能走 adb：`magisk --denylist add` / `--install-module` / `--sqlite`。

### 验证结果（重启后实测）

| 项 | 结果 |
|---|---|
| hosts 条数 | `grep -c` = **80**（模块日志 `blocked=80`） |
| 新增通道解析 | `tracking.miui.com` / `tracking.intl` / `port.sec` / `data.mistat` / `sdkconfig` / `feedback` **全部 → 127.0.0.1** |
| IP 层 | `iptables -L OUTPUT -n` 第 1 条 `DROP → 61.148.212.26` |
| 禁用持久性 | 7 个包重启后仍 `disabled-user`，**无一自愈** |
| `com.miui.daemon` | `installed=false`，进程列表已无 |
| 相机 | `Number of camera devices: 10`，全部在线 |
| 指纹 | `Fingerprint21`，`HAL deaths since last reboot: 0` |
| 性能调度 | `MiuiPerfService` 仅启动时失败 2 次（不重试、不耗电），已由 powerkeeper 接管 |
| ANR | 无 |

## 踩过的坑

### ① `getprop` 不能用来判断 BL 状态（PIF 会伪造全部属性）

排查中出现过一次自相矛盾的证据链：与当天 12:49 的基线快照对比，
`ro.boot.flash.locked` 从 `0` 变 `1`、`ro.boot.verifiedbootstate` 从 `orange` 变 `green`、
`ro.secureboot.lockstate` 从 `unlocked` 变 `locked`——三条同时变，看起来像「BL 在 40 分钟内被重新锁定」。

但这与另一组事实冲突：boot 分区确凿是 Magisk-patched、vbmeta 分区实测 `FLAGS=0`、
原厂 RSA2048 签名未改。被改过的 boot + 未改的 vbmeta + 锁定状态，**三者不可能同时成立**。

按顺序排除了四层，全是阴性：

| 排查层 | 结果 |
|---|---|
| `/proc/cmdline` | 无任何 `verifiedboot` / `lock` 参数 |
| `/proc/bootconfig` | 空 |
| `/proc/device-tree/firmware/android/` | 只有 `compatible` / `fstab` / `name` / `vbmeta`，无 `verifiedbootstate` |
| `ps \| grep resetprop` | 无常驻进程 —— **但 resetprop 执行完即退出，这条阴性结果毫无意义** |

**决定性验证**：`adb reboot bootloader` 后 `fastboot getvar unlocked` → **`unlocked: yes`**。

真凶是 `playintegrityfix` 的 `service.sh` 在 `sys.boot_completed=1` 之后执行：

```sh
resetprop_if_diff ro.boot.flash.locked 1
resetprop_if_diff ro.boot.verifiedbootstate green
resetprop_if_diff ro.secureboot.lockstate locked
resetprop_if_diff ro.boot.vbmeta.device_state locked
resetprop_if_diff ro.boot.veritymode enforcing
```

它的 `post-fs-data.sh` 还会把 `ro.debuggable` 改成 `0`、`ro.build.tags` 改成 `release-keys`、
`ro.build.type` 改成 `user`、删除 `ro.boot.verifiedbooterror`。

> **结论：装了 PIF 的机器，`ro.boot.*` / `ro.secureboot.*` / `ro.debuggable` 一律不可信**，
> 包括看起来最"底层"的那几个。判断真实引导状态只有一个可靠途径：
> `adb reboot bootloader && fastboot getvar unlocked`。

### ② `fastboot boot twrp` 返回 OKAY 但停在 fastboot

镜像头 `os_version = 0xc75d27fc` 是垃圾值，被 MIUI bootloader 拒绝。
改为**先刷到 recovery 分区**（镜像 128 MB，正好等于分区 `0x8000000`）再 `fastboot reboot recovery`，
TWRP 3.7.1_12-0 正常启动。

### ③ Magisk 31.1 精简版根本没有「隐藏 Magisk 应用」功能

判据不是"界面上没看到"，而是查 APK 本体：

| 检查项 | 官方 Magisk | 本机 31.1 |
|---|---|---|
| APK 条目数 | 100+ | **77** |
| `assets/stub.apk` | 有（隐藏功能靠它重打包成随机包名） | **无** |
| 全包 `stub` 字符串 | 有 | **0 命中** |
| 设置页入口 | 有（位于「跟随系统」上方） | **无** |

功能代码根本不在包里，不是 UI 藏起来。`/data/adb/magisk/` 下也只有 11 项文件，无 `stub.apk`、无 `libbusybox.so`。

### ④ `pm hide` 必须 `su -c`

直接 `adb shell pm hide` 会抛
`SecurityException: Neither user 2000 nor current process has android.permission.MANAGE_USERS`。
`pm hide` 只影响 user 0，多用户设备需对每个 userId 分别执行；hidden 状态存
`/data/system/users/0/package-restrictions.xml`，重启保留。

### ⑤ boot 镜像不要从 ROM 包下载

官方 `bigota` 链路实测只有 **~20 KB/s**（走代理也一样），4.86 GB 需要约 **68 小时**，该路线直接放弃。
正确做法是从 TWRP 里 `dd` 出当前 `boot` 分区——这比从 ROM 包里取**更正确**，
因为 Magisk 补丁必须与正在运行的构建完全一致。

另外 Magisk 打补丁要走**应用内**路径而非 `boot_patch.sh`：脚本依赖 app 注入的
`PREINITDEVICE` / `BOOTMODE`，在 TWRP 里手工调用属不受支持用法，可能产出无法开机的镜像。

### ⑥ `enabled=0` 不是禁用

`dumpsys package` 里这些包大多显示 `enabled=0`。**`0` 是 `COMPONENT_ENABLED_STATE_DEFAULT`，
不是禁用**；禁用是 `3`（`DISABLED_USER`）。一开始按 `enabled=0` 判断"都已被禁"是错的。

### ⑦ 输入法陷阱：官方那个能绑定，但打不了中文

三个输入法全是第三方品牌（都被小米定制过）：`com.baidu.input_mi`（出厂默认）、
`com.iflytek.inputmethod.miui`、`com.sohu.inputmethod.sogou.xiaomi`（**唯一在系统分区的**）。

官方替代 `com.miui.securityinputmethod` 看起来完美：`ime set` 成功、
`mHaveConnection=true mBoundToMethod=true mActive=true`、进程也起来了。
**但它的 APK 里 `grep -icE 'pinyin|dict|zh_|chinese'` 结果是 0** ——
1.6 MB 的纯 AOSP LatinIME，没有中文引擎。只留它 = 只能打英文。

> `ime list -s` 不显示它，但 `enabled_input_methods` 和 `dumpsys input_method` 都证明它可用
> ——只看前者会误判"官方输入法不存在"。而「可用」和「能打中文」是两件事，必须拆开验证。

最终保留搜狗（系统分区，最接近"官方预装"），删百度 + 讯飞。
**删除顺序必须先 `ime set` 切默认，再删旧的**，否则中间会出现无输入法窗口。

### ⑧ 明确不装第三方 hosts 模块

BlockAdsNext / pantsufan/Magisk-Ad-Blocking-Module 之类，本质都是「用 OISD/AdGuard/AntiADChinese
列表覆写 `/system/etc/hosts`」。**这与本模块互斥**：第三方模块一旦自更新就会把我们的规则冲掉。

本机不再引入同类模块，从根上消除「谁拥有 hosts」的冲突，而不是事后对账。
若要扩量，正确做法是**把那些列表的域名合并进 `blocklist-tier1.txt`**，仍由 `build_module.sh` 单一来源生成。

### ⑨ 一次归因误判：6 个小米应用消失，其实是用户手动删的

14:00 → 14:09 之间，`pm list packages -3` 从 28 掉到 20，6 个小米官方应用消失
（多看阅读、多看免费小说、小米健康、收音机、换机、游戏中心）。

我看到「14:03 改云控 → 14:04 桌面重启 → 14:07 包消失」这条时间链，就编出了
「`preloadHotValue` 归零 → `com.miui.thirdappassistant` 回收预装位」的机制解释，还写进文档当成结论。
**实际上用户那几分钟正在桌面上长按卸载。**

真正的反证我一开始就拿到了，只是没读懂：`logcat` 三个缓冲里**完全没有** `PackageManager`
的 Uninstall / DELETE 记录。手动卸载走 launcher → PackageInstaller 流程，
与 `pm uninstall --user 0` 是两条不同路径——**查不到系统删除日志，恰恰说明不是系统在自动清理。**

> **教训 1：时间相关性 ≠ 因果。** 同一时段既有我的命令、又有用户在桌面上的操作时，
> 先问一句「这几个是不是你手动删的」，一句话就能省掉整段错误推理。
>
> **教训 2：缺失的证据也是证据。**「该有的日志没有」不是「日志丢了」，而可能直接否定因果链。
>
> **教训 3：别把用户的操作写进自己的故障单。** 一旦写进文档，后面每次排查都会被这条假因果带偏。

### ⑩ `notification_policy.xml` 不能手改

`/data/system/notification_policy.xml` 是 **ABX 二进制格式**（magic `ABX`，不是文本 XML），
手改会破坏结构、导致通知服务异常。解出来看过渠道清单：全是功能类（电池、关机时间、下载、短信、投屏、蓝牙…），
**没有任何"推广/广告"命名渠道**——这反过来印证停用 MSA/hybrid/personalassistant 之后，广告通知的注册源已不存在。

另外 `cmd notification` 没有按渠道禁用的子命令（只有 listener/push/dnd/bubbles），
所以「用 adb 批量关推广渠道」在 Android 12 上本来就走不通。

### ⑪ 开屏广告的最终视觉验证，必须你本人点一次「同意」

`monkey -p com.miui.video` 拉起小米视频后，弹出的是它自己的《用户协议》《隐私政策》确认框。
**自动点「同意」等于替你签一份第三方隐私协议，这件事不做。**
同理 `com.android.thememanager` 弹的是 MIUI「应用模式选择」（浏览模式 / 基础模式），也是隐私合规门。

### ⑫ 诚实的边界：完全去广告做不到

| 类型 | 状态 |
|---|---|
| 云控下发的桌面推广位 | **已断**（改 `isCloseAd` + `preload*Value=0`，文件夹物理消失） |
| 开屏广告（MSA / Zeus） | **已断**（MSA `enabled=3`，`zeus.ad.*` → 127.0.0.1） |
| 通知栏推广推送 | **已断**（MSA + hybrid 停用，渠道清单无推广渠道） |
| 快应用推广卡片 | **已断**（hybrid + hybrid.accessory 双停） |
| 负一屏信息流 | **已断**（personalassistant 停用） |
| **App 内推荐位**（应用商店首页、视频/音乐/天气/文件管理内嵌） | **未处理** —— 属各 App 自身内容流，不是系统广告链路；封域名或停组件会连带废掉功能 |

最后一行是诚实的边界：**在不动 App 功能的前提下，"完全去广告"做不到。**
把这一点说清楚，比假装已经做到了更有用。
