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
| 安全补丁 / 内核 | `2026-07-01` / `6.12.58-android16-6-g7704a1ae279b-ab15213644-4k`（构建于 2026-04-15） | `ro.build.version.security_patch` / `uname -a` |
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

### 7. 未成年人模式：只能关停，不能卸载

**先说结论：ColorOS 16 的「未成年人模式」没有独立 APK，它是框架里的一个模式开关。**
任何"找到那个包卸载掉"的思路都走不通，见踩坑 ⑭。

已落地的两步（都可回滚）：

| 动作 | 命令 | 回读结果 |
|---|---|---|
| 关开关 | `settings put secure minors_mode 0`<br>`settings put secure minors_mode_disable_multiapp 0` | `0` / `0` |
| 停用承载 UI 的包 | `pm disable-user --user 0 com.coloros.digitalwellbeing` | `enabled=3`（disabled-user） |

承载模块的定位证据：

```
com.coloros.digitalwellbeing   16.6.6   /product/app/DigitalWellBeing
  com.coloros.minorsmode.ui.LauncherActivity
  com.coloros.minorsmode.ui.MinorsSettingsActivity
  Intent  com.android.action.ENTER_MINORS_MODE / EXIT_MINORS_MODE
          com.android.action.PARENTAL_CHILD_MANAGEMENT
```

验证：

| 项 | 结果 |
|---|---|
| `am start -a com.android.action.PARENTAL_CHILD_MANAGEMENT` | `unable to resolve Intent` |
| `am start -n .../minorsmode.ui.LauncherActivity` | `Error type 3 ... does not exist` |
| 设置首页滑到底部 | 已无该入口（截图确认） |
| 设置进程 | 存活 3 个，无 FATAL、无 `ActivityNotFound` |
| 其他 App 的联动 | 日志里 `PackageObserver` 正确收到 `enabled=false` |

**回滚**：`pm enable --user 0 com.coloros.digitalwellbeing` + 两个 settings 写回 `1`。

**删不掉的残留**（这是它属于框架的直接证据）：

```
dumpsys settings 里的观察者注册记录：
  setting: minors_mode generation:2
  setting: minors_mode_enabled generation:1
  setting: minors_mode_install_type generation:1
  setting: minors_mode_age_range generation:1
  setting: forbid_splitscreen_by_ep generation:1
```

`generation` 是 SettingsProvider 的观察者计数——**有系统侧代码注册了监听**，
所以即使包被停用，`minors_mode` 仍会被框架读取。开关为 `0` 时它不产生约束，但这段代码删不掉。

另一个连带发现：`secure/no_frozen` 这份"免冻结豁免名单"里有 `com.coloros.familyguard`，
但 `pm list packages -f` 里**根本不存在这个包**——是一枚陈旧条目。

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

### ⑭ 「未成年人模式不是一个 App」——按包名找是错的起手式

第一反应是 `pm list packages | grep -iE "minor|teen|youth|child|kid"`，结果**零命中**。
命中的只有 `com.coloros.securityguard`、`com.oplus.eyeprotect`、`com.oplus.keyguard.*`、
`com.oplus.qualityprotect`、`com.coloros.remoteguardservice`——全是无关的（护眼、锁屏、质量保护）。

如果就此收工，会得出"这台机器没有未成年人模式"的错误结论。真正的入口在**设置表**：

```bash
settings list secure | grep -iE "minor|teen"     # ← 一步命中
# minors_mode=1
# minors_mode_disable_multiapp=1
```

再回到包管理器按 `minorsmode` 关键词找**组件**（不是包名），才定位到
`com.coloros.digitalwellbeing` 里的 `com.coloros.minorsmode.ui.*`。

**方法论**：ColorOS 把大量功能实现为"通用宿主包 + 功能子模块"，
`minors_mode` 这种**模式类**功能尤其如此。查一个功能是否存在，顺序应该是
**设置表 → 组件名 → 包名**，而不是反过来。`pm list packages` 只覆盖第三层。

顺带一条：`settings put` 写入被接受不代表有人响应。本次写 `0` 之后
logcat 里**没有任何进程产生反应**（只有 `SettingsShellCmd` 自己的落库日志），
这也反过来证明它就是纯开关、没有常驻监听者。

### ⑮ 用 `service call` 手搓 Parcel：三个「看起来能用」的写法全是错的

想把一个事件名塞进 native binder 服务，连错三次，每次的错法都很典型：

| 写法 | 现象 | 根因 |
|---|---|---|
| `service call X 2 s16 android.atlas.service s16 <name>` | 日志里事件名只剩 `a` | 这个服务不读 interface token，多传的一个字段被当成 name；而且 String16 被 `readString8` 读，遇第一个 NUL 就断 |
| 把 2 个 ASCII 字节打包进 1 个 UCS-2 字符（寄望 `writeString16(N 字符)` 在 `readString8(N 字节)` 后还原） | **一条日志都没有** | 长度字段对不上，Parcel 直接判损坏，在进函数之前就返回了 |
| 用 `i32` 铺字节，但 value 字段紧接 name 之后 | name 和 value 一起变空 | `readString8` 读完 len 字节后按 `PAD(len+1,4)` 前进，差 4 字节整体损坏 |

**方法论**：`service call` 的参数类型表（`i32/i64/f/d/s16/null/fd/nfd/afd`）里没有 `s8`，
但 `i32` 足够——它可以按 4 字节粒度铺出任意字节流，比任何「编码技巧」都可靠。
真正要先弄清楚的是**读侧怎么算位置**：`readString8` 是 `len` + `PAD(len+1,4)`，
`readString16` 是 `len` + `PAD(2len,4)`，两者不一样，混用就必错。

