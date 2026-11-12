# Wen Privacy Guard — 免费、自选、可逆的国产设备隐私保护模块

一个完整、可编译的 Zygisk 模块项目。灵感来自 COPG 的模块结构（`module.prop` / `customize.sh` / `service.sh` / `webroot/` / `zygisk/`），但**不是 COPG 的复制品**：没有从你上传的 COPG v7.7.2 zip 里复制任何代码、没有它的许可证验证、没有它的收费功能——那些收费功能里的大部分，本项目有意不实现。

## 先说清楚：不做什么，为什么

你指令里要求“全部 PRO 功能免费实现”，包括：

- IMEI / Device ID / IMSI / ICCID / MAC / Boot ID / GAID / App Set ID / Widevine 伪装与随机化
- Build / 指纹 / CPU / GPU / 传感器 / 刷新率伪装
- SIM / 运营商 / 基站 / GPS 伪造
- Play 安装来源伪造、许可证检查绕过、禁用签名验证、允许降级、跳过 Play Protect
- 隐藏 VPN / 隐藏 Mock Location / 隐藏开发者选项、FLAG_SECURE 绕过

这些我没有实现，也不会帮你实现。它们不是隐私保护，是**伪造设备身份、绕过封禁与许可证、破坏应用签名校验**的工具——用来逃避封号、骗过风控、装盗版或被篡改的应用。做成“全部免费”并不能改变这个性质。把它们标成“隐私”也一样。

本模块只做一件事，而且是 Lowex 之前已经在做的那件事的设备端延伸：**让你自己决定，哪些厂商遥测组件可以在你的手机上运行和上报**。这是你自己的设备、你自己的选择、可逆的操作。

## 做什么（全部免费，全部默认关闭）

| 功能 | 怎么做 | 默认 |
|---|---|---|
| 国产遥测组件管理 | WebUI 勾选后，`pm disable-user --user 0 <包名>`；取消勾选或卸载模块即恢复 | 关 |
| 小米 / Redmi / POCO | `com.miui.analytics`、`com.xiaomi.misystem`、`com.miui.miservice` | 关 |
| OPPO / Realme / OnePlus | `com.mobiletools.systemhelper`、 `com.oppo.opporesearch`、 `com.coloros.safecenter`（仅上报部分） | 关 |
| vivo / iQOO | `com.vivo.analytics`、`com.bbk.account` | 关 |
| 应用列表保护 | 仅限制遥测组件自身的包管理器查询结果；不对银行/游戏/工作应用隐藏任何应用，不改任何标识 | 关 |
| Root 类型检测 | 见下 | — |

华为按你的要求排除。

### SystemHelper，特别说明

`com.mobiletools.systemhelper`（联通终端管理模块）已在 OPPO 和小米两边都列出。你 2026-11-06 已核实：它向 `dm.wo.com.cn:18080` 传 IMEI/IMSI/ICCID 与 24 小时应用使用情况。**只停用，不卸载**——你在 OnePlus 上实测过，ColorOS 会拦截系统应用卸载，`pm disable-user --user 0` 才是正确的可逆做法。

网络侧拦截仍在 Lowex 里：OPPO 34 域 / 小米 41 域（v1.7.25），代理开启时生效。本模块是设备侧，Lowex 是网络侧，两边互补。代理规则拦不住手机本地的录制本身，只能拦上传；彻底停录制要靠手机端 ADB 停用对应包，无 root 时拦不彻底——这一点 README 不瞒你。

## Root 类型检测（第 5 节，强制安全降级）

`scripts/root_detect.sh` 在安装时和每次开机都跑，只读 `getprop`，不写任何分区：

- 读 `ro.boot.flash.locked`、`ro.boot.verifiedbootstate`、`ro.boot.vbmeta.device_state`
- 区分 `magisk` / `kernelsu` / `apatch`
- **正式 Root**：BL 已解锁（`flash.locked=0` 或 `verifiedbootstate=orange/yellow`）+ 正式安装的 Root → 显示完整功能
- **临时 Root**：Root 进程在，但 BL 仍报告锁定 / green，或 vbmeta 仍 locked → `root_type=temporary`，WebUI 显示红色警告横幅，高风险功能隐藏，`service.sh` 拒绝执行高风险应用
- BL 状态不明时按临时 Root 处理（宁可保守，不可错放）

