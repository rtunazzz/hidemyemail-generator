<p align="center">
  <img width="64%" src="docs/header.png" alt="HideMyEmail Generator">
</p>

<h1 align="center">HideMyEmail Generator</h1>

<p align="center">
  Generate, reserve, and manage iCloud Hide My Email addresses from a local CLI.
  <br>
  Includes a Windows launcher, iCloud China support, local inbox, and automated cookie capture.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-2ea44f"></a>
  <img alt="Python 3.12+" src="https://img.shields.io/badge/python-3.12%2B-3776ab?logo=python&logoColor=white">
  <a href="https://github.com/rtunazzz/hidemyemail-generator/releases/latest"><img alt="Latest release" src="https://img.shields.io/github/v/release/rtunazzz/hidemyemail-generator?logo=github"></a>
  <a href="https://github.com/rtunazzz/hidemyemail-generator/releases"><img alt="Downloads" src="https://img.shields.io/github/downloads/rtunazzz/hidemyemail-generator/total?logo=github"></a>
</p>

<p align="center">
  <strong>English</strong>
  ·
  <a href="./README.zh-CN.md">简体中文</a>
</p>

> You need an active iCloud+ subscription to generate Hide My Email addresses.

## Overview

HideMyEmail Generator is a local command-line utility for Apple's iCloud Hide My
Email service. It generates and reserves new addresses, lists active or inactive
ones, and inspects the account behind the currently saved iCloud cookie.

Alongside the basics it provides:

- region-aware iCloud API targeting for `global` and `china`;
- automatic iCloud partition detection;
- a one-click Windows launcher;
- bilingual English / Simplified Chinese launcher and CLI output;
- account-aware cookie management with browser-assisted capture;
- a local IMAP inbox with verification-code extraction;
- local address state management (`unused`, `used`, `trash`);
- CSV export for addresses and received messages;
- longer timeouts and automatic retries for slower iCloud responses.

## Contents