判断某个 code 是不是目标方法，用「有日志 / 无日志」不够可靠（可能被限流），
最稳的是对照实验：一个必然存在的小 code 返回 `Parcel(NULL)`，
一个超范围 code 返回 `Parcel(Error: 0xffffffffffffffb6 "Not a data message")`。

### ⑯ 最贵的一课：卸掉 `com.oplus.appplatform`，整台机器进崩溃死循环

上一轮把 `com.oplus.appplatform` 当成"OPPO 应用平台"卸了。后果不是"少个功能"，是**SystemUI 起不来**：

```
java.lang.SecurityException: Failed to find provider
  com.oplus.customize.coreapp.configmanager.configprovider.AppFeatureProvider for user 0
    ← com.android.systemui   (FeatureOption.init → registerContentObserver)
    ← com.oplus.subsys       (SubsysContentObserverManager)
    ← com.android.packageinstaller
```

三件事要记牢：

1. **authority 前缀骗人。** 名字是 `com.oplus.customize.coreapp....`，但真正的宿主是
   `com.oplus.appplatform`——它在自己的 `AppFeatureProvider` 上挂了一条**别名 authority**。
   所以「按包名前缀找宿主」是错的。正确做法是 `dumpsys package | grep <authority>`，
   输出里的 `[xxx]:` 方括号段就是别名注册。
2. **`pm list packages -u` 是必查项。** 拿它减掉 `pm list packages`，差值就是"卸了但可恢复"的包，
   `pm install-existing --user 0 <pkg>` 一键复原。本次差集 12 个，`appplatform` 就在里面。
3. **`install-existing` 会保留原来的 enabled 状态。** 复原后 `pm list packages -d` 里还有它，
   必须再补一条 `pm enable --user 0`。

同理 `com.oplus.athena`（智能引擎）也不能卸——日志里会持续刷
`OplusAthenaAm: AthenaService internal not found, max try times`，一堆调用方在空转重试。

**结论：`com.oplus.appplatform` / `com.oplus.athena` / `com.oplus.customize.coreapp` 列入不可装卸白名单。**

### ⑰ `pm disable-user` 被静默拒绝时，`pm suspend` 往往还能过

第 ④ 条只说了 suspend 被拒时不报错，反过来也成立且更有用：

| 包 | `pm disable-user` | `pm uninstall --user 0` | `pm suspend` |
|---|---|---|---|
| `com.opos.ads` | `new state: default`（拒） | `DELETE_FAILED_INTERNAL_ERROR` | **成功** |
| `com.heytap.pictorial` | 同上 | 同上 | **成功** |
| `com.heytap.tas` | 同上 | 同上 | **成功** |
| `com.nearme.instant.platform` | 同上 | 同上 | **成功** |
| `com.oplus.ota` / `com.oplus.sau` | 拒 | 拒 | 拒 |
| `com.oplus.olc` | 拒 | 拒 | 拒 |

判据很简单：**`new state: default` 就是被拒**（成功会打印 `disabled-user`）。
所以处理硬保护包要按 `disable-user → uninstall → suspend` 三级降级跑，不能只试一种。
`com.oplus.ota` / `com.oplus.sau` / `com.oplus.olc` 属于三级全拒，只能放弃。

### ⑱ adb 安装被 OPPO 拦死：一条完整的因果链

`pm install` 会**永久挂住且无任何输出**（不是失败，是不返回）。实测链条：

```
pm install-commit <sid>  ──挂死──>
  dumpsys package 显示会话 committed 但 appPackageName=null（连解析都没到）
  logcat 只有一行就停：
    D OplusPackageInstallInterceptManager: installStage send adb install pkg:xxx
    D PackageManager: installStage allowInterceptAdbInstallInInstallStage pkg:xxx
```

从 `oplus-services.jar` 里挖出的实现细节（`com.android.server.pm.OplusPackageInstallInterceptManager`）：

- 内部类 `$Receiver` / `$OplusAdbInstallerEntry` / `$FileObserverPolicy`
- 状态文件 `/data/oplus/os/config/adb_installer_status.xml`（root 独占，shell 读不了）
- 属性 `persist.sys.adb_install_disable`（本机为空 = 未禁用，所以不是它挡的）
- 特性开关 `oplus.software.pms_adb_session_installer_intercept` —— 属于
  `OplusFeatureConfigManager` 的**编译期特性**（整张表按字母序排列，不可运行时改）

旁路尝试与结果：

| 尝试 | 结果 |
|---|---|
| `cmd package install-create/write/commit` | create/write 成功，commit 挂死 |
| `-i com.heytap.market` 冒充商店安装 | 无效，拦截认 `INSTALL_FROM_ADB` 标志 |
| 重启设备 | 无效 |
| 恢复 `athena` / `appplatform` | 无效（但修好了 SystemUI） |
| `settings put global install_non_market_apps 1` | 无效（已为 1） |
| `am start -a INSTALL_PACKAGE -d file://...` | 解析不到，安装器只认 `content://` |
| `am start -a VIEW -d content://media/external/file/<id>` | `InstallStart` 起来即 `checkFinished=true`，不转发 |
| `am start -n .../.PackageInstallerActivity` | `not exported from uid 10141` |
| `appops set com.android.shell REQUEST_INSTALL_PACKAGES allow` | shell 无 `MANAGE_APP_OPS_MODES` |

