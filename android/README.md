# HideMyEmail Android / HideMyEmail Android

An optional Android companion for the root HideMyEmail Generator project. It
keeps the desktop CLI and macOS app independent while providing a phone-first
interface for users who manage their own iCloud+ Hide My Email aliases without
an iPhone.

这是根目录 HideMyEmail Generator 项目的可选 Android 配套客户端。在不改变桌面
CLI 与 macOS 应用工作流的前提下，为没有 iPhone、但需要在手机上管理自己
iCloud+「隐藏邮件地址」的用户提供移动端界面。

## Features / 功能

- Supports global iCloud and iCloud China endpoints.
- Accepts a raw `Cookie` header or browser **Copy as cURL** text.
- Validates the signed-in account, generates aliases, lists active or inactive
  addresses, and lets users edit labels and notes or change address activity.
- Maintains phone-local `unused`, `used`, and `trash` address states.
- Does not use a companion server; requests go directly to the relevant iCloud
  endpoint.
- Uses English resources by default and Simplified Chinese resources on Chinese
  devices.

- 支持国际区与中国大陆区 iCloud 端点。
- 支持原始 `Cookie` Header 和浏览器 **Copy as cURL** 内容。
- 支持账号校验、生成地址、查看使用中与已停用地址。
- 支持在手机本地按 `unused`、`used`、`trash` 整理地址状态。
- 不依赖额外中转服务器，请求直接发送至相应 iCloud 端点。

## Build / 构建

Requirements: JDK 17+ and Android SDK Platform 34.

```bash
cd android
bash ./gradlew testDebugUnitTest
bash ./gradlew assembleDebug
```

On Windows:

```powershell
cd android
.\gradlew.bat testDebugUnitTest
.\gradlew.bat assembleDebug
```

The debug APK is written to `app/build/outputs/apk/debug/app-debug.apk`.

## Data / 本地数据

The app stores its configuration and local address-state records in app-private
storage on the Android device. Do not commit cookies, Apple IDs, real aliases,
verification codes, signing keys, or generated APKs.
Android backup is disabled so the session cookie remains on the device.

App 会在 Android 设备的应用私有存储中保存配置与本地地址状态。请不要提交
Cookie、Apple ID、真实邮箱别名、验证码、签名密钥或生成的 APK。
已禁用 Android 备份，确保会话 Cookie 不会离开设备。

## License / 许可证

The Android client is covered by the repository's [MIT License](../LICENSE).
See [third-party notices](THIRD_PARTY_NOTICES.md) for declared dependencies.

Android 客户端适用根目录的 [MIT License](../LICENSE)。声明依赖见
[第三方组件说明](THIRD_PARTY_NOTICES.md)。
