# OPPO A7 Pro Max（PYC110）

> 本系列第四台设备。**BL 不可解锁、全程无 root**，与第二台同属"只能靠 pm"的一侧；
> 但它是四台里工具链最受限的（ColorOS 在 PackageManagerService 里加了硬保护），
> 也是唯一一台**由用户一句话推翻我错误结论**的设备——见踩坑 ①。

## 型号参数版本

| 项 | 值 | 来源 |
|---|---|---|
| 品牌 / 型号 | OPPO `PYC110` = OPPO A7 Pro Max | `ro.product.model` + 工信部/SRRC/3C 认证 + Geekbench（2026-08-04 发布，08-07 开售） |
| SoC | `SM4850` = 骁龙 4 Gen 5（4 nm，2×2.4 GHz + 6×2.02 GHz，Adreno 629） | `ro.soc.model`；`ro.board.platform=malabar` |
| 系统 | ColorOS `V16.1.0` / `PYC110_16.0.9.409(CN01)` | `ro.build.display.id` |
| Android | **16**（SDK 36） | `ro.build.version.sdk` |
| 项目代号 | `25101` | `ro.boot.prjname` |
| 序列号 | `3B668N00PLU00000` | `ro.serialno` |
| 屏幕 | 1272×2772 @ density 560（override 636）→ 320×697 dp | `wm size` / `wm density` |
| 内存 / 存储 | 11.76 GB / 460 GB（已用 62 GB） | `/proc/meminfo` / `df` |
| Root | **无**。`ro.boot.verifiedbootstate=green`、`veritymode=enforcing`、SELinux Enforcing、`su` 不存在 | `getprop` |
| Bootloader | **不可解锁**，`ro.boot.flash.locked=1`、`vbmeta.device_state=locked`、`ro.oem_unlock_supported` **未设置**（AOSP 语义应为 1） | `getprop` |
| 包总数 | 409（第三方 48）→ 加固后 **397** | `pm list packages` |

### BL 为什么不可解锁（三条路径逐一排除）

**① 官方「深度测试」——不存在该机型通道。**
OPPO 官方名单止于 2021 年机型（Find X2/X3、Reno3–Reno6、Reno Ace/Ace2、R17/R15x、K1/K3/K5），
A 系列新机从未纳入。网络流传的「ColorOS 16 可申请深度测试」实为**一加 / realme 的公告**
（发布在一加社区、realme 圈），OPPO 品牌不在其列——这是最常见的误读来源。

**② 高通 9008 / EDL ——新平台无漏洞可用。**
`SM4850` 是 2026-05 发布的新平台，无公开签名 firehose。XDA（2026-01）确认 OPPO 新更新为
"patch + fuse" 组合（版本尾号 `.500/.501/.503`），既修漏洞又烧 ARB 熔断，一旦更新永久锁定且不可降级。

**③ 灰色付费「秒解」——不采用。** 对新平台基本无效，且存在 ARB 硬砖风险（只能返厂授权刷机）。

> `开发者选项 → OEM 解锁` 开关本机**已处于开启状态**，但它只表示"系统接受解锁请求"，
> bootloader 是否响应由厂商策略决定。该开关状态**不在 settings 表**（存于 FRP 分区 / persistent），
> adb 读不到，只能用截图确认。

### 开发者选项的两处缺失

`USB 调试（安全设置）` / `禁止权限监控`：**ColorOS 16 国行已整个删除**。
遍历 `global` / `secure` / `system` 三张 settings 表，`secure_debug|permission_monitor|disable_permission`
**零命中**。不是找不到，是 OPPO 移除。

## 目标

1. 去广告（系统广告 + 锁屏画报 + 桌面推荐位）
2. **卸载系统自动更新**
3. 约束条件：**不解锁 BL、不用 VPN、不依赖家庭 WiFi 的 DNS**

第 3 条是用户明确划的线——他曾直接指出：「我在外面，不连接家里这个 wifi，用移动网络，
不就没有用了。」这句话直接否掉了整个 DNS 方案的方向，见踩坑 ⑩。

## 已落地方案

### 1. 卸载 12 个（`pm path` 已无输出，包总数 409 → 397）

