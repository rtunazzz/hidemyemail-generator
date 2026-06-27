<p align="center">
  <img width="64%" src="docs/header.png" alt="HideMyEmail Generator">
</p>

<h1 align="center">HideMyEmail Generator</h1>

<p align="center">
  Generate, reserve, and manage iCloud Hide My Email addresses from a local CLI.
  <br>
  Includes a Windows launcher, iCloud China support, and automated cookie capture.
</p>

<p align="center">
  <a href="https://github.com/never-seek/hidemyemail-generator/blob/main/LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2ea44f"></a>
  <img alt="Python 3.12+" src="https://img.shields.io/badge/python-3.12%2B-3776ab?logo=python&logoColor=white">
  <img alt="uv ready" src="https://img.shields.io/badge/uv-ready-5c4ee5">
  <img alt="Windows launcher" src="https://img.shields.io/badge/windows-launcher-0078d4?logo=windows&logoColor=white">
  <img alt="iCloud China" src="https://img.shields.io/badge/iCloud-China%20ready-f57c00">
</p>

<p align="center">
  <a href="#english">English</a>
  ·
  <a href="#简体中文">简体中文</a>
  ·
  <a href="https://github.com/rtunazzz/hidemyemail-generator">Upstream</a>
</p>

> This is a fork of [rtunazzz/hidemyemail-generator](https://github.com/rtunazzz/hidemyemail-generator).  
> You need an active iCloud+ subscription to generate Hide My Email addresses.

<a id="english"></a>

## Overview

HideMyEmail Generator is a local command-line utility for Apple's iCloud Hide My
Email service. It can generate new addresses, list active or inactive addresses,
and validate the currently saved iCloud cookie.

This fork focuses on a smoother Windows and iCloud China workflow:

- region-aware iCloud API targeting for `global` and `china`;
- automatic iCloud partition detection;
- one-click Windows launcher;
- account-aware cookie management;
- browser-assisted cookie capture for iCloud China;
- longer timeout and retry behavior for slower iCloud responses.

## Contents

- [Highlights](#highlights)
- [Quick Start](#quick-start)
- [Windows Launcher](#windows-launcher)
- [CLI Reference](#cli-reference)
- [Cookie Management](#cookie-management)
- [Configuration](#configuration)
- [Generated Files](#generated-files)
- [Troubleshooting](#troubleshooting)
- [Security and Privacy](#security-and-privacy)
- [Disclaimer](#disclaimer)
- [Acknowledgements](#acknowledgements)
- [License](#license)
- [简体中文](#简体中文)

## Highlights

| Capability | Description |
| --- | --- |
| Generate addresses | Create and reserve iCloud Hide My Email addresses with a label. |
| List addresses | List active or inactive Hide My Email addresses. |
| Account check | Show the Apple ID, DSID, user partition, and Hide My Email availability for the saved cookie. |
| iCloud China support | Use `icloud.com.cn` origins, setup validation, and maildomain hosts. |
| Partition detection | Derive the correct `pNNN-maildomainws` host from captured requests or account validation. |
| Windows launcher | Double-click menu for generation, listing, and cookie management. |
| Cookie capture | Open iCloud Plus, click Hide My Email, capture the app request, and save the cookie locally. |

## Quick Start

```bash
git clone https://github.com/never-seek/hidemyemail-generator.git
cd hidemyemail-generator
uv sync --python 3.12
```

On Windows, double-click:

```text
start-hidemyemail.bat
```

For direct CLI usage:

```bash
uv run hidemyemail --help
```

## Windows Launcher

The Windows launcher is the recommended entry point for this fork.

```text
1. Generate emails
2. List active emails
3. List inactive emails
4. Manage iCloud cookie
5. Exit
```

Cookie management:

```text
1. Show current cookie account
2. Replace iCloud cookie
3. Auto capture iCloud cookie
4. Back
```

The launcher defaults to iCloud China:

```text
--region china
```

## CLI Reference

### Generate

```bash
uv run hidemyemail generate --label test --count 1 --cookie-file cookies.txt --region china
```

Options:

| Option | Description |
| --- | --- |
| `--label` | Label assigned to generated addresses. Required. |
| `--count` | Number of addresses to generate. Defaults to `1`. |
| `--cookie-file` | Path to the saved cookie file. Defaults to `cookies.txt`. |
| `--output` | File used to append generated addresses. Defaults to `emails.txt`. |
| `--no-output-file` | Print results without writing to an output file. |
| `--region` | `china` or `global`. |

### List

```bash
uv run hidemyemail list --active --cookie-file cookies.txt --region china
uv run hidemyemail list --inactive --cookie-file cookies.txt --region china
```

### Account Check

```bash
uv run hidemyemail whoami --cookie-file cookies.txt --region china
```

Example output:

```text
Current iCloud Cookie
Apple ID       +86 ***********
Name           Example User
DSID           ***********
Hide My Email  Available
User Partition 217
Maildomain     p217-maildomainws.icloud.com.cn
```

### Auto Capture Cookie

```bash
uv run hidemyemail capture-cookie --cookie-file cookies.txt --region china
```

## Cookie Management

The tool needs an authenticated iCloud browser cookie. Cookies stay local in
`cookies.txt`, which is ignored by Git.

### Automatic Capture

Recommended for iCloud China:

1. Run `start-hidemyemail.bat`.
2. Choose `4. Manage iCloud cookie`.
3. Choose `3. Auto capture iCloud cookie`.
4. Log in in the opened browser window if needed.
5. The tool opens iCloud Plus, clicks Hide My Email, captures the app request,
   validates the cookie, and writes `cookies.txt`.

The capture flow listens for this request:

```text
https://www.icloud.com.cn/applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
```

It uses a separate browser profile:

```text
.cookie-browser-profile
```

It does not read your everyday browser profile. If a new cookie is captured,
the previous file is backed up as:

```text
cookies.txt.bak
```

### Manual Capture

1. Open `https://www.icloud.com.cn/icloudplus/`.
2. Press `F12`.
3. Open `Network`.
4. Click the `隐藏邮件地址` tile.
5. Find the request ending with:

   ```text
   /applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
   ```

6. Right-click the request and choose `Copy` -> `Copy as cURL`.
7. Paste the entire copied text into `cookies.txt`.

Raw `Cookie:` header strings also work.

## Configuration

| Setting | Values | Notes |
| --- | --- | --- |
| `--region` | `china`, `global` | Selects iCloud China or global iCloud endpoints. |
| `HIDEMYEMAIL_REGION` | `china`, `global` | Optional environment default for CLI commands. |
| `cookies.txt` | local file | Stores the captured cookie in a Git-ignored file. |
| `emails.txt` | local file | Stores generated addresses unless `--no-output-file` is used. |

## Generated Files

These files are local-only and ignored by Git:

- `cookies.txt`
- `cookies.txt.bak`
- `emails.txt`
- `.cookie-browser-profile/`
- `.venv/`

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Missing X-APPLE-WEBAUTH-USER cookie` | Capture the Hide My Email app request instead of `feedbackws/reportStats`. |
| `Request timed out` | Retry. This fork uses longer timeouts and retries, but iCloud may still be slow. |
| Cookie account is wrong | Use launcher option `4 -> 1` to verify, then `4 -> 3` to capture a new cookie. |
| Browser does not open for capture | Install Microsoft Edge or run `uv run playwright install chromium`. |
| Chinese text looks garbled in old consoles | Use the launcher; it switches the console to UTF-8. |

## Security and Privacy

- Cookies are stored locally and ignored by Git.
- Automatic capture uses a separate browser profile.
- The project does not intentionally collect, upload, or share your cookies.
- Do not commit `cookies.txt`, `cookies.txt.bak`, `emails.txt`, or browser profile data.
- If a token or cookie is accidentally exposed, revoke it from the provider dashboard.

## Rate Limits

Apple may rate-limit Hide My Email creation. The upstream project notes an
observed limit of approximately `5 * number of people in your iCloud family`
new addresses every 30 minutes, with an observed total cap around 700 addresses.

## Disclaimer

This project is an independent community tool and is not affiliated with,
endorsed by, or sponsored by Apple Inc. Apple, iCloud, and Hide My Email are
trademarks of Apple Inc.

## Acknowledgements

- Original implementation by [rtuna](https://github.com/rtunazzz).
- This fork builds on [rtunazzz/hidemyemail-generator](https://github.com/rtunazzz/hidemyemail-generator).

## License

MIT. See [LICENSE](./LICENSE).

---

<a id="简体中文"></a>

## 简体中文

HideMyEmail Generator 是一个本地命令行工具，用于生成、保留和管理 Apple
iCloud「隐藏邮件地址」。

这个分支重点改进 Windows 和 iCloud 中国区体验：一键启动器、中国区接口、账号
Cookie 识别、自动 Cookie 捕获、分区自动检测，以及更稳定的网络超时和重试。

> 本项目基于 [rtunazzz/hidemyemail-generator](https://github.com/rtunazzz/hidemyemail-generator)。  
> 需要有效的 iCloud+ 订阅，才能生成「隐藏邮件地址」。

## 目录

- [功能亮点](#功能亮点)
- [快速开始](#快速开始)
- [Windows 启动器](#windows-启动器)
- [命令行用法](#命令行用法)
- [Cookie 管理](#cookie-管理)
- [配置](#配置)
- [本地文件](#本地文件)
- [故障排查](#故障排查)
- [安全和隐私](#安全和隐私)
- [免责声明](#免责声明)
- [致谢](#致谢)
- [许可证](#许可证)

## 功能亮点

| 功能 | 说明 |
| --- | --- |
| 生成地址 | 按指定标签创建并保留 iCloud「隐藏邮件地址」。 |
| 查看地址 | 查看使用中或已停用的隐藏邮件地址。 |
| 查看账号 | 显示当前 Cookie 对应的 Apple ID、DSID、用户分区和功能可用性。 |
| iCloud 中国区 | 使用 `icloud.com.cn` 的 Origin、校验接口和 maildomain 主机。 |
| 分区检测 | 从捕获请求或账号校验结果推导正确的 `pNNN-maildomainws` 主机。 |
| Windows 启动器 | 双击即可生成、查看和管理 Cookie。 |
| 自动捕获 Cookie | 打开 iCloud+，点击「隐藏邮件地址」，捕获应用请求并保存 Cookie。 |

## 快速开始

```bash
git clone https://github.com/never-seek/hidemyemail-generator.git
cd hidemyemail-generator
uv sync --python 3.12
```

Windows 下双击：

```text
start-hidemyemail.bat
```

直接使用命令行：

```bash
uv run hidemyemail --help
```

## Windows 启动器

推荐在 Windows 上使用启动器。

```text
1. Generate emails
2. List active emails
3. List inactive emails
4. Manage iCloud cookie
5. Exit
```

Cookie 管理菜单：

```text
1. Show current cookie account
2. Replace iCloud cookie
3. Auto capture iCloud cookie
4. Back
```

启动器默认使用 iCloud 中国区：

```text
--region china
```

## 命令行用法

### 生成地址

```bash
uv run hidemyemail generate --label test --count 1 --cookie-file cookies.txt --region china
```

常用参数：

| 参数 | 说明 |
| --- | --- |
| `--label` | 生成地址的标签，必填。 |
| `--count` | 生成数量，默认 `1`。 |
| `--cookie-file` | Cookie 文件路径，默认 `cookies.txt`。 |
| `--output` | 生成结果追加写入文件，默认 `emails.txt`。 |
| `--no-output-file` | 只打印结果，不写文件。 |
| `--region` | `china` 或 `global`。 |

### 查看地址

```bash
uv run hidemyemail list --active --cookie-file cookies.txt --region china
uv run hidemyemail list --inactive --cookie-file cookies.txt --region china
```

### 查看当前账号

```bash
uv run hidemyemail whoami --cookie-file cookies.txt --region china
```

示例输出：

```text
Current iCloud Cookie
Apple ID       +86 ***********
Name           Example User
DSID           ***********
Hide My Email  Available
User Partition 217
Maildomain     p217-maildomainws.icloud.com.cn
```

### 自动捕获 Cookie

```bash
uv run hidemyemail capture-cookie --cookie-file cookies.txt --region china
```

## Cookie 管理

工具需要已登录 iCloud 的浏览器 Cookie。Cookie 只保存在本地 `cookies.txt`，
并已加入 Git 忽略。

### 自动捕获

推荐用于 iCloud 中国区：

1. 运行 `start-hidemyemail.bat`。
2. 选择 `4. Manage iCloud cookie`。
3. 选择 `3. Auto capture iCloud cookie`。
4. 如果打开的浏览器要求登录，请登录 iCloud。
5. 工具会打开 iCloud+ 页面，点击「隐藏邮件地址」，捕获应用请求，校验 Cookie，
   并写入 `cookies.txt`。

自动捕获监听的请求：

```text
https://www.icloud.com.cn/applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
```

它使用独立浏览器配置目录：

```text
.cookie-browser-profile
```

它不会读取你的日常浏览器配置。如果成功捕获新 Cookie，旧文件会备份为：

```text
cookies.txt.bak
```

### 手动捕获

1. 打开 `https://www.icloud.com.cn/icloudplus/`。
2. 按 `F12`。
3. 打开 `Network / 网络`。
4. 点击「隐藏邮件地址」卡片。
5. 找到以下请求：

   ```text
   /applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
   ```

6. 右键请求，选择 `Copy / 复制` -> `Copy as cURL / 复制为 cURL`。
7. 将整段内容粘贴到 `cookies.txt`。

直接粘贴原始 `Cookie:` 请求头也可以。

## 配置

| 配置 | 值 | 说明 |
| --- | --- | --- |
| `--region` | `china`, `global` | 选择 iCloud 中国区或全球区接口。 |
| `HIDEMYEMAIL_REGION` | `china`, `global` | 可选的命令行默认区域。 |
| `cookies.txt` | 本地文件 | 保存捕获到的 Cookie。 |
| `emails.txt` | 本地文件 | 保存生成的隐藏邮件地址。 |

## 本地文件

以下文件只在本地使用，已加入 Git 忽略：

- `cookies.txt`
- `cookies.txt.bak`
- `emails.txt`
- `.cookie-browser-profile/`
- `.venv/`

## 故障排查

| 现象 | 处理方式 |
| --- | --- |
| `Missing X-APPLE-WEBAUTH-USER cookie` | 捕获「隐藏邮件地址」应用请求，不要使用 `feedbackws/reportStats`。 |
| `Request timed out` | 重试。这个分支已经增加超时和重试，但 iCloud 偶尔仍会慢。 |
| Cookie 对应账号不对 | 用启动器 `4 -> 1` 查看账号，再用 `4 -> 3` 重新捕获。 |
| 自动捕获无法打开浏览器 | 安装 Microsoft Edge，或运行 `uv run playwright install chromium`。 |
| 中文在旧控制台里乱码 | 使用启动器；启动器会切换到 UTF-8。 |

## 安全和隐私

- Cookie 只保存在本地，并已被 Git 忽略。
- 自动捕获使用独立浏览器配置。
- 项目不会主动收集、上传或分享你的 Cookie。
- 不要提交 `cookies.txt`、`cookies.txt.bak`、`emails.txt` 或浏览器配置目录。
- 如果 token 或 Cookie 被意外公开，请到对应平台撤销或重新生成。

## 频率限制

Apple 可能限制「隐藏邮件地址」创建频率。上游项目记录的经验值是：
每 30 分钟大约可创建 `5 * iCloud 家庭人数` 个地址，观察到的总量上限约为 700 个。

## 免责声明

本项目是独立社区工具，不隶属于 Apple Inc.，也未获得 Apple Inc. 的认可或赞助。
Apple、iCloud 和 Hide My Email 是 Apple Inc. 的商标。

## 致谢

- 原始实现来自 [rtuna](https://github.com/rtunazzz)。
- 本分支基于 [rtunazzz/hidemyemail-generator](https://github.com/rtunazzz/hidemyemail-generator)。

## 许可证

MIT。见 [LICENSE](./LICENSE)。
