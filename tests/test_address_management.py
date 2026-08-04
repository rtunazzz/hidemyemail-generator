import asyncio
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from hidemyemail_generator.inbox import connect_db, list_addresses, upsert_address
from hidemyemail_generator.main import RichHideMyEmail, _write_through


LIST_RESPONSE = {
    "success": True,
    "result": {
        "hmeEmails": [
            {
                "anonymousId": "abc-123",
                "hme": "example@icloud.com",
                "label": "Example",
                "note": "Original note",
                "isActive": True,
                "createTimestamp": 1753531200000,
            }
        ]
    },
}


class FakeTransport:
    """Records every request the client makes and replays canned responses."""

    def __init__(self, responses=None):
        self.calls = []
        self.responses = responses or {}

    async def __call__(self, method, url, **kwargs):
        self.calls.append((method, url, kwargs.get("json")))
        endpoint = url.rsplit("/", 1)[-1]
        return self.responses.get(endpoint, {"success": True, "result": {}})


def run(coro):
    return asyncio.run(coro)


class AddressManagementTests(unittest.TestCase):
    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        cookie_file = Path(tmpdir.name) / "cookies.txt"
        cookie_file.write_text('X-APPLE-WEBAUTH-USER="v=1:s=0:d=1"', encoding="utf-8")

        self.transport = FakeTransport({"list": LIST_RESPONSE})
        patcher = patch.object(RichHideMyEmail, "_request_json", self.transport)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.hme = RichHideMyEmail(cookie_file=str(cookie_file))

    def test_list_exposes_anonymous_id(self):
        result = run(self.hme.list(None, True))
        self.assertEqual(result["addresses"][0]["anonymous_id"], "abc-123")

    def test_deactivate_posts_anonymous_id(self):
        result = run(self.hme.set_active("example@icloud.com", False))
        self.assertTrue(result["ok"])
        self.assertFalse(result["is_active"])
        method, url, payload = self.transport.calls[-1]
        self.assertEqual(method, "POST")
        self.assertTrue(url.endswith("/v1/hme/deactivate"))
        self.assertEqual(payload, {"anonymousId": "abc-123"})

    def test_reactivate_posts_anonymous_id(self):
        result = run(self.hme.set_active("example@icloud.com", True))
        self.assertTrue(result["ok"])
        _, url, payload = self.transport.calls[-1]
        self.assertTrue(url.endswith("/v1/hme/reactivate"))
        self.assertEqual(payload, {"anonymousId": "abc-123"})

    def test_update_metadata_keeps_unspecified_fields(self):
        result = run(self.hme.update_metadata("example@icloud.com", "Renamed", None))
        self.assertTrue(result["ok"])
        _, url, payload = self.transport.calls[-1]
        self.assertTrue(url.endswith("/v1/hme/updateMetaData"))
        self.assertEqual(
            payload,
            {"anonymousId": "abc-123", "label": "Renamed", "note": "Original note"},
        )

    def test_unknown_address_fails_without_mutating(self):
        result = run(self.hme.set_active("nope@icloud.com", False))
        self.assertFalse(result["ok"])
        self.assertIn("nope@icloud.com", result["error"]["message"])
        self.assertEqual(len(self.transport.calls), 1)

    def test_missing_anonymous_id_fails_without_mutating(self):
        self.transport.responses["list"] = {
            "success": True,
            "result": {
                "hmeEmails": [
                    {"hme": "example@icloud.com", "label": "", "isActive": True}
                ]
            },
        }
        result = run(self.hme.set_active("example@icloud.com", False))
        self.assertFalse(result["ok"])
        self.assertIn("no identifier", result["error"]["message"])
        self.assertEqual(len(self.transport.calls), 1)

    def test_failed_list_surfaces_error(self):
        self.transport.responses["list"] = {
            "success": False,
            "error": {"errorCode": "-41015", "errorMessage": "Too many requests"},
        }
        result = run(self.hme.update_metadata("example@icloud.com", "x", None))
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"]["code"], "-41015")


class WriteThroughTests(unittest.TestCase):
    """An accepted iCloud edit has to land locally, or the list keeps serving
    the pre-edit values until the next full sync."""

    def setUp(self):
        tmpdir = tempfile.TemporaryDirectory()
        self.addCleanup(tmpdir.cleanup)
        self.db_file = str(Path(tmpdir.name) / "hidemyemail.db")
        conn = connect_db(self.db_file)
        upsert_address(conn, "example@icloud.com", label="Old", note="Old note")
        conn.close()

    def stored(self):
        conn = connect_db(self.db_file)
        try:
            return list_addresses(conn)[0]
        finally:
            conn.close()

    def test_metadata_edit_lands_locally(self):
        _write_through(
            self.db_file,
            {
                "ok": True,
                "email": "example@icloud.com",
                "label": "Renamed",
                "note": "New note",
            },
        )
        row = self.stored()
        self.assertEqual(row["label"], "Renamed")
        self.assertEqual(row["note"], "New note")

    def test_cleared_note_is_not_reverted(self):
        _write_through(
            self.db_file,
            {"ok": True, "email": "example@icloud.com", "label": "Old", "note": ""},
        )
        self.assertEqual(self.stored()["note"], "")

    def test_forwarding_change_lands_locally(self):
        _write_through(
            self.db_file,
            {"ok": True, "email": "example@icloud.com", "is_active": False},
        )
        row = self.stored()
        self.assertEqual(row["is_active"], 0)
        # A deactivate result carries no label or note; they must survive it.
        self.assertEqual(row["label"], "Old")
        self.assertEqual(row["note"], "Old note")


if __name__ == "__main__":
    unittest.main()
