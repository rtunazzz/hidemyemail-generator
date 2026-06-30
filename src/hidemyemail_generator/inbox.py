import csv
import html
import imaplib
import json
import re
import sqlite3
from dataclasses import dataclass
from datetime import datetime, timezone
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from email.utils import getaddresses, parsedate_to_datetime
from pathlib import Path
from typing import Iterable, Optional


DEFAULT_DB_FILE = "hidemyemail.db"
DEFAULT_INBOX_CONFIG_FILE = "inbox_config.json"
DEFAULT_EXPORT_DIR = "exports"
DEFAULT_FOLDER = "INBOX"

ADDRESS_STATES = ("unused", "used", "trash")
CODE_KEYWORDS = re.compile(
    r"验证码|校验码|动态码|安全码|认证码|确认码|临时码|一次性|验证|verification|verify|code|otp|passcode|security code|confirmation",
    re.IGNORECASE,
)
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
DIGIT_CODE_RE = re.compile(r"(?<!\d)\d{4,8}(?!\d)")
ALNUM_CODE_RE = re.compile(
    r"\b(?=[A-Z0-9]{6,10}\b)(?=[A-Z0-9]*[A-Z])(?=[A-Z0-9]*\d)[A-Z0-9]{6,10}\b"
)
TAG_RE = re.compile(r"<[^>]+>")


@dataclass
class InboxConfig:
    host: str
    port: int
    username: str
    password: str
    folder: str = DEFAULT_FOLDER
    use_ssl: bool = True

    @property
    def account_key(self) -> str:
        return f"{self.username}@{self.host}/{self.folder}"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def connect_db(db_file: str = DEFAULT_DB_FILE) -> sqlite3.Connection:
    conn = sqlite3.connect(db_file)
    conn.row_factory = sqlite3.Row
    init_db(conn)
    return conn