- [Highlights](#highlights)
- [Quick Start](#quick-start)
- [Windows Launcher](#windows-launcher)
- [CLI Reference](#cli-reference)
- [Cookie Management](#cookie-management)
- [Local Inbox and Codes](#local-inbox-and-codes)
- [Configuration](#configuration)
- [Generated Files](#generated-files)
- [Troubleshooting](#troubleshooting)
- [Security and Privacy](#security-and-privacy)
- [Rate Limits](#rate-limits)
- [Disclaimer](#disclaimer)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Highlights

| Capability | Description |
| --- | --- |
| Generate addresses | Create and reserve iCloud Hide My Email addresses with a label. |
| List addresses | List active or inactive Hide My Email addresses. |
| Account check | Show the Apple ID, DSID, user partition, and Hide My Email availability for the saved cookie. |
| iCloud China support | Use `icloud.com.cn` origins, setup validation, and maildomain hosts. |
| Partition detection | Derive the correct `pNNN-maildomainws` host from captured requests or account validation. |
| Windows launcher | Double-click menu for generation, listing, and cookie management. |
| Bilingual UI | Launcher and CLI help include English and Simplified Chinese text. |
| Cookie capture | Open iCloud Plus, click Hide My Email, capture the app request, and save the cookie locally. |
| Local inbox | Fetch forwarded mail through IMAP and extract verification codes locally. |
| Status workflow | Track addresses as `unused`, `used`, or `trash`. |
| CSV export | Export local address and message data for spreadsheet workflows. |

## Quick Start

```bash
git clone https://github.com/rtunazzz/hidemyemail-generator.git
cd hidemyemail-generator
uv sync --python 3.12
```

On Windows, double-click `start-hidemyemail.bat`. For direct CLI usage:

```bash
uv run hidemyemail --help
```

## Windows Launcher

The Windows launcher is the recommended entry point for Windows users.

```text
1. Generate emails
2. List active emails
3. List inactive emails
4. Manage iCloud cookie
5. Local inbox and codes
6. Exit
```

Cookie management:

```text
1. Show current cookie account
2. Replace iCloud cookie
3. Auto capture iCloud cookie
4. Back
```

Inbox management:

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

The launcher defaults to the `global` region. To target iCloud China, set the
environment variable before launching:

```text
HIDEMYEMAIL_REGION=china
```

## CLI Reference

Commands default to the `global` region. Add `--region china` (or set
`HIDEMYEMAIL_REGION=china`) to target iCloud China.

### Generate

```bash
uv run hidemyemail generate --label test --count 1 --cookie-file cookies.txt
```

Options:

| Option | Description |
| --- | --- |
| `--label` | Label assigned to generated addresses. Required. |
| `--count` | Number of addresses to generate. Defaults to `1`. |
| `--cookie-file` | Path to the saved cookie file. Defaults to `cookies.txt`. |
| `--output` | File used to append generated addresses. Defaults to `emails.txt`. |
| `--no-output-file` | Print results without writing to an output file. |
| `--region` | `global` (default) or `china`. |

### List

```bash
uv run hidemyemail list --active --cookie-file cookies.txt
uv run hidemyemail list --inactive --cookie-file cookies.txt
```

### Account Check

```bash
uv run hidemyemail whoami --cookie-file cookies.txt
```

Example output:

```text
Current iCloud Cookie
Apple ID       user@example.com
Name           Example User
DSID           ***********
Hide My Email  Available
User Partition 68
Maildomain     p68-maildomainws.icloud.com
```

### Auto Capture Cookie

```bash
uv sync --extra capture
uv run hidemyemail capture-cookie --cookie-file cookies.txt
```

### Local Inbox

Configure the receiving mailbox used by iCloud Hide My Email forwarding:

```bash
uv run hidemyemail inbox setup
```

Sync the latest inbox messages and show extracted verification codes:

```bash
uv run hidemyemail inbox sync --limit 100 --show-codes
```

Show recent codes:

```bash
uv run hidemyemail inbox codes --limit 30
```

Sync existing iCloud Hide My Email addresses into the local database:

```bash
uv run hidemyemail inbox sync-hme --cookie-file cookies.txt
```

Track address state:

```bash
uv run hidemyemail inbox addresses --state unused
uv run hidemyemail inbox mark example@icloud.com used
uv run hidemyemail inbox mark example@icloud.com trash
```

Export local CSV files:

```bash
uv run hidemyemail inbox export
```

## Cookie Management

The tool needs an authenticated iCloud browser cookie. Cookies stay local in
`cookies.txt`, which is ignored by Git.

### Automatic Capture

1. Run `start-hidemyemail.bat`.
2. Choose `4. Manage iCloud cookie`.
3. Choose `3. Auto capture iCloud cookie`.
4. Log in in the opened browser window if needed.
5. The tool opens iCloud Plus, clicks Hide My Email, captures the app request,
   validates the cookie, and writes `cookies.txt`.

The capture flow listens for the Hide My Email app request:

```text
https://www.icloud.com/applications/hidemyemail/current/en-us/index.html?rootDomain=www
```

For iCloud China the host is `www.icloud.com.cn` and the locale segment is
`zh-cn`.

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

1. Open `https://www.icloud.com/icloudplus/` (use `www.icloud.com.cn` for China).
2. Press `F12`.
3. Open `Network`.
4. Click the `Hide My Email` tile (`隐藏邮件地址` on China).
5. Find the request ending with:

   ```text
   /applications/hidemyemail/current/en-us/index.html?rootDomain=www
   ```

6. Right-click the request and choose `Copy` -> `Copy as cURL`.
7. Paste the entire copied text into `cookies.txt`.

Raw `Cookie:` header strings also work.

## Local Inbox and Codes

The local inbox feature uses IMAP to read the mailbox that receives forwarded
mail from iCloud Hide My Email. It stores message metadata, matched Hide My Email
addresses, and extracted verification codes in a local SQLite database.

What it does:

- connects to your receiving mailbox through IMAP;
- fetches new messages from the configured folder;
- extracts likely verification codes from subjects and message bodies;
- links messages to known Hide My Email addresses when possible;
- tracks local address state as `unused`, `used`, or `trash`;
- exports `addresses.csv` and `messages.csv`.

What it does not do:

- it does not upload mail or codes to any server;
- it does not require public deployment;
- it does not read your everyday browser profile;
- it does not bypass Apple or mailbox provider rate limits.

For many mail providers, you should use an app password instead of your normal
mailbox password.

## Configuration

| Setting | Values | Notes |
| --- | --- | --- |
| `--region` | `china`, `global` | Selects iCloud China or global iCloud endpoints. |
| `HIDEMYEMAIL_REGION` | `china`, `global` | Optional default region for the CLI and launcher. Defaults to `global`. |
| `cookies.txt` | local file | Stores the captured cookie in a Git-ignored file. |
| `emails.txt` | local file | Stores generated addresses unless `--no-output-file` is used. |
| `inbox_config.json` | local file | Stores IMAP settings for the receiving mailbox. |
| `hidemyemail.db` | local file | SQLite database for addresses, message metadata, and codes. |

## Generated Files

These files are local-only and ignored by Git:

- `cookies.txt`
- `cookies.txt.bak`
- `emails.txt`
- `hidemyemail.db`
- `hidemyemail.db-*`
- `inbox_config.json`
- `exports/`
- `.cookie-browser-profile/`
- `.venv/`

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `Missing X-APPLE-WEBAUTH-USER cookie` | Capture the Hide My Email app request instead of `feedbackws/reportStats`. |
| `Request timed out` | Retry. The CLI uses longer timeouts and retries, but iCloud may still be slow. |
| Cookie account is wrong | Use launcher option `4 -> 1` to verify, then `4 -> 3` to capture a new cookie. |
| Browser does not open for capture | Install Microsoft Edge, then run `uv sync --extra capture` or `uv run playwright install chromium`. |
| Chinese text looks garbled in old consoles | Use the launcher; it switches the console to UTF-8. |
| IMAP login fails | Enable IMAP in your mailbox provider and use an app password if required. |
| No verification code is detected | Open `hidemyemail inbox messages` and inspect the subject/body preview; some providers use non-standard formats. |

## Security and Privacy

- Cookies are stored locally and ignored by Git.
- IMAP configuration and local mailbox data are stored locally and ignored by Git.
- Automatic capture uses a separate browser profile.
- The project does not intentionally collect, upload, or share your cookies, email data, or verification codes.
- Do not commit `cookies.txt`, `cookies.txt.bak`, `emails.txt`, `inbox_config.json`, `hidemyemail.db`, exports, or browser profile data.
- If a token or cookie is accidentally exposed, revoke it from the provider dashboard.

## Rate Limits

Apple may rate-limit Hide My Email creation. Observed limits are roughly
`5 * number of people in your iCloud family` new addresses every 30 minutes,
with a total cap around 700 addresses.

## Disclaimer

This project is an independent community tool and is not affiliated with,
endorsed by, or sponsored by Apple Inc. Apple, iCloud, and Hide My Email are
trademarks of Apple Inc.

## Acknowledgements

- iCloud China support, the Windows launcher, and the local inbox were
  contributed by [@never-seek](https://github.com/never-seek).
- Thanks to all other [community contributors](https://github.com/rtunazzz/hidemyemail-generator/graphs/contributors).

## License

MIT. See [LICENSE](./LICENSE).