结果写在 `/data/adb/wenprivacyguard/root_status.json`，WebUI 直接读它。

## 安全约束（第 8 节，硬性）

- **严禁分区操作**：全项目没有任何 `dd` / `lpmake` / `fastboot` 分区命令，不读写 `super` / `system` / `vendor` / `odm` / `product` / `vbmeta`。`build.sh` 里有安全门，grep 到就失败。
- 停用只用 `pm disable-user --user 0`，可逆，systemless。
- 无恶意代码、无后门、无数据上传、无远程控制、无许可证验证。Native 代码不联网。
- 全部 opt-in：配置默认全关，只应用用户明确勾选的内容；提供“全部关闭 / 清空”。
- 卸载即恢复：`uninstall.sh` 把所有列出的包 `pm enable`，再清掉自己的数据。

## 项目结构

```
module.prop  customize.sh  service.sh  uninstall.sh  sepolicy.rule
META-INF/com/google/android/          # 标准刷机包结构
config.example.json                   # 默认全关的配置模板
scripts/
  root_detect.sh                      # Root 类型检测
  apply_telemetry.sh                  # 只执行用户勾选的停用
  telemetry_db.json                   # 国产遥测组件库（带“停用后影响”）
zygisk/
  CMakeLists.txt  src/main.cpp        # 最小可编译骨架：只读配置、记日志，
                                      # 未经三重门（启用 + 非临时 Root + 勾选）
                                      # 不给任何应用进程装 Hook
webroot/                              # WebUI：index.html + css/style.css + js/app.js
  telemetry_db.json  config.json
build.sh  make_zip.sh
.github/workflows/build.yml          # tag 触发 CI，编 .so 并打包
```

## 安装

1. Android 9+，Magisk 24+ / KernelSU 0.6.6+ / APatch 0.10+，**先装 Zygisk Next / ReZygisk / NeoZygisk**，Magisk 内置 Zygisk 必须关掉（否则装不上，`customize.sh` 会直接拒绝）。
2. `build.sh` 打包（见下），或在 GitHub 打 tag `v*` 让 CI 打包。
3. 在 Magisk / KernelSU / APatch 里刷入 zip，重启。
4. 打开 WebUI，确认 Root 类型横幅，再逐个勾选。什么都不勾，模块就什么都不做。

## 构建

```bash
# 需要 Android NDK
export ANDROID_NDK_HOME=/path/to/ndk
./build.sh            # 编 .so + 打包成 WenPrivacyGuard-v1.0.0.zip
./build.sh --no-native  # 只打包 zip（无 .so 时 zip 里是占位说明）
```

CI：打 tag `v1.0.0` 即自动构建，产物在 Actions 的 Artifacts 里。

## WebUI

Apple / Google 风格：系统字体、大标题、分组卡片、柔和阴影、精致开关、深色模式（含 AMOLED 纯黑）。中文优先。分四块：仪表盘（模块状态 / Root 方案 / BL / Root 类型）、遥测组件（按厂商分组，每项写明“停用后影响”）、应用列表保护、风险警告横幅。配置是 JSON，存在 `/data/adb/wenprivacyguard/config.json`，WebUI 通过 KernelSU `ksu.exec` 读写；没有 ksu 时回落到浏览器 localStorage（仅供预览）。

## 已知限制（不瞒你）

- 没有编译过的 `.so` 时，打出来的 zip 只能算结构完整，不能直接刷了就用——先跑 `./build.sh`（需要 NDK），或等 CI 产物。
- Native 的完整 Zygisk 接线（`HAVE_ZYGISK` 分支）需要官方 `zygisk.hpp`（Magisk / Zygisk Next），骨架里留了位置和三重门，默认的纯 NDK 构建只加载、读配置、记日志，不装 Hook。
- 遥测组件清单按 ROM 版本会有出入：WebUI 每项都写了来源和“停用后影响”，勾选前请先看；某个包在你的 ROM 上不存在时，`apply_telemetry.sh` 会跳过，不报错。
- 这个模块不能替代 Lowex 的网络侧拦截，也不能阻止本地录制本身。
