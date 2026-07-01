<h1 align="center">HideMyEmail Generator</h1>

<p align="center">
  从本地命令行生成、保留和管理 iCloud「隐藏邮件地址」。
  <br>
  包含 Windows 启动器、iCloud 中国区支持、本地收件台和自动 Cookie 捕获。
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2ea44f"></a>
  <img alt="Python 3.12+" src="https://img.shields.io/badge/python-3.12%2B-3776ab?logo=python&logoColor=white">
  <a href="https://github.com/rtunazzz/hidemyemail-generator/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/rtunazzz/hidemyemail-generator?logo=github"></a>
  <a href="https://github.com/rtunazzz/hidemyemail-generator/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/rtunazzz/hidemyemail-generator/total?logo=github"></a>
</p>

<p align="center">
  <a href="./README.md">English</a>
  ·
  <strong>简体中文</strong>
</p>

> 需要有效的 iCloud+ 订阅，才能生成「隐藏邮件地址」。

## 目录

- [功能亮点](#功能亮点)
- [快速开始](#快速开始)
- [Windows 启动器](#windows-启动器)
- [命令行用法](#命令行用法)
- [Cookie 管理](#cookie-管理)
- [本地收件台和验证码](#本地收件台和验证码)
- [配置](#配置)
- [本地文件](#本地文件)
- [故障排查](#故障排查)
- [安全和隐私](#安全和隐私)
- [频率限制](#频率限制)
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
| 双语界面 | 启动器和 CLI 帮助包含英文和简体中文。 |
| 自动捕获 Cookie | 打开 iCloud+，点击「隐藏邮件地址」，捕获应用请求并保存 Cookie。 |
| 本地收件台 | 通过 IMAP 拉取转发邮件，并在本地提取验证码。 |
| 状态管理 | 将地址标记为 `unused`、`used` 或 `trash`。 |
| 表格导出 | 导出本地地址和邮件数据，便于表格管理。 |

## 快速开始

### 下载预构建二进制

从[最新发行版](https://github.com/rtunazzz/hidemyemail-generator/releases/latest)下载独立二进制文件，无需安装 Python 或 `uv`。

- **Windows：** 下载 `hidemyemail-windows.exe`。双击打开交互式菜单，或在终端中带参数运行以使用命令行（`hidemyemail-windows.exe --help`）。
- **macOS：** 下载 `hidemyemail-macos`，然后执行 `chmod +x hidemyemail-macos`。不带参数运行会打开菜单，带参数则进入命令行。该二进制未签名，首次启动会被 Gatekeeper 拦截——在访达中右键点击并选择**打开**即可放行。

预构建二进制使用手动获取 Cookie；自动获取（Playwright）仅在源码运行时可用。

### 源码运行

```bash
git clone https://github.com/rtunazzz/hidemyemail-generator.git
cd hidemyemail-generator
uv sync --python 3.12
```

Windows 下双击 `start-hidemyemail.bat`。直接使用命令行：

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
5. Local inbox and codes
6. Exit
```

Cookie 管理菜单：

```text
1. Show current cookie account
2. Replace iCloud cookie
3. Auto capture iCloud cookie
4. Back
```

收件台菜单：

```text
1. Configure inbox IMAP account
2. Sync inbox and show verification codes
3. Show recent verification codes
4. Show recent inbox messages
5. List unused local emails
6. Mark email as used
7. Move email to trash
8. Sync iCloud HME addresses to local DB
9. Export CSV files
10. Back
```

启动器默认使用 `global` 区域。如需使用 iCloud 中国区，请在启动前设置环境变量：

```text
HIDEMYEMAIL_REGION=china
```

## 命令行用法

命令默认使用 `global` 区域。加上 `--region china`（或设置
`HIDEMYEMAIL_REGION=china`）即可切换到 iCloud 中国区。

### 生成地址

```bash
uv run hidemyemail generate --label test --count 1 --cookie-file cookies.txt
```

常用参数：

| 参数 | 说明 |
| --- | --- |
| `--label` | 生成地址的标签，必填。 |
| `--count` | 生成数量，默认 `1`。 |
| `--cookie-file` | Cookie 文件路径，默认 `cookies.txt`。 |
| `--output` | 生成结果追加写入文件，默认 `emails.txt`。 |
| `--no-output-file` | 只打印结果，不写文件。 |
| `--region` | `global`（默认）或 `china`。 |

### 查看地址

```bash
uv run hidemyemail list --active --cookie-file cookies.txt
uv run hidemyemail list --inactive --cookie-file cookies.txt
```

### 查看当前账号

```bash
uv run hidemyemail whoami --cookie-file cookies.txt
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
uv sync --extra capture
uv run hidemyemail capture-cookie --cookie-file cookies.txt
```

### 本地收件台

配置接收 iCloud 转发邮件的邮箱：

```bash
uv run hidemyemail inbox setup
```

同步最新邮件并显示验证码：

```bash
uv run hidemyemail inbox sync --limit 100 --show-codes
```

查看最近验证码：

```bash
uv run hidemyemail inbox codes --limit 30
```

同步 iCloud 里已有的隐藏邮箱到本地数据库：

```bash
uv run hidemyemail inbox sync-hme --cookie-file cookies.txt
```

管理地址状态：

```bash
uv run hidemyemail inbox addresses --state unused
uv run hidemyemail inbox mark example@icloud.com used
uv run hidemyemail inbox mark example@icloud.com trash
```

导出 CSV：

```bash
uv run hidemyemail inbox export
```

## Cookie 管理

工具需要已登录 iCloud 的浏览器 Cookie。Cookie 只保存在本地 `cookies.txt`，
并已加入 Git 忽略。

### 自动捕获

1. 运行 `start-hidemyemail.bat`。
2. 选择 `4. Manage iCloud cookie`。
3. 选择 `3. Auto capture iCloud cookie`。
4. 如果打开的浏览器要求登录，请登录 iCloud。
5. 工具会打开 iCloud+ 页面，点击「隐藏邮件地址」，捕获应用请求，校验 Cookie，
   并写入 `cookies.txt`。

自动捕获监听的隐藏邮件地址应用请求：

```text
https://www.icloud.com/applications/hidemyemail/current/en-us/index.html?rootDomain=www
```

中国区对应的主机为 `www.icloud.com.cn`，语言段为 `zh-cn`。

它使用独立浏览器配置目录：

```text
.cookie-browser-profile
```

它不会读取你的日常浏览器配置。如果成功捕获新 Cookie，旧文件会备份为：

```text
cookies.txt.bak
```

### 手动捕获

1. 打开 `https://www.icloud.com/icloudplus/`（中国区使用 `www.icloud.com.cn`）。
2. 按 `F12`。
3. 打开 `Network / 网络`。
4. 点击「Hide My Email / 隐藏邮件地址」卡片。
5. 找到以下请求：

   ```text
   /applications/hidemyemail/current/en-us/index.html?rootDomain=www
   ```

6. 右键请求，选择 `Copy / 复制` -> `Copy as cURL / 复制为 cURL`。
7. 将整段内容粘贴到 `cookies.txt`。

直接粘贴原始 `Cookie:` 请求头也可以。

## 本地收件台和验证码

本地收件台通过 IMAP 读取接收 iCloud 隐藏邮箱转发邮件的邮箱。它会把邮件元数据、
匹配到的隐藏邮箱地址和提取出的验证码保存到本地 SQLite 数据库。

它会做：

- 连接你配置的接收邮箱 IMAP；
- 从指定文件夹同步新邮件；
- 从邮件标题和正文中提取可能的验证码；
- 尽量把邮件关联到已知隐藏邮箱；
- 将隐藏邮箱标记为 `unused`、`used` 或 `trash`；
- 导出 `addresses.csv` 和 `messages.csv`。

它不会做：

- 不上传邮件或验证码到任何服务器；
- 不需要公网部署；
- 不读取你的日常浏览器配置；
- 不绕过 Apple 或邮箱服务商的频率限制。

很多邮箱服务商要求使用“应用专用密码”，不要直接使用网页登录密码。

## 配置

| 配置 | 值 | 说明 |
| --- | --- | --- |
| `--region` | `china`, `global` | 选择 iCloud 中国区或全球区接口。 |
| `HIDEMYEMAIL_REGION` | `china`, `global` | 命令行和启动器的可选默认区域，默认 `global`。 |
| `cookies.txt` | 本地文件 | 保存捕获到的 Cookie。 |
| `emails.txt` | 本地文件 | 保存生成的隐藏邮件地址。 |
| `inbox_config.json` | 本地文件 | 保存接收邮箱 IMAP 配置。 |
| `hidemyemail.db` | 本地文件 | 保存地址、邮件元数据和验证码的 SQLite 数据库。 |

## 本地文件

以下文件只在本地使用，已加入 Git 忽略：

- `cookies.txt`
- `cookies.txt.bak`
- `emails.txt`
- `hidemyemail.db`
- `hidemyemail.db-*`
- `inbox_config.json`
- `exports/`
- `.cookie-browser-profile/`
- `.venv/`

## 故障排查

| 现象 | 处理方式 |
| --- | --- |
| `Missing X-APPLE-WEBAUTH-USER cookie` | 捕获「隐藏邮件地址」应用请求，不要使用 `feedbackws/reportStats`。 |
| `Request timed out` | 重试。命令行已经增加超时和重试，但 iCloud 偶尔仍会慢。 |
| Cookie 对应账号不对 | 用启动器 `4 -> 1` 查看账号，再用 `4 -> 3` 重新捕获。 |
| 自动捕获无法打开浏览器 | 安装 Microsoft Edge，然后运行 `uv sync --extra capture` 或 `uv run playwright install chromium`。 |
| 中文在旧控制台里乱码 | 使用启动器；启动器会切换到 UTF-8。 |
| IMAP 登录失败 | 确认邮箱已开启 IMAP，并按邮箱服务商要求使用应用专用密码。 |
| 没有识别出验证码 | 用 `hidemyemail inbox messages` 查看标题和正文预览；有些服务商格式不标准。 |

## 安全和隐私

- Cookie 只保存在本地，并已被 Git 忽略。
- IMAP 配置和本地收件数据只保存在本地，并已被 Git 忽略。
- 自动捕获使用独立浏览器配置。
- 项目不会主动收集、上传或分享你的 Cookie、邮件数据或验证码。
- 不要提交 `cookies.txt`、`cookies.txt.bak`、`emails.txt`、`inbox_config.json`、`hidemyemail.db`、导出目录或浏览器配置目录。
- 如果 token 或 Cookie 被意外公开，请到对应平台撤销或重新生成。

## 频率限制

Apple 可能限制「隐藏邮件地址」创建频率。经验值大约是：
每 30 分钟可创建 `5 * iCloud 家庭人数` 个地址，观察到的总量上限约为 700 个。

## 免责声明

本项目是独立社区工具，不隶属于 Apple Inc.，也未获得 Apple Inc. 的认可或赞助。
Apple、iCloud 和 Hide My Email 是 Apple Inc. 的商标。

## 致谢

- iCloud 中国区支持、Windows 启动器和本地收件台由 [@never-seek](https://github.com/never-seek) 贡献。
- 同时感谢其他[社区贡献者](https://github.com/rtunazzz/hidemyemail-generator/graphs/contributors)。

## 许可证

MIT。见 [LICENSE](./LICENSE)。