**当时的结论：这台机器在没有 root 的前提下装不了 APK，只能人工在手机上点开文件安装。**
（`/sdcard/Download/` 放好 apk，用「文件管理」点开即可——那条路的调用方是文件管理器，
不是 shell，能过来源校验。）

> ⚠️ **此结论已于 2026-11-14 晚被推翻**，见坑⑲。真正的原因是 ColorOS 的「权限监控」
> 在拦，不是那个编译期特性。关掉权限监控后 `pm install` 直接 `Success`，
> 上面 9 条旁路一条都不需要。

---

### ⑲ 真正的总闸门：ColorOS 16 把「权限监控」藏进了英文界面

这是本机所有怪现象（adb 装不了 APK、Shizuku 报 adb 权限受限、部分 `pm` 操作被静默拒绝）
的**同一个根因**，也是本轮最大的发现。

**症状**：Shizuku 服务端起来了（`shizuku_server` 在跑），界面却报红：

```
您需要进行额外的步骤
您的设备制造商限制了 adb 的权限，使用 Shizuku 的应用无法正常工作。
通常，在"开发者选项"中调整一些选项即可解除此限制。
```

Shizuku 官方 FAQ 对 ColorOS 的说法是「在开发者选项里关闭『权限监控』」。
**但本机（Android 16 / ColorOS 16.1 / `PYC110_16.0.9.409`）的开发者选项里根本没有这一项**
——我把整页从顶翻到底逐条 dump 过，`调试` 段只有：USB 调试 / 撤消授权 / 无线调试 /
停用 adb 授权超时 / 视图属性检查 / 选择调试应用 / 等待调试程序 / 通过 USB 验证应用 /
验证可调试应用的字节码 / 日志缓冲区 / 功能标记 …，**没有「权限监控」，也没有任何同义项**。

**社区解法**（CSDN + 金舟，两个独立来源一致）：ColorOS 16 **隐藏了该项但没删**，
中文界面看不到，切英文后会以 **`Disable system optimization`** 的名字出现在开发者选项。

**更轻的落地方式**（不用改系统语言，只改 Settings 一个应用）：

```bash
# Android 13+ 支持 per-app locale，只让「设置」用英文渲染
adb shell cmd locale set-app-locales com.android.settings --user 0 --locales en-US
adb shell am force-stop com.android.settings
adb shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS
# 英文界面下翻到底部 → "Disable system optimization" → 打开 → 确认框点 "Turn on anyway"
# 完事后恢复中文
adb shell cmd locale set-app-locales com.android.settings --user 0 --locales zh-CN
```

开关本身的位置与文案：

| 项 | 值 |
|---|---|
| 英文名 | `Disable system optimization` |
| 摘要 | `Turning this on may increase background power usage.` |
| 确认框标题 | `Proceed with caution` |
| 三条警告 | Increased power consumption / System features may be affected / Reduced security protection |
| 确认按钮 | `Turn on anyway` |
| 中文界面 | 该行**不显示**（状态保留，切回中文也生效） |

**开了之后立刻发生的变化（实测）**：

| 动作 | 开之前 | 开之后 |
|---|---|---|
| `pm install -r /data/local/tmp/hail.apk` | 永久挂死无输出 | **`Success`** |
| `pm install -r .../shizuku.apk` | 同上 | **`Success`** |
| 拦截器日志 | 停在 `installStage send adb install` | `installStage send adb replace install, **silent**`（放行） |
| Shizuku 界面 | 红字「adb 权限受限」，版本显示错误的 13.0 | 「正在运行 版本 13.5, adb」，红字消失 |
| `pm disable-user com.oplus.ota` | `new state: default` | 仍 `default`（**这条没解**，属另一套保护名单） |

→ 坑⑱ 里那 9 条安装旁路**全部不需要了**。根因从来不是编译期特性，是运行期的权限监控。

**它的状态存哪**：不在 `settings` 的 global/secure/system 三张表里（开启前后做了全量 diff，
只有时间戳类字段变化），和坑⑱ 挖到的 `/data/oplus/os/config/adb_installer_status.xml` 同处，
`/data/oplus/os/config/` 对 shell 是 `Permission denied`。所以想脚本化只能靠上面的 UI 操作，
或者日后拿到 root 再直接写文件。

**副作用与回滚**：ColorOS 部分系统界面会变成原生安卓样式，耗电略增，安全防护降低。
回滚就是把 `Disable system optimization` 关掉（同样需要英文界面才能看到）。
社区与实测都确认**状态跨重启保留**。

> 雷区提醒：不要因为"反正都关了"就去动 `com.oplus.safecenter` / `com.coloros.securityguard`
> ——安全中心在 Android 15+ 冻结后会异常；`com.oplus.subsys` / `com.oplus.appplatform` /
> `com.oplus.athena` / `com.oplus.customize.coreapp` 更是整机级地雷（见坑⑯）。

---

## 附：临时 root 可行性调研（2026-11，A 线已实测执行）

目标：在**不解 BL、不刷机、不依赖 PC 常驻**的前提下拿一次 root。
以下四条路线全部来自公开渠道（XDA / CVE 库 / 研究者博客 / 酷安转载），按可行性排序。

**执行结论先行**：A 线已实测跑通到「拉起 root 进程」，但**没有拿到任意命令执行**；
B/C/D 三条在动手前就被本机条件排除（见各节）。

### 结论摘要