| 包 | 路径 | 作用 |
|---|---|---|
| `com.oplus.cota` | `/product/priv-app/Cota` | **OTA 下载客户端**（`COTA_DOWNLOAD`） |
| `com.oplus.upgradeguide` | `/system_ext/priv-app/UpgradeGuide` | 升级引导 / 升级后提示 |
| `com.oplus.statistics.rom` | `/product/priv-app/DCS` | 系统级统计上报 |
| `com.oplus.onetrace` | `/system_ext/app/OTrace` | 全链路埋点追踪 |
| `com.oplus.beaconlink` | `/product/app/BeaconLink` | 信标 / 场景感知上报 |
| `com.oplus.contentportal` | `/product/priv-app/ContentPortal` | 内容分发门户（信息流） |
| `com.heytap.mcs` | `/product/app/Mcs` | 欢太推送通道 |
| `com.oplus.deepthinker` | `/product/app/DeepThinker` | 用户画像 / 智能推荐引擎 |
| `com.oplus.athena` | `/system_ext/app/Athena` | 系统资源调度 |
| `com.oplus.appplatform` | `/product/app/AppPlatform` | 应用平台中间层 |
| `com.oplus.lfeh` | — | 预装服务组件 |
| `com.oplus.games` | `/product/app/Games` | 游戏中心 |

### 2. 冻结 5 个（`suspended=true`）

| 包 | 作用 |
|---|---|
| `com.opos.ads` | **OPPO 广告 SDK**（对标小米 MSA），v3.8.0 |
| `com.heytap.pictorial` | **锁屏画报广告**，v40.10.6.2 |
| `com.heytap.tas` | 广告投放 / 归因组件 |
| `com.nearme.instant.platform` | 快应用框架（广告落地页载体） |
| `com.oplus.romupdate` | ROM 更新校验 |

### 3. 系统自动更新：包卸不掉，但整条链被切断

`com.oplus.ota` 本身受硬保护（见踩坑 ②），但**每一个依赖环节都断了**，并且拿到了一个持久化冻结：

| 环节 | 状态 |
|---|---|
| `com.oplus.cota`（下载客户端） | **已卸载** |
| `com.oplus.romupdate`（ROM 校验） | `suspended=true` |
| `com.oplus.upgradeguide`（升级引导） | **已卸载** |
| `com.oplus.ota`（OTA 主模块） | **`stopped=true`** + 进程不复活（10 s 内 0 残留） |
| `com.oplus.sauhelper`（应用自动更新助手） | `disabled-user` |
| `init.svc.cotad` / `cotad-boot` | `stopped` |
| `ota_disable_automatic_update` | `1` |
| `can_update_at_night` | `0` |
| `update_site_data` | `null` |

**关键手法**：`am force-stop` 在受保护系统应用上会产生**持久化的 `stopped=true`**
（写入 `/data/system/packages.xml`，重启后保持）。处于 stopped 状态的应用**收不到任何广播、
不会被隐式 Intent 拉起**。这是免 root 条件下对硬保护包唯一有效的手段。

> 局限：若某个系统服务用**显式组件名**启动 OTA，`stopped` 仍会被打破。
> 实测 10 秒观察窗口内未复发，但未做数天级的长观察。

### 4. 设置项强化

| 动作 | 命令 | 验证 |
|---|---|---|
| 关闭桌面文件夹推荐位 | `settings put secure folder_content_recommend_support {...folderRecommendEnable:0...}` | 回读 0；文件夹「常用应用」5 应用无推荐卡片 |
| 关闭预装应用默认授权 | `settings put secure default_grant_for_preload_app 0` | 回读 0 |

> 因果说明：文件夹推荐位改动**没有改动前截图**，因此"闭合"程度为「一致但未完全闭环」。

### 5. 验证

| 项 | 结果 |
|---|---|
| 包总数 | 397（差值 12，与卸载清单逐一对上） |
| 界面 | 桌面截图正常，壁纸/图标/状态栏无异常，无报错弹窗 |
| `sys.boot_completed` | 1 |
| crash buffer `FATAL EXCEPTION` | **0**（日志里那几条是 2 月/11 月的旧记录，`avf_qcvm_manager` 是高通虚拟机管理进程，与本操作无关） |

### 6. 回滚

`rollback.sh` 覆盖全部改动，`bash -n` 通过：

```bash
pm install-existing --user 0 <12 个包>     # 装回
pm unsuspend --user 0 <5 个包>             # 解冻
pm enable --user 0 com.oplus.sauhelper
monkey -p com.oplus.ota ... 1              # 显式拉起以清除 stopped 标志
settings put ...                           # 恢复三项设置
```

## 踩过的坑

### ① 以偏概全：我用一个包的五次失败，否定了 12 个本可卸载的包

**这是四台设备里最该记住的一条。**

最初只测 `com.oplus.ota` 一个包：`pm uninstall` → `DELETE_FAILED_INTERNAL_ERROR`、
`pm suspend` → `new suspended state: false`、`pm disable-user` → `new state: default`、
`pm clear` / 组件 disable / `cmd appops set` 全部 `SecurityException`。
连着五次失败后，我写下结论：「ColorOS 16 对系统包拦截卸载，**唯独 `pm suspend` 未被门禁覆盖**。」

