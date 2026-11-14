# mydevice-harden

四台设备的免 root / 有 root 加固实录：怎么定位国产定制系统里的「云控」与系统广告链路，
以及在**不同权限边界下**分别能做到哪一步、哪一步做不到。

不是包名清单分享。**每台设备的规则都不可互换**，可复用的只有方法论。
唯一的例外是 [#4 OPPO](OPPOA7ProMax-PYC110.md) 的 `scripts/`——它把这台的完整改动做成了
可 `--dry-run` 的一键脚本与全量回滚，因为那台机器没有 root、每一步都得靠 shell 权限硬磕，
手工重放成本太高。

## 设备一览

| # | 设备 | 系统 | Root | 域名层 | 组件层 | 文档 |
|---|---|---|---|---|---|---|
| 1 | 小米平板 5 Pro 11″<br>`M2105K81AC` / elish | Android 13<br>MIUI `V14.0.3.0.TKYCNXM` | ✅ Magisk 26.1<br>BL 已解锁 | hosts 24,936 行<br>+ iptables | disable 24<br>+ uninstall 1 | [小米平板5Pro-M2105K81AC.md](小米平板5Pro-M2105K81AC.md) |
| 2 | 荣耀 Magic Vs2<br>`VER-AN00` | Android 13<br>MagicOS `7.2.0.125` | ❌ 无<br>BL 锁定 | ✗ 不可写 | disable 15<br>+ settings 1 | [荣耀MagicVs2-VER-AN00.md](荣耀MagicVs2-VER-AN00.md) |
| 3 | Redmi K30 4G<br>`phoenix` | Android 12<br>MIUI `V13.0.6.0.SGHCNXM` | ✅ Magisk 31.1<br>BL 已解锁 | hosts 80 条<br>+ iptables | disable 8 + uninstall 2<br>+ 预装清退 15 | [RedmiK30-4G-phoenix.md](RedmiK30-4G-phoenix.md) |
| 4 | OPPO A7 Pro Max<br>`PYC110` | Android 16<br>ColorOS `V16.1.0`<br>`PYC110_16.0.9.409(CN01)` | ❌ 无<br>**BL 不可解锁** | ✗ | disable 21 + uninstall 2<br>+ suspend 12<br>+ Shizuku 免电脑自启<br>+ Termux:Boot 开机脚本 | [OPPOA7ProMax-PYC110.md](OPPOA7ProMax-PYC110.md) |

四台跨了小米 / 荣耀 / Redmi / OPPO 四个厂商，Android 12 / 13 / 16 三个大版本，
有 root 与无 root 各两台——这个组合正好能把「哪些结论是通用的、哪些只是某台设备的特例」分开。

## 核心认知：云控不是一个功能，是四条链路

国产定制系统里常被笼统称为「云控」的东西，实际是四条独立链路。屏蔽时必须逐层拆开，
否则把某条链路当成全部，就会得出「已经关掉了」的错误结论。

| 链路 | 干什么 | 端侧特征 | 怎么打 |
|---|---|---|---|
| **配置下发**（Remote Config） | 上报设备指纹（SN/OAID/机型/地区/电量/温度/场景），服务端按分桶返回配置 JSON，端侧据此切换性能策略、功能开关、广告位、灰度分组 | 单向拉取 + 本地缓存 + 定时刷新，**几乎没有用户可见界面** | 封域名，或冻结通道宿主 |
| **埋点上报**（Telemetry） | 事件流批量上报，带指数退避与本地队列 | 敏感的是**维度**不是事件：安装列表、使用时长、前台切换、输入法词频、WiFi/BTS 扫描 | 封域名 + 冻结上报服务 |
| **广告投放** | 由配置层驱动，但另有独立 SDK 配置接口（`sdkconfig.*`）、素材 CDN、曝光回传 | 多数「系统组件被判为广告」的误判，是因为它内嵌了这套 SDK 而非它本身在做广告 | 冻结 SDK 本体，封 `zeus.ad.*` 一类主端点 |
| **静默分发** | 预装 / 推荐应用的静默安装 | 应用商店 + 包安装器 + 推送三者配合 | 清退推广位 + 冻结商店侧 |

**同构、不同名**：小米是 `com.miui.daemon` + `jupiter/ccc`，荣耀是三层 `hiview` + `metrics-drcn.*`，
OPPO 是 `com.oplus.statistics.rom` / `com.oplus.onetrack` / `com.oplus.deepthinker`。
四台的命名空间零重叠，**照抄包名必然既掉功能又漏通道**。

## 能力边界取决于 BL，不是取决于品牌

这是整个项目最重要的一条：**能不能做域名层，只取决于 bootloader 是否解锁**，与品牌、系统版本、
是否装了 Shizuku 都无关。

| 能力 | BL 解锁（有 root） | BL 锁定（无 root） |
|---|---|---|
| `pm` 卸载 / 冻结 / 隐藏 | ✅ | ✅（但受厂商保护名单限制） |
| `settings` 读写 | ✅ | ✅（shell 持有 `WRITE_SECURE_SETTINGS`） |
| 改 hosts | ✅ | ❌ 分区只读 |
| iptables / nftables | ✅ | ❌ |
| 杀 uid 1000 的 native 进程 | ✅ | ❌ |
| 读 `/data`、`/data/adb` | ✅ | ❌ |
| 开机自动校准 | ✅ | ❌（只能手工重跑） |

> **Shizuku 不是 root。** 它的 `shizuku_server` 以 uid `shell`(2000) 运行，与 adb shell 同级，
> 能力边界完全一致——补不上 hosts 和 native 两个缺口。详见[荣耀那台](荣耀MagicVs2-VER-AN00.md)的踩坑 ⑤。

## 六条通用方法论

1. **先分层定位承载实体，再逐层选手段，最后用状态回读复核。** 顺序反了就会变成"照着别人的清单关包"。
2. **判断依据永远是 `dumpsys` 回读，不是命令的返回文本。** `pm suspend` 对受保护包返回
   `new suspended state: false`——退出码 0、不抛异常，只是状态没变；`pm disable-user` 会静默降级成
   `new state: default`。只看"执行成功"必然误判。
3. **门禁是逐包差异的，不能预设某个机制会失败。** 同一条 `pm uninstall`，对 OPPO 的 12 个包直接成功，
   对另外 9 个返回 `DELETE_FAILED_INTERNAL_ERROR`。必须逐包实测。
4. **失败的错误码比失败本身更有信息量。** `DELETE_FAILED_INTERNAL_ERROR` 只说明"PM 内部拒绝"，
   而 `pm clear` 的 Java 栈直接点名了拦截类 `OplusClearDataProtectManager`——后者才是根因。
5. **打通道，不打宿主。** 宿主动了会掉功能甚至掉系统服务，封它引用的端点效果等价且完全可逆。
6. **验证必须有功能对照。** RethinkDNS 把整机打到断网时，端侧表现与「拦截成功」**完全一致**
   （目标域名 NXDOMAIN、耗时 12 s），只有同时测 baidu/qq 能否正常访问才能区分。

## 各设备最值得看的一条

| 设备 | 如果只看一条 |
|---|---|
| [小米平板 5 Pro](小米平板5Pro-M2105K81AC.md) | `PERSISTENT` 应用 `disable-user` 无效、`kill -9` 会 4 秒复活，必须 `uninstall --user 0` |
| [荣耀 Magic Vs2](荣耀MagicVs2-VER-AN00.md) | `hiview` 是三层结构，禁用应用层只关掉三分之一，native 与 vendor 层无 root 就是无解 |
| [Redmi K30 4G](RedmiK30-4G-phoenix.md) | 装了 PIF 的机器 `ro.boot.*` 全部不可信，判断 BL 状态只能 `fastboot getvar unlocked` |
| [OPPO A7 Pro Max](OPPOA7ProMax-PYC110.md) | 「禁用包数」三个答案：`pm list -d`=21、加 `-u`=22、`dumpsys enabled=3`=21。两个 21 **集合完全不同**（各有 1 个漏报、2 个假阳性），只信 dumpsys |

## 复现

文档里的命令都是逐条实测过的原始命令，可直接照抄。几点通用注意：

```bash
# Git Bash / MSYS 环境下，adb shell 的绝对路径会被改写成 Windows 路径
MSYS_NO_PATHCONV=1 adb shell uiautomator dump /sdcard/ui.xml

# 卸载前一定先做状态快照，回滚全靠它
# 注意：pm list packages -d 会漏报（OPPO 实测少 1 个），快照请用 dumpsys
adb shell dumpsys package | awk '/^  Package \[/{p=$2} /^    User 0: ceDataInode/ && /enabled=3/{print p}' > disabled-before.txt
adb shell dumpsys package | awk '/^  Package \[/{p=$2} /suspended=true/{print p}' > suspended-before.txt

# 回滚：disable 的用 enable，uninstall 的用 install-existing
adb shell pm enable --user 0 <pkg>
adb shell pm install-existing --user 0 <pkg>
```

## 免责与边界

- 全部操作在**本人设备**上完成，目的是减少遥测与广告，不涉及破解付费内容、不绕过 DRM、不改系统签名。
- 每台设备的改动都**可回滚**，回滚命令写在各文档末尾。但**执行前请自行做快照**，不同系统版本的包名与行为可能有差异。
- 文档中的"已断"仅指**系统级广告链路**。App 把推荐当内容呈现的那部分（应用商店首页、视频/音乐/天气内嵌信息流）
  在不动功能的前提下做不到，各文档都单独标注了这条边界。
- 结论有时效性。系统大版本更新后，包名、保护名单、设置项都可能变化，**回读验证不能省**。

## 目录

```
README.md                        本文件
小米平板5Pro-M2105K81AC.md        #1 Xiaomi M2105K81AC / elish
荣耀MagicVs2-VER-AN00.md          #2 HONOR VER-AN00
RedmiK30-4G-phoenix.md            #3 Redmi K30 / phoenix
OPPOA7ProMax-PYC110.md            #4 OPPO PYC110
.gitattributes                    强制 *.sh 用 LF（否则 Windows 检出后脚本跑不起来）
scripts/apply-tier2.sh            #4 一键应用（21 禁用 + 2 卸载 + 12 挂起 + 权限/设置 + Shizuku）
scripts/rollback.sh               #4 一键全量复原（默认保留 Shizuku，--strict 连它一起撤）
scripts/termux-boot-00-oaid-kill.sh  #4 开机脚本，推到 Termux:Boot 目录后开机自动跑（md5 与机内一致）
```

每份文档结构一致：**型号参数版本 → 目标 → 已落地方案 → 踩过的坑**。
「踩过的坑」占了每份的一半以上篇幅，包括我自己判断错、被用户纠正、以及一度写进文档后又被推翻的结论——
这部分才是真正能省别人时间的东西。