| # | 路线 | 前置条件 | 本机可行性 | 结论 |
|---|---|---|---|---|
| A | CVE-2026-70386 `AtlasService` → `audiodumpinfo` | 只需一个 binder 调用 | 触发链完整打通，终点是 root 进程启动 | **已实测，半通（见 A-1～A-4）** |
| B | CVE-2026-43499 futex PI UAF（GhostLock） | 需 boot.img 提内核偏移 + NDK 编译 | 内核 `6.12.58` 不在偏移表 | 可做但工作量大 |
| C | GBL / `fastboot oem set-gpu-preemption` SELinux 降级 | 需 fastboot + 特定 SoC | `SM4850` 是否受影未知 | 不确定 |
| D | 各种「一键 root 工具箱」/ 提权助手 App | 多数要**先解 BL 刷 init_boot** | 不成立 | 排除 |

### A. CVE-2026-70386（唯一在本机拿到实证的一条）

官方描述要点：`atlasservice` 的 `setEvent(String8 name, String8 value)` 对任意调用方**不做鉴权**（CWE-862）；
名字为 `atlas_event_multimedia_audio_dumpsys` 的事件处理器把调用方传入的 value 原样写进系统属性
`oplus.audio.dumpinfo.type`，随后拉起 root init 服务 `audiodumpinfo`，后者把该属性**未净化**交给 `system()`
（CWE-78）。最终以 `uid 0` 在 `u:r:dumpstate:s0` 域执行任意命令。CVSS 4.0 = **8.5**。
官方给出受影响区间：`16.1.0 < 16.1.10.500`、`16.0.0 < 16.0.5.1200`、`15.0.0 < 15.0.0.2000`。

本机实测到的零件（**全部为只读检查**）：

```
service list  → 0   AtlasService: [android.atlas.service]
ps -A         → 2136 root  atlasservice          ← 宿主进程就是 root
getenforce    → Enforcing
```

`/system_ext/etc/init/audiodumpinfo.rc`（本机实读，177 字节）:

```
service audiodumpinfo /system_ext/bin/audioDumpInfo
    class main
    user root
    group root system everybody sdcard_rw
    seclabel u:r:dumpstate:s0
    disabled
    oneshot
```

`/system_ext/lib64/libatlasservice.so` 里能直接读到完整链条的字符串：

| 偏移 | 内容 |
|---|---|
| `0xdde1` | `atlas_event_multimedia_audio_dumpsys` ← 触发事件名 |
| `0xde94` | `oplus.audio.dumpinfo.type` ← 中转属性 |
| `0xdf56` | `audiodumpinfo` ← 要拉起的 init 服务 |
| `0xe11b` | `ctl.start` ← 拉起方式 |
| `0xc8c0` | `start audio dump info, mDumpType:%s` |
| `0xcb46` | `dumpsys media.audio_policy` ← 正常业务命令 |
| `0xe024` | `isParamInvalid` ← 过滤函数 |

符号表里同时存在 `android::AtlasService::setEvent(String8 const&, String8 const&)`、
`android::OplusAtlasLogWriter::handleEvent(...)`，且导入了 libc 的 `system`。

两个反向验证（说明为什么必须借 `atlasservice` 代写）：

| 尝试 | 结果 |
|---|---|
| `setprop oplus.audio.dumpinfo.type id` | `Failed to set property ...` ← 属性受保护 |
| `timeout 5 /system_ext/bin/audioDumpInfo` | `Permission denied`，exit 126（`/system_ext/bin` 是 `drwxr-x--x root shell`，只有 x 无 r） |

**为什么原来只停在调研**（以下三条在动手前成立，动手后第 1、2 条已被实测推翻/修正）：

1. ~~没证明 `isParamInvalid` 的过滤强度~~ → 已反汇编，见 A-1 卡点 4：**只是 5 个字符的黑名单**，漏了换行和 `>`。
2. ~~`system()` 那一步是推定~~ → 已确认 `system()` 存在且被调用，但 12 个调用点没有一处吃事件参数，见 A-3。
3. 拿到的是 `u:r:dumpstate:s0` 的 root，**不是完整 su**，重启即失效（这条成立）。

### A-1. 打通过程：四个卡点

全部在 `shell` 权限下完成，不需要任何提权。

**卡点 1：事务号是 2，且这个服务不校验 interface token**

`service call AtlasService <code> ...` 对照实验：

| 输入 | 返回 |
|---|---|
| `code=1` | `Parcel(NULL)`，但只出现 `Thread Pool max thread count is 0` 警告，无 `setEvent` 日志 |
| `code=2` | `Parcel(NULL)` + `AtlasService setEvent:...` |
| `code=999` | `Parcel(Error: 0xffffffffffffffb6 "Not a data message")` |

所以 `setEvent` = transact code **2**。把 `s16 android.atlas.service` 当第一个参数塞进去时，日志打出的是
`setEvent:a`——第一个字段被直接当成事件名读了。这说明它是**手写 native binder，不走 AIDL 的 CHECK_INTERFACE**，
不需要 interface token；多传一个 token 反而会让整条 Parcel 错位。

**卡点 2：参数是 String8，而 `service call` 只会写 String16**

符号表里是 `android::AtlasService::setEvent(android::String8 const&, android::String8 const&)`。
String16 写出来是 `len, a\0t\0l\0a\0…`，被 `readString8` 读时在第一个 NUL 处截断，事件名只剩 `a`。