**这个结论是错的。** 用户追问「卸载对应软件/服务，不行吗？」之后改为逐包实测，结果完全不同：

- `pm uninstall --user 0` 对大量 OPPO 包**直接成功**（12 个）
- `pm disable-user` 对部分成功（`com.oplus.sauhelper` → `disabled-user`），对另一部分被静默降级为 `default`
- `pm suspend` 对第三批成功，对受保护包返回 `new suspended state: false`

**门禁是逐包差异的，不是全局策略。不能预设某个机制会失败，必须逐包实测。**

### ② 硬保护的根因：OPPO 在 PackageManagerService 里写死了一个类

`pm clear com.oplus.ota` 抛出的栈直接暴露答案：

```
java.lang.SecurityException: adb clearing user data is forbidden.
  at com.android.server.pm.OplusClearDataProtectManager.interceptClearUserDataIfNeeded(OplusClearDataProtectManager.java:123)
  at com.android.server.am.ActivityManagerServiceExtImpl.hookInterceptClearUserDataIfNeeded(ActivityManagerServiceExtImpl.java:905)
  at com.android.server.am.ActivityManagerService.clearApplicationUserData(...)
  at com.android.server.pm.PackageManagerShellCommand.runClear(...)
```

`OplusClearDataProtectManager` 是 **OPPO 硬编码的保护类**（`Oplus*` 前缀、`*ExtImpl` 命名 = OPPO 对 AOSP 的注入点）。
保护名单**不在 settings 表里**，adb 没有写入口。

受保护的包（六种机制全败：uninstall / suspend / disable-user / clear / 组件 disable / AppOps）：
`com.oplus.ota`、`com.oplus.sau`、`com.oplus.cosa`、`com.oplus.olc`、`com.heytap.browser`、
`com.heytap.market`、`com.heytap.themestore`、`com.heytap.quicksearchbox`、`com.coloros.assistantscreen`。

> **方法论**：失败的错误码比失败本身更有信息量。`DELETE_FAILED_INTERNAL_ERROR` 只告诉你"PM 内部拒绝"，
> 而 `pm clear` 的 Java 栈直接点名了拦截类——后者才是根因。

### ③ 一个伪线索：`unimportant_exemption`

`settings list global` 里有一行 `unimportant_exemption=com.oplus.ota`，看起来像"豁免名单"，
很像 suspend 被拒的原因。实测 `settings delete global unimportant_exemption` **成功**（回读 `null`）后，
`suspend` 仍被拒——**不是它**。

附带收获：`settings delete` 能成功，证明 shell **确实有写 global 命名空间的权限**，
所以"权限不够"这个解释从一开始就不成立。

### ④ `pm suspend` 被拒时不会报错

对受保护包执行 `pm suspend`，返回的是 `Package xxx new suspended state: false`——
**退出码 0、不抛异常，只是状态没变**。如果只看"命令执行成功"就会误判为已冻结。
必须回读 `dumpsys package` 的 `suspended=` 才算数。

同理 `pm disable-user` 会返回 `new state: default`（静默降级，不是 `disabled-user`）。
**判断依据永远是 `dumpsys` 回读，不是命令的返回文本。**

### ⑤ `stopped=true` 是被严重低估的免 root 冻结手段

卸不掉 `com.oplus.ota`，改用 `am force-stop` 后拿到 `stopped=true`。
它比 suspend 更"硬"：写入 `/data/system/packages.xml`，重启保持，
且**不受包保护名单限制**（因为 force-stop 是 AM 层操作，不走 PM 的删除/冻结路径）。

清除方式：显式启动一次该应用（`monkey -p <pkg> ... 1`）即可。

### ⑥ Private DNS 严格模式会让整机断网

配 `private_dns_specifier=p2.freedns.controld.com` 时，`nc -z -w 4 host 853` 返回 rc=0，
看起来端口通。但配置后 `baidu.com` / `qq.com` / `taobao.com` **全部 `unknown host`**，
系统弹窗：「指定私人 DNS 服务器连接失败，当前无法连接网络。」

**根因**：`private_dns_mode=hostname` 是**严格模式**——DoT 握手失败时**不会回退**到明文 DNS，
而是整体解析失败。立即回滚（`private_dns_mode=off` + `specifier=null`）后，`ping baidu` 恢复 102 ms。

### ⑦ `nc -z host 853` 只证明 TCP 可达 ≠ DoT 可用

必须验证 TLS：`openssl s_client -connect host:853 -servername host`。
另外 Android 的 `sh` **不支持 `/dev/tcp`**，`echo > /dev/tcp/host/port` 对**所有**主机都返回 rc=1，
用它测端口会得到 100% 假阴性。

