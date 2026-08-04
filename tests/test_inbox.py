import sqlite3
import tempfile
import unittest
from pathlib import Path

from hidemyemail_generator.inbox import (
    connect_db,
    count_unread,
    create_batch,
    extract_verification_code,
    get_batch,
    insert_message,
    list_addresses,
    list_batches,
    list_messages,
    mark_messages_read,
    set_address_metadata,
    set_batch_state,
    upsert_address,
)

LEGACY_SCHEMA = """
CREATE TABLE addresses (
  email TEXT PRIMARY KEY, label TEXT, state TEXT NOT NULL DEFAULT 'unused',
  source TEXT NOT NULL DEFAULT 'manual', note TEXT,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL);
CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT, account_key TEXT NOT NULL, folder TEXT NOT NULL,
  uid TEXT NOT NULL, sender TEXT, recipients TEXT, hme_address TEXT, subject TEXT,
  code TEXT, body_preview TEXT, received_at TEXT, created_at TEXT NOT NULL,
  UNIQUE(account_key, folder, uid));
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
"""


class VerificationCodeExtractionTests(unittest.TestCase):
    def test_extracts_chinese_verification_code(self):
        self.assertEqual(
            extract_verification_code(
                "你的 ChatGPT 临时验证码",
                "你的验证码是 937455。请勿告诉他人。",
            ),
            "937455",
        )

    def test_extracts_english_verification_code(self):
        self.assertEqual(
            extract_verification_code(
                "Verify your email",
                "Your verification code is AB12CD.",
            ),
            "AB12CD",
        )

    def test_ignores_year_in_security_notification(self):
        self.assertEqual(
            extract_verification_code(
                "New sign-in to your OpenAI account",
                "A sign-in happened on June 27, 2026.",
            ),
            "",
        )

    def test_ignores_uppercase_words_near_dates(self):
        self.assertEqual(
            extract_verification_code(
                "NGC API paths retiring September 30",
                "NVIDIA account notices can mention 2026 without containing a code.",
            ),
            "",
        )

    def test_ignores_plain_account_numbers(self):
        self.assertEqual(
            extract_verification_code(
                "Security alert for user",
                "Account 1067452334 signed in.",
            ),
            "",
        )


class DatabaseTestCase(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.addCleanup(self._dir.cleanup)
        self.db_file = str(Path(self._dir.name) / "hidemyemail.db")

    def legacy_db(self, rows=()):
        """Creates a database on the pre-migration schema and seeds it."""
        conn = sqlite3.connect(self.db_file)
        conn.executescript(LEGACY_SCHEMA)
        for email, state, note in rows:
            conn.execute(
                "INSERT INTO addresses VALUES (?,?,?,?,?,?,?)",
                (
                    email,
                    "lbl",
                    state,
                    "icloud",
                    note,
                    "2026-07-01T00:00:00+00:00",
                    "2026-07-01T00:00:00+00:00",
                ),
            )
        conn.commit()
        conn.close()

    def require(self, row):
        assert row is not None, "expected a row"
        return row


class MigrationTests(DatabaseTestCase):
    # sync-hme stamped "iCloud active=..." on every synced row, so only the
    # active=False variant identifies a row it forced into trash.
    SEEDED = (
        ("collapsed@icloud.com", "trash", "iCloud active=False"),
        ("usertrashed@icloud.com", "trash", "iCloud active=True"),
        ("plain@icloud.com", "trash", None),
        ("normal@icloud.com", "used", "my own note"),
    )

    def states(self, conn):
        return {
            row["email"]: (row["state"], row["is_active"], row["note"])
            for row in conn.execute(
                "SELECT email, state, is_active, note FROM addresses"
            )
        }

    def test_adds_columns_and_tables_to_a_legacy_database(self):
        self.legacy_db()
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)

        address_columns = {
            r["name"] for r in conn.execute("PRAGMA table_info(addresses)")
        }
        message_columns = {
            r["name"] for r in conn.execute("PRAGMA table_info(messages)")
        }
        tables = {
            r["name"]
            for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
        }

        self.assertLessEqual({"is_active", "batch_id"}, address_columns)
        self.assertIn("is_read", message_columns)
        self.assertIn("batches", tables)

    def test_repairs_only_addresses_sync_forced_into_trash(self):
        self.legacy_db(self.SEEDED)
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        states = self.states(conn)

        self.assertEqual(states["collapsed@icloud.com"], ("unused", 0, None))
        # A user-trashed address that happened to be active keeps its state; a
        # LIKE 'iCloud active=%' predicate would have wrongly resurrected it.
        self.assertEqual(states["usertrashed@icloud.com"][0], "trash")
        self.assertEqual(states["plain@icloud.com"][0], "trash")
        self.assertEqual(states["normal@icloud.com"], ("used", None, "my own note"))

    def test_is_idempotent_and_preserves_rows(self):
        self.legacy_db(self.SEEDED)
        first = connect_db(self.db_file)
        before = self.states(first)
        first.close()

        second = connect_db(self.db_file)
        self.addCleanup(second.close)
        self.assertEqual(self.states(second), before)
        self.assertEqual(len(before), len(self.SEEDED))


