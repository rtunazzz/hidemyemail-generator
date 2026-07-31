# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A small CLI that automates generation of Apple iCloud "Hide My Email" (HME) addresses via iCloud's private maildomain web API. Requires an active iCloud+ subscription and valid iCloud session cookies. Apple rate-limits to ~5 emails / 30 min per family member and caps total HME addresses at ~700.

## Commands

Python 3.12+ and [uv](https://docs.astral.sh/uv/) are required.

```bash
uv sync                                              # install deps + create .venv
uv run hidemyemail generate --label test --count 5   # generate + reserve N emails
uv run hidemyemail list                              # list existing HME addresses
uv run ruff check                                    # lint
uv run ruff format                                   # format
```

Run the macOS Swift tests with `xcodebuild` after changing the app.

### macOS build artifacts

**Xcode 26 or newer is required.** `HME-Gen-icon.icon` is an Icon Composer
document and only `actool` from Xcode 26 onwards can compile it. The build picks
an Xcode via `scripts/xcode-developer-dir.sh` (first `/Applications` Xcode with
major version >= 26, or an explicit `DEVELOPER_DIR`) rather than trusting the
`/Applications/Xcode.app` symlink, which on the GitHub runners points at 16.4.
Anything older fails with a clear error instead of building.

After every change under `macos/Sources/`, run
`scripts/build-macos-app.sh "$(uname -m)"` before handing off the work. The
script removes and regenerates `build/macos-app-$ARCH` and the matching macOS
ZIP and DMG in `dist/`; an Xcode build alone does not refresh those artifacts.
The distributable ZIP and DMG must never contain an Apple team signature.
For signed local builds, set `CODESIGN_IDENTITY` to a stable Apple Development
identity; the script applies it only to the ignored local app after packaging
identity-free release artifacts.

- `generate` options: `--label` (required), `--count` (default 1), `--cookie-file` (default `cookies.txt`), `--output` (default `emails.txt`), `--no-output-file`.
- `list` options: `--label-query` (regex matched against the Label field), `--active/--inactive` (default `--active`), `--cookie-file`.

## Authentication / cookies (important gotcha)

Auth is entirely cookie-based — there is no login flow. The user exports their iCloud session as a single "Header String" (Cookie-Editor browser extension on icloud.com/settings) and saves it to a file; that string is injected verbatim into the `Cookie` header of every request.

- Cookie file format: one header string per line; lines starting with `//` are treated as comments and skipped, and only the **first** non-comment line is used (see `RichHideMyEmail.__init__` in `main.py`).
- Default cookie filename is `icloud_cookies.txt` (`DEFAULT_COOKIE_FILENAME` in `main.py`), matching the README. Override with `--cookie-file`. If the file is missing, the app does **not** fail loudly — it logs a yellow `[WARN]` and sends an empty Cookie header, after which Apple rejects the request with `Missing X-APPLE-WEBAUTH-USER cookie`. That Apple error almost always means "cookie file not found / not loaded," not "your cookies are bad."
- Cookies expire; a fresh export is needed when requests start failing with auth errors.

## Architecture

Two modules under `src/hidemyemail_generator/`:

- **`hidemyemail.py`** — `HideMyEmail`, the low-level async API client (plain `aiohttp`, no UI). It is an async context manager (`async with`) that owns the `ClientSession`: the session is created in `__aenter__` with browser-mimicking headers plus the cookie string, and closed in `__aexit__`. Three methods, each returning a raw response dict and never raising — timeouts/exceptions are caught and returned as `{"error": 1, "reason": ...}`:
  - `generate_email()` → `POST {base_v1}/generate`
  - `reserve_email(email, label, note)` → `POST {base_v1}/reserve`
  - `list_email()` → `GET {base_v2}/list`
  - Base host is `p68-maildomainws.icloud.com`. A shared class-level `params` dict carries `clientBuildNumber` / `clientMasteringNumber` / etc.

- **`main.py`** — the Click CLI plus `RichHideMyEmail`, a subclass that layers the Rich console UI (colored logging, status spinner, table output) and file output on top of the base client without changing its logic. Entry point is the `cli` Click group (`pyproject.toml` console script `hidemyemail`). Two commands are registered, `generate` and `list` (handler functions are named `generatecommand`/`listcommand` and registered via `cli.add_command(..., name=...)`).

### Generation flow

`generate` → `asyncio.run(_generate(...))` → `RichHideMyEmail` (async ctx mgr) → `generate(label, count)`:

- Each email requires **two** sequential API calls — `generate_email()` then `reserve_email()` (see `_generate_one`). An address is not usable until reserved.
- Concurrency is controlled by **batching, not a semaphore**: the count is processed in batches of `MAX_CONCURRENT_TASKS = 10`, each batch run via `asyncio.gather`. A batch therefore issues ~20 concurrent requests (2 per email).
- Successful emails are **appended** (mode `a+`, not overwritten) to the output file, one per line.

## Maintenance note

Because this hits Apple's private/undocumented endpoints, the request headers and `params` values (client build numbers, User-Agent, `sec-ch-ua`) go stale whenever Apple updates its web client. The git history shows these are periodically refreshed/synced — when generation starts failing for non-auth reasons, updating those values in `hidemyemail.py` is the usual fix.
