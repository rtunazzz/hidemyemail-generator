# HideMyEmail Generator

English | [简体中文](#简体中文)

Automated generation and listing of Apple's iCloud Hide My Email addresses.

This fork adds Windows-friendly setup, iCloud China support, a one-click launcher,
cookie account inspection, automatic cookie capture, and more resilient network
timeouts/retries.

Original project: [rtunazzz/hidemyemail-generator](https://github.com/rtunazzz/hidemyemail-generator)

> You need an active iCloud+ subscription to generate Hide My Email addresses.

## Features

- Generate iCloud Hide My Email addresses from the command line.
- List active and inactive Hide My Email addresses.
- Support both global iCloud and iCloud China regions.
- Auto-detect the iCloud maildomain partition from captured requests or account
  validation.
- Windows one-click launcher: `start-hidemyemail.bat`.
- Cookie management menu:
  - show the current saved iCloud account;
  - manually replace cookies;
  - automatically capture the Hide My Email app cookie.
- Longer request timeout and retry handling for slower iCloud China responses.

## Requirements

- Python 3.12+
- [uv](https://docs.astral.sh/uv/)
- Microsoft Edge or Chrome for automatic cookie capture

## Setup

```bash
git clone https://github.com/never-seek/hidemyemail-generator.git
cd hidemyemail-generator
uv sync --python 3.12
```

On Windows, you can then double-click:

```text
start-hidemyemail.bat
```

## Windows Launcher

The launcher provides:

```text
1. Generate emails
2. List active emails
3. List inactive emails
4. Manage iCloud cookie
5. Exit
```

Cookie management provides:

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

## CLI Usage

Generate one email:

```bash
uv run hidemyemail generate --label test --count 1 --cookie-file cookies.txt --region china
```

List active emails:

```bash
uv run hidemyemail list --active --cookie-file cookies.txt --region china
```

List inactive emails:

```bash
uv run hidemyemail list --inactive --cookie-file cookies.txt --region china
```

Show the account represented by the saved cookie:

```bash
uv run hidemyemail whoami --cookie-file cookies.txt --region china
```

Automatically capture the Hide My Email app cookie:

```bash
uv run hidemyemail capture-cookie --cookie-file cookies.txt --region china
```

For global iCloud, use:

```bash
--region global
```

## Cookie Setup

The tool needs an authenticated iCloud browser cookie. The cookie is stored
locally in `cookies.txt`, which is ignored by Git.

### Automatic Capture

Recommended on Windows:

1. Run `start-hidemyemail.bat`.
2. Choose `4. Manage iCloud cookie`.
3. Choose `3. Auto capture iCloud cookie`.
4. Log in in the opened browser window if needed.
5. The tool opens iCloud Plus, clicks Hide My Email, captures the app request,
   and writes `cookies.txt`.

The automatic capture flow listens for this request:

```text
https://www.icloud.com.cn/applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
```

It uses a separate browser profile:

```text
.cookie-browser-profile
```

It does not clear an existing `cookies.txt` unless a new cookie is captured.
When replacing cookies, the old file is backed up as:

```text
cookies.txt.bak
```

### Manual Capture

1. Open `https://www.icloud.com.cn/icloudplus/`.
2. Press `F12`.
3. Open the `Network` tab.
4. Click the `隐藏邮件地址` tile.
5. Find the request ending with:

   ```text
   /applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
   ```

6. Right-click it and choose `Copy` -> `Copy as cURL`.
7. Paste the whole copied text into `cookies.txt`.

Raw cookie header strings also work.

## Generated Files

These files are local-only and ignored by Git:

- `cookies.txt`
- `cookies.txt.bak`
- `emails.txt`
- `.cookie-browser-profile/`

## Notes

Apple may rate-limit Hide My Email creation. The original project notes that
Apple allows approximately `5 * number of people in your iCloud family` new
addresses every 30 minutes, with an observed total cap around 700 addresses.

## License

MIT. See [LICENSE](./LICENSE).

---

## 简体中文

自动生成和查看 Apple iCloud「隐藏邮件地址」的命令行工具。

这个分支在原项目基础上增加了 Windows 友好部署、iCloud 中国区支持、一键启动器、
Cookie 账号识别、自动 Cookie 捕获，以及更稳定的网络超时和重试处理。

原项目：[rtunazzz/hidemyemail-generator](https://github.com/rtunazzz/hidemyemail-generator)

> 需要有效的 iCloud+ 订阅，才能生成「隐藏邮件地址」。

## 功能

- 生成 iCloud「隐藏邮件地址」。
- 查看使用中和已停用的隐藏邮件地址。
- 支持全球区 iCloud 和 iCloud 中国区。
- 根据捕获到的请求或账号校验结果自动识别 iCloud 分区。
- Windows 一键启动器：`start-hidemyemail.bat`。
- Cookie 管理菜单：
  - 查看当前保存的 iCloud 账号；
  - 手动替换 Cookie；
  - 自动捕获「隐藏邮件地址」应用请求 Cookie。
- 针对 iCloud 中国区偶发慢响应，增加更长超时和重试。

## 环境要求

- Python 3.12+
- [uv](https://docs.astral.sh/uv/)
- Microsoft Edge 或 Chrome，用于自动捕获 Cookie

## 安装

```bash
git clone https://github.com/never-seek/hidemyemail-generator.git
cd hidemyemail-generator
uv sync --python 3.12
```

Windows 下可以直接双击：

```text
start-hidemyemail.bat
```

## Windows 一键启动器

主菜单：

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

生成 1 个地址：

```bash
uv run hidemyemail generate --label test --count 1 --cookie-file cookies.txt --region china
```

查看使用中的地址：

```bash
uv run hidemyemail list --active --cookie-file cookies.txt --region china
```

查看已停用的地址：

```bash
uv run hidemyemail list --inactive --cookie-file cookies.txt --region china
```

查看当前 Cookie 对应的 iCloud 账号：

```bash
uv run hidemyemail whoami --cookie-file cookies.txt --region china
```

自动捕获「隐藏邮件地址」应用 Cookie：

```bash
uv run hidemyemail capture-cookie --cookie-file cookies.txt --region china
```

如果使用全球区 iCloud：

```bash
--region global
```

## Cookie 设置

工具需要一个已登录 iCloud 的浏览器 Cookie。Cookie 保存在本地 `cookies.txt`，
并且已被 Git 忽略，不会提交到仓库。

### 自动捕获

Windows 推荐流程：

1. 运行 `start-hidemyemail.bat`。
2. 选择 `4. Manage iCloud cookie`。
3. 选择 `3. Auto capture iCloud cookie`。
4. 如果打开的浏览器要求登录，请登录 iCloud。
5. 工具会打开 iCloud+ 页面，点击「隐藏邮件地址」，捕获应用请求，并写入 `cookies.txt`。

自动捕获监听的目标请求是：

```text
https://www.icloud.com.cn/applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
```

它使用单独的浏览器配置目录：

```text
.cookie-browser-profile
```

如果没有捕获到新 Cookie，不会清空原有 `cookies.txt`。捕获成功并替换时，旧文件会备份为：

```text
cookies.txt.bak
```

### 手动捕获

1. 打开 `https://www.icloud.com.cn/icloudplus/`。
2. 按 `F12`。
3. 打开 `Network / 网络`。
4. 点击「隐藏邮件地址」卡片。
5. 找到这个请求：

   ```text
   /applications/hidemyemail/current/zh-cn/index.html?rootDomain=www
   ```

6. 右键该请求，选择 `Copy / 复制` -> `Copy as cURL / 复制为 cURL`。
7. 把整段内容粘贴到 `cookies.txt`。

直接粘贴原始 Cookie Header String 也可以。

## 本地生成文件

以下文件只保存在本地，已加入 Git 忽略：

- `cookies.txt`
- `cookies.txt.bak`
- `emails.txt`
- `.cookie-browser-profile/`

## 说明

Apple 可能会限制「隐藏邮件地址」创建频率。原项目说明的经验值是：
每 30 分钟大约可创建 `5 * iCloud 家庭人数` 个地址，总量上限观察值约为 700 个。

## 许可证

MIT。见 [LICENSE](./LICENSE)。