`service call` 的参数类型只有 `i32 / i64 / f / d / s16 / null / fd / nfd / afd`，没有 `s8`。
破法是绕开 `s16`：用 `i32` 把 Parcel **逐 4 字节原样铺出来**。

**卡点 3：对齐差 4 字节就整体判损坏**

实测出的布局（`readString8` 读完 len 字节后，位置按 `PAD(len+1,4)` 前进）：

```
int32 len(name)
name 字节 × len
补齐到 4 + PAD(len+1,4)
int32 len(value)
value 字节 × len
```

事件名 36 字节时 `4 + PAD(37,4) = 44`，value 的长度字段必须落在偏移 **44**；落在 40 会整个 Parcel 判损坏，
name 和 value 一起变空（这个坑花了几轮才定位）。打通后日志（`%s$%s` 是它自己的拼接格式）：

```
V/AtlasService: AtlasService setEvent:atlas_event_multimedia_audio_dumpsys cliensCount 1
V/AtlasEventDisptch: setEvent event atlas_event_multimedia_audio_dumpsys$TESTVAL
V/AtlasEventDisptch: dispatchEvent callback name:OplusAtlasLogWriter event atlas_event_multimedia_audio_dumpsys
```

**卡点 4：过滤是黑名单，真正的门是白名单**

反汇编 `OplusAudioDumpsysLogThread::isParamInvalid`（`0x23bc0`，200 字节），逻辑等价于：

