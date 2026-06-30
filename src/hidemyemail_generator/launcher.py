import os
import shutil
import subprocess
import sys
from pathlib import Path


REGION = os.environ.get("HIDEMYEMAIL_REGION", "global")
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
    input("\n按 Enter 继续 / Press Enter to continue...")


def run_cli(*args: str) -> int:
    command = [sys.executable, "-m", "hidemyemail_generator.main", *args]
    return subprocess.run(command).returncode


def has_cookies() -> bool:
    path = Path(COOKIE_FILE)
    return path.exists() and path.stat().st_size > 0


def ensure_cookies() -> bool:
    if has_cookies():
        return True
    print("[INFO] cookies.txt 不存在或为空 / cookies.txt is missing or empty.")
    show_cookie_help()
    if has_cookies():
        return True
    print("[ERROR] cookies.txt 仍然为空 / cookies.txt is still empty.")
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
    print("将打开 iCloud 页面和 cookies.txt。")
    print("This opens iCloud and cookies.txt.")
    print("现有 cookies.txt 不会被自动清空。")
    print("Existing cookies.txt will not be cleared automatically.")
    print("如需替换，请在记事本中按 Ctrl+A，粘贴新的 cURL 内容，然后保存。")
    print("To replace it, press Ctrl+A in Notepad, paste the new cURL text, then save.")
    print("打开记事本前会备份为 cookies.txt.bak。")
    print("A backup will be saved as cookies.txt.bak before Notepad opens.")
    print()
    print("浏览器操作步骤 / Steps in your browser:")
    print(f"1. 登录 {origin}/settings/")
    print("2. 按 F12")
    print("3. 点击 Network / 网络")
    print("4. 刷新页面")
    print("5. 在过滤框搜索 hme 或 maildomainws")
    print("6. 如果看到 maildomainws 或 hme 请求，右键它")
    print("   如果只有其他请求，选择已登录状态下的设置页请求")
    print("   不要使用 feedbackws/reportStats，因为它通常缺少授权 Cookie")
    print("7. 点击 Copy / 复制，然后 Copy as cURL / 复制为 cURL")
    print("8. 将整段内容粘贴到 cookies.txt")
    print("9. 保存并关闭记事本")
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
        print("1. 生成隐藏邮箱 / Generate emails")
        print("2. 查看使用中地址 / List active emails")
        print("3. 查看已停用地址 / List inactive emails")
        print("4. 管理 iCloud Cookie / Manage iCloud cookie")
        print("5. 本地收件台和验证码 / Local inbox and codes")
        print("6. 退出 / Exit")
        print()
        choice = input("请选择 / Choose an option [1-6]: ").strip()

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
    label = input("标签 / Label for generated emails: ").strip() or "generated"
    count = input("生成数量 / How many emails to generate [1]: ").strip() or "1"
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
        print("[ERROR] 生成失败 / Generate command failed.")
    pause()


def list_active() -> None:
    if not ensure_cookies():
        return
    code = run_cli("list", "--active", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] 查看使用中地址失败 / List active command failed.")
    pause()


def list_inactive() -> None:
    if not ensure_cookies():
        return
    code = run_cli("list", "--inactive", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] 查看已停用地址失败 / List inactive command failed.")
    pause()


def cookie_menu() -> None:
    while True:
        clear()
        print("iCloud Cookie 管理 / iCloud Cookie")
        print()
        print("1. 查看当前 Cookie 账号 / Show current cookie account")
        print("2. 手动替换 iCloud Cookie / Replace iCloud cookie")
        print("3. 自动获取 iCloud Cookie / Auto capture iCloud cookie")
        print("4. 返回 / Back")
        print()
        choice = input("请选择 / Choose an option [1-4]: ").strip()

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
        print("[INFO] cookies.txt 不存在或为空 / cookies.txt is missing or empty.")
        print("请使用选项 2 添加 iCloud Cookie / Use option 2 to add an iCloud cookie.")
        pause()
        return
    code = run_cli("whoami", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] 无法识别当前 Cookie 账号 / Could not identify current cookie account.")
    pause()