> 另外一个自查坑：`openssl s_client -verify_return_error` 报
> `unable to get local issuer certificate (num=20)` 时，先看 `-showcerts` 是否输出了完整链
> ——本次输出 3 张证书、链是完整的，错的是**本机 openssl 缺 CA bundle**，不是服务器缺陷。

### ⑧ OneDNS 连得上、不断网，但根本不拦广告

`dot.onedns.net` 是唯一 TLS 1.3 握手成功且配置后不断网的（证书 CN=`*.onedns.net`，北京微步在线）。
但实测：

| 域名 | 结果 |
|---|---|
| `doubleclick.net` / `googleadservices.com` / `applovin.com` | **返回真实 IP** |
| `gdt.qq.com` / `api-access.pangolin-sdk-toutiao.com` | **返回真实 IP** |
| `ulog.umeng.com` | 被拦（仅此一个） |

异常点：`gdt.qq.com` 和穿山甲域名都返回 `42.236.73.28`，ipinfo.io 识别为 AS4837 中国联通河南郑州
——这是**运营商侧 DNS 污染**，不是广告拦截。

### ⑨ 反直觉：AdGuard 的 DoT 不通，但明文 53 通

| 端点 | 结果 |
|---|---|
| `94.140.14.14:53`（AdGuard 明文） | `nc -z` rc=0 ✅ |
| `76.76.2.0:53`（ControlD 明文） | rc=0 ✅ |
| `52.80.66.66:53`（OneDNS 明文） | 不通 |
| `dns.adguard-dns.com:853`（DoT） | 不通 |

用 `Resolve-DnsName` 验证 AdGuard 明文 DNS 的返回：

| 域名 | 返回 |
|---|---|
| `doubleclick.net` / `googleadservices.com` / `applovin.com` / `ad.doubleclick.net` | `0.0.0.0` |
| `baidu.com` / `qq.com` | 正常解析 |

**这条路在移动数据下同样有效**，不受"只在家用 WiFi"限制。但 Android 的系统级 DNS 是**按网络**配置的，
`cmd wifi` 没有静态 DNS 子命令（42 个子命令全查过），落地只有两条：
WiFi 建议静态 IP + DNS1，或第三方 App（走本地 VPN——已被用户排除）。所以本轮**不采用**。

### ⑩ 用户一句话否掉了整个 DNS 方向

我把"NAS 自建 AdGuard Home + 手机静态 DNS"当作可行方案提出，用户回：
**「我在外面，不连接家里这个 wifi，用移动网络，不就没有用了。」**

这个反驳是对的。内网 DNS 只在一个 SSID 内生效，而绝大多数使用场景在移动数据下。
**方案的价值必须按"最常用场景"评估，不是按"技术上可行"评估。**
后续所有 DNS 尝试（含上面 ⑨ 的明文 DNS）都降级为"记录在案、不推荐"。

### ⑪ 工具链坑（Git Bash + adb）

| 现象 | 原因 / 解法 |
|---|---|
| `adb shell uiautomator dump /sdcard/ui.xml` 写到了 `D:/…/PortableGit/sdcard/ui.xml`，`adb pull` 报 No such file | Git Bash 把 Android 绝对路径改写成 Windows 路径。**所有 `adb shell` 绝对路径命令都要加 `MSYS_NO_PATHCONV=1`** |
| `df -h /data` 报 `/data` 不存在 | 同上 |
| `getprop a b c` 报 `Max 2 arguments` | 一次只能查一个 key，写循环 |
| `uiautomator dump` + `adb pull` 偶发 `FileNotFoundError` | 竞态：pull 静默失败。dump 与 pull **两处**都要加 `MSYS_NO_PATHCONV=1`，且 pull 后先 `ls -l` 再解析 |
| 截图管道到 `/tmp` 后 `ViewImage` 找不到 | 写到工作目录，用 Windows 绝对路径 |

### ⑫ `screenrecord` 被 ColorOS 策略拦，不是权限问题

`screencap` 与 `touch` 写同一目录正常，但 `screenrecord` 报 `Unable to open '/sdcard/t.mp4': Permission denied`，
换 `/data/local/tmp/` 同样被拒。**结论是 ColorOS 16 对录屏的策略限制，不是文件系统权限问题**——
不要在这上面浪费时间去改权限。

### ⑬ 相关发现清单（供后续机型参考）

`com.oplus.sau` = **SystemAppUpdateService（系统应用自动更新）**，`com.oplus.sauhelper` 是它的助手。
这是「系统自动更新」的**第二条链路**，与 OTA 相互独立，很容易漏。
`com.oplus.olc` / `com.oplus.athena` / `com.oplus.cosa` 分别为日志采集、资源调度、广告归因。