```c
if (find(p,"|") != npos) return true;   // 无效
if (find(p,"&") != npos) return true;
if (find(p,";") != npos) return true;
if (find(p,"`") != npos) return true;
if (find(p,"$") != npos) return true;
return false;                            // 有效
```

五个字符，**不含换行、`>`、空格、`(`、`)`**——防 shell 分隔的意图很明显，但漏得很干净。

真正的门在 `threadLoop`（`0x23c88`）：

```c
if (mDumpType.empty()) { log("invalid mDumpType."); return false; }
if (mDumpType == "audio_log" || mDumpType == "anr_log") {
    log("start audio dump info, mDumpType:%s", mDumpType);
    __system_property_set("oplus.audio.dumpinfo.type", mDumpType);
    __system_property_set("ctl.start", "audiodumpinfo");
    return true;
}
log("invalid mDumpType, mDumpType:%s", mDumpType);
return false;
```

`mDumpType` 就是事件 value **原样**，且只认这两个字符串。**属性值不可控，注入点不在这一步。**

### A-2. 实测结果

发送 `value = "audio_log"`，抓到的进程与日志：

```
PS: u:r:dumpstate:s0   root   29334   1   audioDumpInfo
D/audioDumpInfo(29334): start dump: dumpType:audio_log
D/audioDumpInfo(29334): end dump: dumpType:audio_log
```

即：**一次无需任何权限的 shell 侧 binder 调用，稳定拉起 uid 0、`u:r:dumpstate:s0`、PPID=1（init）的进程**。
可重复，每次 PID 不同（28461 / 28829 / 29334 三次均命中）。

### A-3. 为什么停在「能起 root 进程」而不是「任意命令执行」

逐条都是实测，不是推测：

1. `audiodumpinfo` 在 `.rc` 里**没有 argv**，`setprop ctl.start` 也不带参数 → 它的命令行不可控。
2. 它唯一的输入属性 `oplus.audio.dumpinfo.type` 被 `threadLoop` 钉死在 `audio_log|anr_log` → 属性值不可控。
3. 它自己会建 `/data/persist_log/TMP/audio_dumpsys`，权限 **0770 root:root** → 也没法往里塞带元字符的
   文件名去赌 `cp %s* %s` 这类 glob 注入（何况 glob 展开的结果不会被二次解析成命令）。
4. 把 `libatlasservice.so` 里 **12 个 `system()` 调用点全部对过**：命令串是 `%s > %s%s%s` 这类模板，
   `%s` 只来自固定常量（`dumpsys audio` / `dumpsys media.audio_flinger` / `dumpsys media.audio_policy` /
   `dmesg -c` / `tar -czf` / `chmod 0777`）与时间戳，**没有一处来自事件参数**。
5. 补一轮动态验证：对 `.so` 里全部 **10 个原生事件**，用 `\n id > /data/local/tmp/.pwn \n`（绕开黑名单）
   按 5 字段逗号格式逐位置注入，**0 命中**。

### A-4. 对这台机器的实际意义

坏消息：**拿不到 root shell**，只是「能让 init 起一个 root 进程」，进程内部行为改不了。

好消息：这条链本身是**真实的权限边界突破**。策略里存在

```
(allow untrusted_app atlasservice (binder (call transfer)))
(allow untrusted_app atlas_service (service_manager (find)))
```

（本机 `system_ext_sepolicy.cil` 实读），即**任何普通 App 都能调**。一个普通 App 能让 init 拉起 root 进程，
这本身就够当漏洞修了——哪怕终点不是 shell。

副作用：过程中 `/data/persist_log/TMP/` 下多了一个 `audio_dumpsys/`（root:root 0770，由 `audioDumpInfo` 自建），
未删除任何文件，未修改任何属性。

### B. CVE-2026-43499（GhostLock，威力最大但最麻烦）

`p2p3p/GhostLock-for-OnePlus` 是完整可编译 PoC：futex PI 的 UAF → 控制内核栈 → 两次任意写
→ 写 `selinux_state.enforcing = 0` → 把自身 `cred` 指向 `init_cred` → 清 seccomp → late-load KernelSU。
效果接近完整 Magisk（SELinux 关闭 + full caps + KernelSU 模块）。

卡点很明确：偏移表按 `uname -r` 精确匹配，现成条目只有

```
6.12.38-android16-5-...-ab14275539-4k   （Ace 6T）
6.12.38-android16-5-...-ab14552068-4k   （Ace 6T）
6.12.23-android16-5-...-ab14541642-4k   （OnePlus 15）
```

本机是 `6.12.58-android16-6-g7704a1ae279b-ab15213644-4k`，**不在表里**。
作者给了 `tools/extract_target.py`（提 28 个 kallsyms 全局符号偏移）和
`tools/extract_btf.py`（提 57 个 BTF 结构体字段偏移），理论上只要拿到 boot.img 就能自行适配。
但意味着：下 OTA 包 → 拆 `payload.bin` → 取 boot.img → 配 NDK(r25+) 交叉编译 → 反复调
`PSELECT_ENTER_DELAY_USEC` 时序。而且内核构建于 2026-04-15，该 UAF 是否已被上游回补也需另证。

### C. GBL / SELinux 降级类

酷安 @muzhou07 的免解 BL 路线核心是 `fastboot oem set-gpu-preemption 0 androidboot...` 把 SELinux 降级，
再配特殊版 KernelSU。前提是**能进 fastboot 且该 oem 命令未被封**，且原帖面向骁龙 8e5 平台。
`SM4850` 是入门 SoC，是否受影响无公开资料。

### D. 已排除的几类

| 对象 | 排除理由 |
|---|---|
| 「ColorOS16 一键 root 工具箱」（酷安 @悲伤压缩包等） | 教程里明确写着「使用本工具前请解锁 bootloader」，且流程是 `fastboot flash init_boot` —— 本机 BL 不可解，直接不成立 |
| `JokerLock 提权助手`（`com.jokerlock.app`） | 只在 87g 这类下载站分发，无可核对源码。可信 PoC 都走 GitHub / XDA，走下载站的"免 BL 一键 root"应按不可信处理 |
| Rootline（CVE-2026-98260） | 明确限定 CPH2563 Global + ColorOS 17，payload 与内核绑定，作者自己写「Do not use this build on other models」 |
| lk.img + preload.so 方案（Find X8 系） | 需要**机型专属**的 lk/preload，且作者写明「ColorOS 16 全部失败，仅支持 C15」 |

### 一句话建议

A 线已经走完：**能稳定拉起 root 进程，但拿不到命令执行，也不值得继续往这条链里砸时间**——
剩下的空间要读 `/system_ext/bin/audioDumpInfo` 本体（但它 0500 root，读它需要 root，鸡生蛋）。
如果要的是持久 root + 模块，那这台机器（BL 锁死 + `ro.oem_unlock_supported` 未设置 + ARB 熔断）
本质上不属于可 root 的设备类型，继续投入的期望回报很低。

如果目标是「加固分享」而不是「root 自己」：把 A-1 的调用方式当成一个**固件缺陷报告**写出去更有价值——
它证明这台机器上任何一个普通 App 都能让 init 起 root 进程，且厂商的过滤只是一张 5 字符黑名单。

### 复现脚本

本轮产物在 `D:/1/.tmp/cve/`（未入库）：

| 文件 | 作用 |
|---|---|
| `fire.py` | 按实测布局构造 Parcel 并发送 `setEvent`，`python fire.py audio_log` 即可复现 |
| `call2.py` | `i32` 铺字节的基础函数 + 事务号扫描 |
| `probe.py` | 布局探针（用唯一图案反推 `readString8` 的真实读取偏移） |
| `disasm.py` / `fn.py` / `xref.py` | AArch64 反汇编 + 字符串交叉引用（依赖 capstone / pyelftools） |

---

## 附二：落地执行实录（2026-11-14）

目标四件事：① 装 root 管理工具（Shizuku 类）② 拿临时系统 root ③ 卸系统更新 ④ 屏蔽广告与云监。

| # | 目标 | 结果 | 说明 |
|---|---|---|---|
| ① | 安装 Shizuku / Hail | **未完成** | adb 安装被 OPPO `OplusPackageInstallInterceptManager` 拦死；UI 安装三条路全封（见坑 ⑱）。APK 已就位，**需人工点安装** |
| ② | 临时系统 root | **不可达** | A 线只能拉起 root 进程，无命令执行；GhostLock 三条通道全被拒（见前文 A-3 / B） |
| ③ | 卸载系统更新 | **部分完成** | `romupdate` 已挂起；`ota` / `sau` 三级全拒（硬保护）；`sauhelper` 已禁用；`cota` 已卸载 |
| ④ | 屏蔽广告与云监 | **基本完成** | 广告 4 个 suspend 成功 + metis 禁用；云监 4 个禁用 + pantanal 挂起；`olc` 被拒 |

### 事故与修复（本轮最大发现）

上一轮卸载 `com.oplus.appplatform` 导致 **SystemUI 崩溃死循环**（10 秒内 PID 递增 10 次），
连带 `com.oplus.subsys`、`com.android.packageinstaller` 全部起不来，表现就是"什么都装不上"。

修复动作与验证：

```
$ pm install-existing --user 0 com.oplus.appplatform
Package com.oplus.appplatform installed for user: 0
$ dumpsys package | grep AppFeatureProvider
  com.oplus.appplatform/com.oplus.customize.appfeature.configprovider.AppFeatureProvider
  [com.oplus.customize.coreapp.configmanager.configprovider.AppFeatureProvider]:   ← 别名