class AddressWriteTests(DatabaseTestCase):
    def test_inbox_sync_does_not_overwrite_a_user_note(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        upsert_address(conn, "a@icloud.com", label="Figma", note="my own note")

        insert_message(
            conn,
            {
                "account_key": "acct",
                "folder": "INBOX",
                "uid": "1",
                "sender": "s@example.com",
                "recipients": "a@icloud.com",
                "hme_address": "a@icloud.com",
                "subject": "Verify",
                "code": "123456",
                "body_preview": "Your code is 123456",
                "received_at": "2026-07-02T00:00:00+00:00",
                "created_at": "2026-07-02T00:00:00+00:00",
            },
        )

        row = list_addresses(conn)[0]
        self.assertEqual(row["note"], "my own note")

    def test_metadata_write_can_clear_a_note(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        upsert_address(conn, "a@icloud.com", label="Figma", note="temporary")

        set_address_metadata(conn, "a@icloud.com", note="")

        # upsert_address merges with COALESCE(NULLIF(...)) and cannot write an
        # empty string, which is why edits go through set_address_metadata.
        self.assertEqual(list_addresses(conn)[0]["note"], "")

    def test_sync_can_correct_the_creation_time(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        upsert_address(conn, "a@icloud.com")
        upsert_address(conn, "a@icloud.com", created_at="2026-01-15T09:00:00+00:00")

        self.assertEqual(
            list_addresses(conn)[0]["created_at"], "2026-01-15T09:00:00+00:00"
        )

    def test_filters_by_forwarding_state_and_query(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        upsert_address(conn, "on@icloud.com", label="newsletter", is_active=True)
        upsert_address(conn, "off@icloud.com", label="airline", is_active=False)
        upsert_address(conn, "unknown@icloud.com", label="newsletter")

        active = {r["email"] for r in list_addresses(conn, active=True)}
        inactive = {r["email"] for r in list_addresses(conn, active=False)}
        matched = {r["email"] for r in list_addresses(conn, query="newsl")}

        # NULL is_active means never synced, which reads as forwarding.
        self.assertEqual(active, {"on@icloud.com", "unknown@icloud.com"})
        self.assertEqual(inactive, {"off@icloud.com"})
        self.assertEqual(matched, {"on@icloud.com", "unknown@icloud.com"})


class UnreadTests(DatabaseTestCase):
    def seed_message(self, conn, uid):
        insert_message(
            conn,
            {
                "account_key": "acct",
                "folder": "INBOX",
                "uid": uid,
                "sender": "s@example.com",
                "recipients": "",
                "hme_address": "",
                "subject": f"Message {uid}",
                "code": "",
                "body_preview": "",
                "received_at": "2026-07-02T00:00:00+00:00",
                "created_at": "2026-07-02T00:00:00+00:00",
            },
        )

    def test_messages_start_unread_and_can_be_marked(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        self.seed_message(conn, "1")
        self.seed_message(conn, "2")
        self.assertEqual(count_unread(conn), 2)

        first = list_messages(conn)[0]["id"]
        self.assertEqual(mark_messages_read(conn, [first]), 1)

        self.assertEqual(count_unread(conn), 1)
        self.assertEqual(len(list_messages(conn, only_unread=True)), 1)
        # Marking the same message again is a no-op rather than a double count.
        self.assertEqual(mark_messages_read(conn, [first]), 0)

    def test_insert_returns_the_row_id(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        record = {
            "account_key": "acct",
            "folder": "INBOX",
            "uid": "9",
            "sender": "",
            "recipients": "",
            "hme_address": "",
            "subject": "x",
            "code": "",
            "body_preview": "",
            "received_at": "",
            "created_at": "2026-07-02T00:00:00+00:00",
        }
        insert_message(conn, record)
        self.assertIsNotNone(record["id"])


class BatchTests(DatabaseTestCase):
    def test_tracks_reserved_addresses_and_state(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        batch = create_batch(conn, "shop signups", target=3, interval_seconds=1920)

        upsert_address(conn, "a@icloud.com", batch_id=batch["id"])
        upsert_address(conn, "b@icloud.com", batch_id=batch["id"])
        upsert_address(conn, "unrelated@icloud.com")

        self.assertEqual(self.require(get_batch(conn, batch["id"]))["reserved"], 2)
        self.assertEqual(len(list_addresses(conn, batch_id=batch["id"])), 2)

    def test_state_transitions_stamp_and_clear_the_finish_time(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        batch = create_batch(conn, "trials", target=2)

        paused = self.require(set_batch_state(conn, batch["id"], "paused"))
        finished = self.require(set_batch_state(conn, batch["id"], "finished"))
        resumed = self.require(set_batch_state(conn, batch["id"], "running"))

        self.assertIsNone(paused["finished_at"])
        self.assertIsNotNone(finished["finished_at"])
        # Resuming a finished batch clears the stamp again.
        self.assertIsNone(resumed["finished_at"])

    def test_rejects_unknown_state_and_missing_batch(self):
        conn = connect_db(self.db_file)
        self.addCleanup(conn.close)
        batch = create_batch(conn, "trials", target=1)

        with self.assertRaises(ValueError):
            set_batch_state(conn, batch["id"], "sideways")
        self.assertIsNone(set_batch_state(conn, "nope", "paused"))
        self.assertEqual(len(list_batches(conn)), 1)


if __name__ == "__main__":
    unittest.main()
