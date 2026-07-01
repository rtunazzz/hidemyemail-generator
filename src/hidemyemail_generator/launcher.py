import os
import shutil
import subprocess
import sys
from pathlib import Path


REGION = os.environ.get("HIDEMYEMAIL_REGION", "global").lower()
COOKIE_FILE = "cookies.txt"


def icloud_origin() -> str:
    return "https://www.icloud.com.cn" if REGION == "china" else "https://www.icloud.com"


def configure_console() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


def clear() -> None:
    os.system("cls" if os.name == "nt" else "clear")


def pause() -> None:
    input("\nPress Enter to continue / 按 Enter 继续...")


def run_cli(*args: str) -> int:
    command = [sys.executable, "-m", "hidemyemail_generator.main", *args]
    return subprocess.run(command).returncode


def has_cookies() -> bool:
    path = Path(COOKIE_FILE)
    return path.exists() and path.stat().st_size > 0


def ensure_cookies() -> bool:
    if has_cookies():
        return True
    print("[INFO] cookies.txt is missing or empty / cookies.txt 不存在或为空.")
    show_cookie_help()
    if has_cookies():
        return True
    print("[ERROR] cookies.txt is still empty / cookies.txt 仍然为空.")
    pause()
    return False


def open_url(url: str) -> None:
    if os.name == "nt":
        os.startfile(url)  # type: ignore[attr-defined]
    else:
        subprocess.Popen(["xdg-open", url])


def open_notepad(path: str) -> None:
    if os.name == "nt":
        subprocess.run(["notepad.exe", path])
    else:
        editor = os.environ.get("EDITOR", "nano")
        subprocess.run([editor, path])


def show_cookie_help() -> None:
    origin = icloud_origin()
    print()
    print("This opens iCloud and cookies.txt.")
    print("将打开 iCloud 页面和 cookies.txt。")
    print("Existing cookies.txt will not be cleared automatically.")
    print("现有 cookies.txt 不会被自动清空。")
    print("To replace it, press Ctrl+A in Notepad, paste the new cURL text, then save.")
    print("如需替换，请在记事本中按 Ctrl+A，粘贴新的 cURL 内容，然后保存。")
    print("A backup will be saved as cookies.txt.bak before Notepad opens.")
    print("打开记事本前会备份为 cookies.txt.bak。")
    print()
    print("Steps in your browser / 浏览器操作步骤:")
    print(f"1. Sign in to {origin}/settings/ / 登录")
    print("2. Press F12 / 按 F12")
    print("3. Open the Network tab / 点击 Network 网络")
    print("4. Refresh the page / 刷新页面")
    print("5. Search hme or maildomainws in the filter box / 在过滤框搜索 hme 或 maildomainws")
    print("6. Right-click a maildomainws or hme request if one appears;")
    print("   otherwise pick a signed-in settings request.")
    print("   Avoid feedbackws/reportStats; it usually misses the auth cookie.")
    print("   如果看到 maildomainws 或 hme 请求，右键它；否则选择已登录状态下的设置页请求。")
    print("   不要使用 feedbackws/reportStats，因为它通常缺少授权 Cookie。")
    print("7. Choose Copy, then Copy as cURL / 点击 Copy 复制，然后 Copy as cURL 复制为 cURL")
    print("8. Paste the whole text into cookies.txt / 将整段内容粘贴到 cookies.txt")
    print("9. Save and close Notepad / 保存并关闭记事本")
    print()

    cookie_path = Path(COOKIE_FILE)
    if cookie_path.exists() and cookie_path.stat().st_size > 0:
        shutil.copy2(cookie_path, f"{COOKIE_FILE}.bak")
    cookie_path.touch(exist_ok=True)
    open_url(f"{origin}/settings/")
    open_notepad(COOKIE_FILE)


def main_menu() -> None:
    while True:
        clear()
        print("HideMyEmail Generator / iCloud 隐藏邮箱工具")
        print()
        print("1. Generate emails / 生成隐藏邮箱")
        print("2. List active emails / 查看使用中地址")
        print("3. List inactive emails / 查看已停用地址")
        print("4. Manage iCloud cookie / 管理 iCloud Cookie")
        print("5. Local inbox and codes / 本地收件台和验证码")
        print("6. Exit / 退出")
        print()
        choice = input("Choose an option / 请选择 [1-6]: ").strip()

        if choice == "1":
            generate()
        elif choice == "2":
            list_active()
        elif choice == "3":
            list_inactive()
        elif choice == "4":
            cookie_menu()
        elif choice == "5":
            inbox_menu()
        elif choice == "6":
            return


def generate() -> None:
    if not ensure_cookies():
        return
    print()
    label = input("Label for generated emails / 标签: ").strip() or "generated"
    count = input("How many emails to generate / 生成数量 [1]: ").strip() or "1"
    code = run_cli(
        "generate",
        "--label",
        label,
        "--count",
        count,
        "--cookie-file",
        COOKIE_FILE,
        "--output",
        "emails.txt",
        "--region",
        REGION,
    )
    if code:
        print("[ERROR] Generate command failed / 生成失败.")
    pause()


def list_active() -> None:
    if not ensure_cookies():
        return
    code = run_cli("list", "--active", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] List active command failed / 查看使用中地址失败.")
    pause()


def list_inactive() -> None:
    if not ensure_cookies():
        return
    code = run_cli("list", "--inactive", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] List inactive command failed / 查看已停用地址失败.")
    pause()