$ pidof com.android.systemui     # 3 次采样同一 PID，0 新增崩溃
28576
```

同时恢复 `com.oplus.athena`（`install-existing` + `enable`，两者都要做）。

### 本机当前生效状态

在线（`adb shell`）可直接回滚：

```
# 广告
pm suspend --user 0 com.opos.ads
pm suspend --user 0 com.heytap.pictorial
pm suspend --user 0 com.heytap.tas
pm suspend --user 0 com.nearme.instant.platform
pm disable-user --user 0 com.oplus.metis

# 云监 / 遥测
pm disable-user --user 0 com.heytap.cloud
pm disable-user --user 0 com.oplus.obrain
pm disable-user --user 0 com.oplus.logtrial
pm disable-user --user 0 com.oplus.vdc
pm suspend --user 0 com.oplus.pantanal.ums

# 系统更新
pm suspend --user 0 com.oplus.romupdate
pm disable-user --user 0 com.oplus.sauhelper
```

已卸载（`pm install-existing` 可恢复）：`com.heytap.mcs` `com.oplus.beaconlink`
`com.oplus.contentportal` `com.oplus.cota` `com.oplus.deepthinker` `com.oplus.games`
`com.oplus.lfeh` `com.oplus.onetrace` `com.oplus.statistics.rom` `com.oplus.upgradeguide`

被硬保护、无解：`com.oplus.ota` `com.oplus.sau` `com.oplus.olc`

### 不可移除白名单（踩过就懂）

`com.oplus.appplatform` · `com.oplus.athena` · `com.oplus.customize.coreapp`

### 待人工完成的一步

> ✅ 已于 2026-11-14 晚完成，且发现**根本不需要人工点安装** —— 关掉权限监控后
> `pm install` 直接可用（坑⑲），两个 APK 都是 adb 装进去的。

装好后 Shizuku 用 adb 启动一次。**注意：Shizuku 13.x 已经没有 `start.sh` 了**，
老教程那句 `adb shell sh /sdcard/Android/data/.../start.sh` 会报文件不存在。正确做法是直接
执行 APK 里的原生库（App 里「查看指令」弹窗给出的就是这条）：

```bash
# 路径用 pm path 现取，别抄死（hash 段每次安装都会变）
adb shell "pm path moe.shizuku.privileged.api"
# package:/data/app/~~AICAWYv43VYxogViPKuoXg==/moe.shizuku.privileged.api-CZsXIkjrxQVq_aCryPYR2g==/base.apk
adb shell "/data/app/~~AICAWYv43VYxogViPKuoXg==/moe.shizuku.privileged.api-CZsXIkjrxQVq_aCryPYR2g==/lib/arm64/libshizuku.so"
# info: killing old process...  /  info: shizuku_server pid is 8227  /  exit with 0
```

判据：`ps -A | grep shizuku_server` 出现 `shell <pid> 1 ... shizuku_server`（PPID=1 表示已 daemon 化）。

注意：因本机拿不到 root，Shizuku **只能用 ADB 模式**（这也是它的常规形态），root 模式不可用。

### 工具链

`axml.py`（自写 AXML 解析，读 APK 清单里的 provider/authority/authorities）、
`scanjar.py`（在 `services.jar` / `oplus-services.jar` 里按字符串定位 OPPO 定制类与常量）。

---

## 附三：Shizuku / Hail 配置与第二轮屏蔽（2026-11-14 晚）

目标：把「临时 root 管理工具链」真正跑通，并按社区清单做第二轮云控/广告/OTA 清理。

### 1. 四件事完成度

| # | 事项 | 结果 |
|---|---|---|
| ① | 装 Shizuku / Hail | ✅ v13.6.0 / v1.11.0，已用 `pm install` 装上（见坑⑲） |
| ② | 让 Shizuku 真正可用 | ✅ 关掉 `Disable system optimization` 后红字消失，版本显示 13.5 |
| ③ | Hail 绑定 Shizuku | ✅ 工作模式 = `Shizuku - 停用`，授权弹窗点「始终允许」 |
| ④ | 端到端验证 | ✅ 冻结计算器 → `enabled=3`；解冻 → `enabled=1`；`pm default-state` 复位 → `enabled=0` |

### 2. Shizuku 的几个坑

- **13.x 不再有 `start.sh`**，改为直接执行 `lib/arm64/libshizuku.so`（见上）。
- 用截屏 OCR 抄路径会把 hash 段抄错（`CZsXlk-jrQxQv` vs 真实 `CZsXIkjrxQVq`），
  报错形如 `inaccessible or not found`。**一律用 `pm path` 现取。**
- 服务端启动后界面**版本号可能显示错误**（曾显示 13.0 并提示"再次启动来升级到 13.5"）。
  这是权限受限时的降级表现；把权限监控关掉再重启服务端，版本立刻变回 13.5。
- `service list | grep shizuku` 返回空是**正常**的——Shizuku 不注册系统 service。
- 每次**重启手机后都要重新执行一次** `libshizuku.so`（ADB 模式的固有代价）。

### 3. Hail 的操作逻辑（第一次用会懵）

Hail 不是"点一下就冻结"，是两步：

```
「应用」页 → 勾选右侧复选框（加入工作台）
    ↓
「首页」→ 条目单击 = 启动应用；真正冻结在右上角 ⋮ 菜单：
   冻结可见 / 解冻可见 / 全部冻结 / 全部解冻 / 冻结非白名单 / 导入应用 / 导出到剪切板
