# 晴耕雨航 · Android 测试包

当前产物：`build/android/qinggeng-yuhang-0.4.1-debug.apk`。

- 应用名：晴耕雨航
- 包名：`com.qinggengyuhang.game`
- 版本：0.4.1 / versionCode 10
- 架构：arm64-v8a，64位安卓设备
- 最低系统：Android 7.0（API 24）
- target SDK：36
- 文件大小：49,448,695 字节（47.2 MiB）
- 签名：Android Debug，供开发试玩；不是商店正式发行签名
- 已通过 APK v2/v3 签名验证、16KB 原生库对齐检查和 ZIP CRC 检查
- APK 中未包含 tests、tools、docs 或私钥文件；不申请网络权限

原生导出模板使用官方 Godot 4.7.2 `android_debug.apk`。下载脚本仅从官方模板压缩包读取该条目并校验CRC，不下载其他平台模板。构建脚本使用独立的自包含Godot编辑器设置，不修改全局编辑器的Java或Android SDK路径。原全局配置文件构建前后SHA256一致。

## 重新打包

```sh
python3 tools/build_android.py
```

脚本默认使用 `/Applications/Godot.app`、`~/android_sdk` 和 Homebrew OpenJDK 17，支持 `--sdk` 与 `--java` 指定路径。签名使用本机 `~/.android/debug.keystore`；不要将密钥或其凭据加入仓库。

## USB 安装

手机开启USB调试，连接电脑并允许调试授权后：

```sh
adb devices -l
adb install -r build/android/qinggeng-yuhang-0.4.1-debug.apk
adb shell pm path com.qinggengyuhang.game
```

`-r`保留现有数据覆盖安装。若出现签名不一致，不要直接卸载以免丢失存档，应先确认旧包签名与备份需要。多设备连接时使用 `adb -s 设备序列号 install -r ...` 指定目标。

安装成功后可在手机桌面点击《晴耕雨航》。默认不自动启动游戏、模拟器或编辑器。APK的签名和完整性检查不等于手机上的画面、触控和性能验收。

## 本次安装记录

2026-11-11 15:51：三星 SM-M446K（RFCX11LS15K）覆盖安装 Success，系统确认0.4.1 / versionCode 10。保留数据，未自动启动游戏。