def init_db(conn: sqlite3.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS addresses (
            email TEXT PRIMARY KEY,
            label TEXT,
            state TEXT NOT NULL DEFAULT 'unused',
            source TEXT NOT NULL DEFAULT 'manual',
            note TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_key TEXT NOT NULL,
            folder TEXT NOT NULL,
            uid TEXT NOT NULL,
            sender TEXT,
            recipients TEXT,
            hme_address TEXT,
            subject TEXT,
            code TEXT,
            body_preview TEXT,
            received_at TEXT,
            created_at TEXT NOT NULL,
            UNIQUE(account_key, folder, uid)
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """
    )
    conn.commit()


def load_config(config_file: str = DEFAULT_INBOX_CONFIG_FILE) -> InboxConfig:
    path = Path(config_file)
    if not path.exists():
        raise FileNotFoundError(f'No "{config_file}" found. Run inbox setup first.')
    data = json.loads(path.read_text(encoding="utf-8"))
    return InboxConfig(
        host=data["host"],
        port=int(data.get("port", 993)),
        username=data["username"],
        password=data["password"],
        folder=data.get("folder") or DEFAULT_FOLDER,
        use_ssl=bool(data.get("use_ssl", True)),
    )


def save_config(config: InboxConfig, config_file: str = DEFAULT_INBOX_CONFIG_FILE) -> None:
    data = {
        "host": config.host,
        "port": config.port,
        "username": config.username,
        "password": config.password,
        "folder": config.folder,
        "use_ssl": config.use_ssl,
    }
    Path(config_file).write_text(
        json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8"
    )


def mask_account(value: str) -> str:
    if "@" not in value:
        return value[:2] + "***" if len(value) > 2 else "***"
    local, domain = value.split("@", 1)
    if len(local) <= 2:
        masked = local[:1] + "***"
    else:
        masked = local[:2] + "***" + local[-1:]
    return f"{masked}@{domain}"


def upsert_address(
    conn: sqlite3.Connection,
    email: str,
    label: str = "",
    state: str = "unused",
    source: str = "manual",
    note: str = "",
) -> None:
    if state not in ADDRESS_STATES:
        raise ValueError(f"Unsupported address state: {state}")
    now = utc_now()
    conn.execute(
        """
        INSERT INTO addresses(email, label, state, source, note, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(email) DO UPDATE SET
            label = COALESCE(NULLIF(excluded.label, ''), addresses.label),
            state = CASE
                WHEN addresses.state = 'unused' THEN excluded.state
                ELSE addresses.state
            END,
            source = excluded.source,
            note = COALESCE(NULLIF(excluded.note, ''), addresses.note),
            updated_at = excluded.updated_at
        """,
        (email, label, state, source, note, now, now),
    )
    conn.commit()


def mark_address(conn: sqlite3.Connection, email: str, state: str) -> None:
    if state not in ADDRESS_STATES:
        raise ValueError(f"Unsupported address state: {state}")
    now = utc_now()
    conn.execute(
        """
        INSERT INTO addresses(email, state, source, created_at, updated_at)
        VALUES (?, ?, 'manual', ?, ?)
        ON CONFLICT(email) DO UPDATE SET state = excluded.state, updated_at = excluded.updated_at
        """,
        (email, state, now, now),
    )
    conn.commit()


def list_addresses(
    conn: sqlite3.Connection, state: Optional[str] = None, limit: int = 50
) -> list[sqlite3.Row]:
    if state:
        return conn.execute(
            """
            SELECT email, label, state, source, updated_at
            FROM addresses
            WHERE state = ?
            ORDER BY updated_at DESC
            LIMIT ?
            """,
            (state, limit),
        ).fetchall()
    return conn.execute(
        """
        SELECT email, label, state, source, updated_at
        FROM addresses
        ORDER BY updated_at DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()


def strip_html(value: str) -> str:
    value = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", value)
    value = TAG_RE.sub(" ", value)
    return html.unescape(value)


def get_message_body(message: EmailMessage) -> str:
    plain_parts: list[str] = []
    html_parts: list[str] = []
    if message.is_multipart():
        for part in message.walk():
            if part.get_content_disposition() == "attachment":
                continue
            content_type = part.get_content_type()
            try:
                content = part.get_content()
            except Exception:
                continue
            if not isinstance(content, str):
                continue
            if content_type == "text/plain":
                plain_parts.append(content)
            elif content_type == "text/html":
                html_parts.append(strip_html(content))
    else:
        try:
            content = message.get_content()
        except Exception:
            content = ""
        if isinstance(content, str):
            if message.get_content_type() == "text/html":
                html_parts.append(strip_html(content))
            else:
                plain_parts.append(content)
    body = "\n".join(part.strip() for part in plain_parts if part.strip())
    if body:
        return body
    return "\n".join(part.strip() for part in html_parts if part.strip())


def normalize_space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def extract_verification_code(subject: str, body: str) -> str:
    text = normalize_space(f"{subject}\n{body}")
    if not text:
        return ""

    candidates: list[tuple[int, str]] = []
    for regex, base_score in ((DIGIT_CODE_RE, 50), (ALNUM_CODE_RE, 20)):
        for match in regex.finditer(text):
            code = match.group(0)
            start, end = match.span()
            window = text[max(0, start - 80) : min(len(text), end + 80)]
            if not CODE_KEYWORDS.search(window):
                continue
            if re.fullmatch(r"(?:19|20)\d{2}", code):
                continue
            score = base_score
            score += 100
            if len(code) == 6:
                score += 20
            if len(code) in (4, 5, 7, 8):
                score += 5
            candidates.append((score, code))

    if not candidates:
        return ""
    candidates.sort(key=lambda item: item[0], reverse=True)
    return candidates[0][1]


def parse_received_at(message: EmailMessage) -> str:
    date_header = message.get("Date")
    if not date_header:
        return ""
    try:
        parsed = parsedate_to_datetime(date_header)
    except Exception:
        return date_header
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).isoformat()


def header_addresses(message: EmailMessage, names: Iterable[str]) -> list[str]:
    raw_values: list[str] = []
    for name in names:
        raw_values.extend(message.get_all(name, []))
    parsed = getaddresses(raw_values)
    return [addr.lower() for _, addr in parsed if addr]


def find_hme_address(
    conn: sqlite3.Connection, message: EmailMessage, body: str
) -> tuple[str, str]:
    recipient_headers = [
        "To",
        "Delivered-To",
        "X-Original-To",
        "Envelope-To",
        "Apparently-To",
        "Original-Recipient",
        "Resent-To",
        "Cc",
    ]
    recipients = header_addresses(message, recipient_headers)
    haystack = "\n".join(
        [message.get(name, "") for name in recipient_headers] + [body]
    ).lower()

    known = conn.execute("SELECT email FROM addresses").fetchall()
    for row in known:
        email = row["email"].lower()
        if email in haystack:
            return email, ", ".join(recipients)

    for email in recipients:
        if email.endswith("@icloud.com"):
            return email, ", ".join(recipients)
    return (recipients[0] if recipients else "", ", ".join(recipients))


def message_to_record(
    conn: sqlite3.Connection,
    config: InboxConfig,
    uid: str,
    raw_message: bytes,
) -> dict:
    message = BytesParser(policy=policy.default).parsebytes(raw_message)
    subject = str(message.get("Subject", ""))
    sender = ", ".join(header_addresses(message, ["From"]))
    body = get_message_body(message)
    hme_address, recipients = find_hme_address(conn, message, body)
    code = extract_verification_code(subject, body)
    preview = normalize_space(body)[:500]
    received_at = parse_received_at(message)

    return {
        "account_key": config.account_key,
        "folder": config.folder,
        "uid": uid,
        "sender": sender,
        "recipients": recipients,
        "hme_address": hme_address,
        "subject": subject,
        "code": code,
        "body_preview": preview,
        "received_at": received_at,
        "created_at": utc_now(),
    }


def insert_message(conn: sqlite3.Connection, record: dict) -> bool:
    try:
        conn.execute(
            """
            INSERT INTO messages(
                account_key, folder, uid, sender, recipients, hme_address,
                subject, code, body_preview, received_at, created_at
            )
            VALUES (
                :account_key, :folder, :uid, :sender, :recipients, :hme_address,
                :subject, :code, :body_preview, :received_at, :created_at
            )
            """,
            record,
        )
    except sqlite3.IntegrityError:
        return False

    if record.get("hme_address"):
        upsert_address(
            conn,
            record["hme_address"],
            state="unused",
            source="inbox",
            note="Seen in inbox",
        )
    conn.commit()
    return True


def sync_inbox(
    config: InboxConfig, db_file: str = DEFAULT_DB_FILE, limit: int = 50
) -> list[dict]:
    conn = connect_db(db_file)
    mailbox = (
        imaplib.IMAP4_SSL(config.host, config.port)
        if config.use_ssl
        else imaplib.IMAP4(config.host, config.port)
    )
    try:
        mailbox.login(config.username, config.password)
        status, _ = mailbox.select(config.folder)
        if status != "OK":
            raise RuntimeError(f"Could not select IMAP folder: {config.folder}")

        status, data = mailbox.uid("search", None, "ALL")
        if status != "OK":
            raise RuntimeError("IMAP search failed")

        uids = data[0].split()
        if limit > 0:
            uids = uids[-limit:]

        inserted: list[dict] = []
        for raw_uid in uids:
            uid = raw_uid.decode("ascii", errors="ignore")
            exists = conn.execute(
                """
                SELECT 1 FROM messages
                WHERE account_key = ? AND folder = ? AND uid = ?
                """,
                (config.account_key, config.folder, uid),
            ).fetchone()
            if exists:
                continue

            status, msg_data = mailbox.uid("fetch", raw_uid, "(RFC822)")
            if status != "OK" or not msg_data:
                continue

            raw_message = b""
            for part in msg_data:
                if isinstance(part, tuple):
                    raw_message += part[1]
            if not raw_message:
                continue

            record = message_to_record(conn, config, uid, raw_message)
            if insert_message(conn, record):
                inserted.append(record)
        return inserted
    finally:
        try:
            mailbox.logout()
        except Exception:
            pass
        conn.close()


def list_messages(
    conn: sqlite3.Connection, only_codes: bool = False, limit: int = 50
) -> list[sqlite3.Row]:
    where = "WHERE code IS NOT NULL AND code != ''" if only_codes else ""
    return conn.execute(
        f"""
        SELECT received_at, hme_address, sender, subject, code, body_preview
        FROM messages
        {where}
        ORDER BY COALESCE(received_at, created_at) DESC
        LIMIT ?
        """,
        (limit,),
    ).fetchall()


def export_csv_files(
    db_file: str = DEFAULT_DB_FILE, export_dir: str = DEFAULT_EXPORT_DIR
) -> dict[str, Path]:
    conn = connect_db(db_file)
    out_dir = Path(export_dir)
    out_dir.mkdir(exist_ok=True)

    outputs = {
        "addresses": out_dir / "addresses.csv",
        "messages": out_dir / "messages.csv",
    }
    queries = {
        "addresses": "SELECT email, label, state, source, note, created_at, updated_at FROM addresses ORDER BY updated_at DESC",
        "messages": "SELECT received_at, hme_address, sender, subject, code, body_preview FROM messages ORDER BY COALESCE(received_at, created_at) DESC",
    }
    try:
        for key, query in queries.items():
            rows = conn.execute(query).fetchall()
            with outputs[key].open("w", newline="", encoding="utf-8-sig") as f:
                writer = csv.writer(f)
                if rows:
                    writer.writerow(rows[0].keys())
                    for row in rows:
                        writer.writerow([row[column] for column in row.keys()])
                else:
                    writer.writerow([])
        return outputs
    finally:
        conn.close()