def cookie_menu() -> None:
    while True:
        clear()
        print("iCloud Cookie / iCloud Cookie 管理")
        print()
        print("1. Show current cookie account / 查看当前 Cookie 账号")
        print("2. Replace iCloud cookie / 手动替换 iCloud Cookie")
        print("3. Auto capture iCloud cookie / 自动获取 iCloud Cookie")
        print("4. Back / 返回")
        print()
        choice = input("Choose an option / 请选择 [1-4]: ").strip()

        if choice == "1":
            show_cookie_account()
        elif choice == "2":
            show_cookie_help()
            pause()
        elif choice == "3":
            auto_capture_cookies()
        elif choice == "4":
            return


def show_cookie_account() -> None:
    if not has_cookies():
        print("[INFO] cookies.txt is missing or empty / cookies.txt 不存在或为空.")
        print("Use option 2 to add an iCloud cookie / 请使用选项 2 添加 iCloud Cookie.")
        pause()
        return
    code = run_cli("whoami", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] Could not identify current cookie account / 无法识别当前 Cookie 账号.")
    pause()


def auto_capture_cookies() -> None:
    print()
    print("This opens a separate browser profile for cookie capture.")
    print("将打开一个独立浏览器配置用于获取 Cookie。")
    print("Log in if needed. The tool will open iCloud Plus, click Hide My Email,")
    print("capture the Hide My Email app request, and save cookies.txt.")
    print("如需登录请在浏览器中登录。工具会打开 iCloud+，点击隐藏邮件地址，")
    print("捕获应用请求并保存 cookies.txt。")
    print()
    code = run_cli("capture-cookie", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] Auto cookie capture failed / 自动获取 Cookie 失败.")
    pause()


def inbox_menu() -> None:
    while True:
        clear()
        print("Local Inbox and Codes / 本地收件台和验证码")
        print()
        print("1. Configure inbox IMAP account / 配置收件邮箱 IMAP")
        print("2. Sync inbox and show verification codes / 同步收件箱并显示验证码")
        print("3. Show recent verification codes / 查看最近验证码")
        print("4. Show recent inbox messages / 查看最近邮件")
        print("5. List unused local emails / 查看未使用本地邮箱")
        print("6. Mark email as used / 标记邮箱为已使用")
        print("7. Move email to trash / 移入垃圾箱")
        print("8. Sync iCloud HME addresses to local DB / 同步 iCloud 隐藏邮箱到本地库")
        print("9. Export CSV files / 导出 CSV 表格")
        print("10. Back / 返回")
        print()
        choice = input("Choose an option / 请选择 [1-10]: ").strip()

        if choice == "1":
            inbox_setup()
        elif choice == "2":
            inbox_sync()
        elif choice == "3":
            inbox_codes()
        elif choice == "4":
            inbox_messages()
        elif choice == "5":
            inbox_unused()
        elif choice == "6":
            inbox_mark("used")
        elif choice == "7":
            inbox_mark("trash")
        elif choice == "8":
            inbox_sync_hme()
        elif choice == "9":
            inbox_export()
        elif choice == "10":
            return


def inbox_setup() -> None:
    print()
    print("Configure your receiving mailbox IMAP account.")
    print("配置用于接收转发邮件的邮箱 IMAP 账号。")
    print("For many providers, use an app password instead of the login password.")
    print("很多邮箱需要使用应用专用密码，不要用网页登录密码。")
    print("The config is saved locally in inbox_config.json.")
    print("配置会保存在本地 inbox_config.json。")
    print()
    code = run_cli("inbox", "setup")
    if code:
        print("[ERROR] Inbox setup failed / 收件台配置失败.")
    pause()


def inbox_sync() -> None:
    code = run_cli("inbox", "sync", "--limit", "100", "--show-codes")
    if code:
        print("[ERROR] Inbox sync failed / 收件箱同步失败.")
    pause()


def inbox_codes() -> None:
    code = run_cli("inbox", "codes", "--limit", "30")
    if code:
        print("[ERROR] Could not show codes / 无法显示验证码.")
    pause()


def inbox_messages() -> None:
    code = run_cli("inbox", "messages", "--limit", "30")
    if code:
        print("[ERROR] Could not show messages / 无法显示邮件.")
    pause()


def inbox_unused() -> None:
    code = run_cli("inbox", "addresses", "--state", "unused", "--limit", "100")
    if code:
        print("[ERROR] Could not show local emails / 无法显示本地邮箱.")
    pause()


def inbox_mark(state: str) -> None:
    prompt = (
        "Email to mark as used / 要标记为已使用的邮箱: "
        if state == "used"
        else "Email to move to trash / 要移入垃圾箱的邮箱: "
    )
    email = input(prompt).strip()
    if not email:
        return
    code = run_cli("inbox", "mark", email, state)
    if code:
        print("[ERROR] Could not mark email / 无法标记邮箱.")
    pause()


def inbox_sync_hme() -> None:
    if not ensure_cookies():
        return
    code = run_cli("inbox", "sync-hme", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] Could not sync iCloud HME addresses / 无法同步 iCloud 隐藏邮箱.")
    pause()


def inbox_export() -> None:
    code = run_cli("inbox", "export")
    if code:
        print("[ERROR] Export failed / 导出失败.")
    pause()


def main() -> None:
    configure_console()
    main_menu()


if __name__ == "__main__":
    main()