```

- 「冻结可见」= 只处理当前屏可见的条目，做单点测试最安全（别手滑点「全部冻结」）。
- 工作模式里的四个 Shizuku 选项含义：`强行停止`(force-stop) / `停用`(disable-user) /
  `隐藏`(hide) / `暂停`(suspend)。**选「停用」**，和 adb 的 `pm disable-user` 等价、最彻底。
- `pm suspend`/`pm disable` 那条路上被硬保护的包，Hail 一样会失败（同一个 system_server 检查）。
- 顺便记一个操作坑：**开着输入法时 `adbd` 的点击会落到键盘上**，看着"点了没反应"，
  其实点在了「语音转文字」面板上。点列表前先 `input keyevent KEYCODE_BACK` 收键盘。
- `adb shell input text` **不支持中文**（`NullPointerException: length of null array`），
  所以 Hail 的搜索框只能输入 ASCII；按中文名找应用得靠滚动。

### 4. 第二轮屏蔽结果

新增 **disabled-user（16 个）**：

```
com.android.virtualization.terminal   com.coloros.digitalwellbeing   com.heytap.cloud
com.heytap.speechassist               com.oplus.logtrial             com.oplus.metis
com.oplus.nas                         com.oplus.nhs                  com.oplus.obrain
com.oplus.onetrace                    com.oplus.ovoicemanager        com.oplus.ovoicemanager.wakeup
com.oplus.qualityprotect              com.oplus.sauhelper            com.oplus.stdsp
com.oplus.thirdkit                    com.oplus.vdc
```

新增 **suspended（13 个，`disable-user` 被拒后降级成功）**：

```
com.heytap.browser        com.heytap.market      com.heytap.quicksearchbox
com.oplus.themestore      com.oplus.pantanal.ums com.heytap.pictorial
com.nearme.instant.platform  com.heytap.tas      com.heytap.openid
com.heytap.htms           com.oplus.romupdate    com.oplus.cota
com.opos.ads
```

`com.oplus.nas` 与 `com.oplus.nhs` **必须成对处理**（社区警告，单动一个会炸），本次两个一起禁用后
WiFi/移动网络实测正常（`ping 223.5.5.5` 0% loss，`dumpsys connectivity` 默认网络仍为 WIFI）。

**故意没动的**：`com.heytap.colorfulengine`（桌面/锁屏动态引擎，动它可能坏壁纸与小组件）、
`com.heytap.music` / `com.coloros.video`（有广告但是功能应用，留给用户自己决定）、
`com.heytap.accessory` / `com.heytap.mydevices`（配件与设备管理）、`com.heytap.mcs`（推送通道）。

### 5. OTA：包级无解，但可以把引擎废掉

`com.oplus.ota` / `com.oplus.sau` / `com.oplus.olc` 四路全拒，且报错暴露了保护机制的真实位置：

| 手法 | 结果 |
|---|---|
| `pm disable-user --user 0` | `new state: default`（静默拒绝） |
| `pm suspend --user 0` | `new suspended state: false` |
| `pm uninstall --user 0` | `Failure [DELETE_FAILED_INTERNAL_ERROR]` |
| `pm disable --user 0 com.oplus.ota/.service.OTAService` | `SecurityException: Shell cannot change component state ... to 2` |
| `pm hide --user 0` | `SecurityException: Access denied, requires: android.permission.MANAGE_USERS` |
| `cmd appops set <pkg> RUN_IN_BACKGROUND ignore` | ✅ 成功 |
| `cmd deviceidle whitelist -<pkg>` | ✅ `Removed:` |

关键结论：**组件级 `pm disable` 也会被拦**，而且抛的是 `SecurityException` 而不是静默 `default`
——说明 OTA 三包在 system_server 里有一张显式保护名单，连"改组件状态"这个更细的入口都堵了。

所以 OTA 走"绕"而不是"关"：

```bash
# 引擎已挂起（真正的下载/刷写在这里）
pm suspend --user 0 com.oplus.romupdate
pm suspend --user 0 com.oplus.cota          # 已 uninstall，如恢复则一并 suspend

# 三个硬保护包：禁后台 + 踢出 doze 白名单，让它检查不了、也活不下来
for p in com.oplus.ota com.oplus.sau com.oplus.olc; do
  cmd appops set $p RUN_IN_BACKGROUND ignore
  cmd deviceidle whitelist -$p
done
```

另外这两项本来就已经是关的（`settings get global` 确认）：

```
ota_disable_automatic_update=1
can_update_at_night=0
```

### 6. 本轮健康检查（全部通过）

```
SystemUI pid   : 28576（两次采样同一 PID，0 崩溃）
FATAL EXCEPTION: 0 条（近 300 行日志）
网络           : ping 223.5.5.5 → 0% packet loss
Shizuku        : shizuku_server pid 8227, user shell, PPID 1
安装通道       : pm install -r hail.apk → Success
```

### 7. 完整回滚

```bash
# 解冻（Hail 冻的 / adb 禁的都能用这两条还原）
pm enable --user 0 <pkg>
pm default-state --user 0 <pkg>

# 解除挂起
pm unsuspend --user 0 <pkg>

# 恢复后台限制
cmd appops set <pkg> RUN_IN_BACKGROUND default
cmd deviceidle whitelist +<pkg>

# 恢复已卸载的（保留 enabled 状态，恢复后可能还要 pm enable）
pm install-existing --user 0 <pkg>
```