def auto_capture_cookies() -> None:
    print()
    print("将打开一个独立浏览器配置用于获取 Cookie。")
    print("This opens a separate browser profile for cookie capture.")
    print("如需登录，请在浏览器中登录。工具会打开 iCloud+，点击隐藏邮件地址，")
    print("捕获应用请求并保存 cookies.txt。")
    print("Log in if needed. The tool will open iCloud Plus, click Hide My Email,")
    print("capture the Hide My Email app request, and save cookies.txt.")
    print()
    code = run_cli("capture-cookie", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] 自动获取 Cookie 失败 / Auto cookie capture failed.")
    pause()


def inbox_menu() -> None:
    while True:
        clear()
        print("本地收件台和验证码 / Local Inbox and Codes")
        print()
        print("1. 配置收件邮箱 IMAP / Configure inbox IMAP account")
        print("2. 同步收件箱并显示验证码 / Sync inbox and show verification codes")
        print("3. 查看最近验证码 / Show recent verification codes")
        print("4. 查看最近邮件 / Show recent inbox messages")
        print("5. 查看未使用本地邮箱 / List unused local emails")
        print("6. 标记邮箱为已使用 / Mark email as used")
        print("7. 移入垃圾箱 / Move email to trash")
        print("8. 同步 iCloud 隐藏邮箱到本地库 / Sync iCloud HME addresses to local DB")
        print("9. 导出 CSV 表格 / Export CSV files")
        print("10. 返回 / Back")
        print()
        choice = input("请选择 / Choose an option [1-10]: ").strip()

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
    print("配置用于接收转发邮件的邮箱 IMAP 账号。")
    print("Configure your receiving mailbox IMAP account.")
    print("很多邮箱需要使用“应用专用密码”，不要用网页登录密码。")
    print("For many providers, use an app password instead of the normal login password.")
    print("配置会保存在本地 inbox_config.json。")
    print("The config is saved locally in inbox_config.json.")
    print()
    code = run_cli("inbox", "setup")
    if code:
        print("[ERROR] 收件台配置失败 / Inbox setup failed.")
    pause()


def inbox_sync() -> None:
    code = run_cli("inbox", "sync", "--limit", "100", "--show-codes")
    if code:
        print("[ERROR] 收件箱同步失败 / Inbox sync failed.")
    pause()


def inbox_codes() -> None:
    code = run_cli("inbox", "codes", "--limit", "30")
    if code:
        print("[ERROR] 无法显示验证码 / Could not show codes.")
    pause()


def inbox_messages() -> None:
    code = run_cli("inbox", "messages", "--limit", "30")
    if code:
        print("[ERROR] 无法显示邮件 / Could not show messages.")
    pause()


def inbox_unused() -> None:
    code = run_cli("inbox", "addresses", "--state", "unused", "--limit", "100")
    if code:
        print("[ERROR] 无法显示本地邮箱 / Could not show local emails.")
    pause()


def inbox_mark(state: str) -> None:
    prompt = (
        "要标记为已使用的邮箱 / Email to mark as used: "
        if state == "used"
        else "要移入垃圾箱的邮箱 / Email to move to trash: "
    )
    email = input(prompt).strip()
    if not email:
        return
    code = run_cli("inbox", "mark", email, state)
    if code:
        print("[ERROR] 无法标记邮箱 / Could not mark email.")
    pause()


def inbox_sync_hme() -> None:
    if not ensure_cookies():
        return
    code = run_cli("inbox", "sync-hme", "--cookie-file", COOKIE_FILE, "--region", REGION)
    if code:
        print("[ERROR] 无法同步 iCloud 隐藏邮箱 / Could not sync iCloud HME addresses.")
    pause()


def inbox_export() -> None:
    code = run_cli("inbox", "export")
    if code:
        print("[ERROR] 导出失败 / Export failed.")
    pause()


def main() -> None:
    configure_console()
    main_menu()


if __name__ == "__main__":
    main()
