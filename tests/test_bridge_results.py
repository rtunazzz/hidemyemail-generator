import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from click.testing import CliRunner

import hidemyemail_generator.main as main_module
from hidemyemail_generator.inbox import InboxConfig, connect_db, save_config, upsert_address
from hidemyemail_generator.main import (
    account_summary,
    bridge_error,
    cli,
    write_result_json,
)


class BridgeResultTests(unittest.TestCase):
    def test_writes_success_result(self):
        payload = {"ok": True, "emails": ["example@icloud.com"], "error": None}
        with tempfile.TemporaryDirectory() as tmpdir:
            result_file = Path(tmpdir) / "result.json"
            write_result_json(str(result_file), payload)
            self.assertEqual(json.loads(result_file.read_text()), payload)
            self.assertEqual(os.stat(result_file).st_mode & 0o777, 0o600)

    def test_extracts_rate_limit_error(self):
        error = bridge_error(
            {
                "error": {
                    "errorCode": "-41015",
                    "errorMessage": "You have reached the limit",
                    "retryAfter": 2,
                }
            }
        )
        self.assertEqual(error["code"], "-41015")
        self.assertEqual(error["retry_after"], 2)

    def test_account_result_never_contains_cookie(self):
        summary = account_summary(
            {
                "cookie": "secret",
                "userPartition": "68",
                "webservices": {
                    "maildomainws": {"url": "https://p68-maildomainws.icloud.com/v1"}
                },
                "dsInfo": {
                    "appleId": "user@example.com",
                    "dsid": "123456789",
                    "fullName": "Example User",
                    "isHideMyEmailFeatureAvailable": True,
                },
            }
        )
        self.assertNotIn("cookie", json.dumps(summary).lower())
        self.assertEqual(summary["user_partition"], 68)
        self.assertEqual(summary["maildomain_host"], "p68-maildomainws.icloud.com")
        self.assertEqual(summary["dsid"], "123456789")

    def test_cloud_list_bridge_is_hidden_and_structured(self):
        async def fake_list(*_args):
            return {
                "ok": True,
                "addresses": [
                    {
                        "email": "example@icloud.com",
                        "label": "Example",
                        "created_at": "2026-07-26T12:00:00+00:00",
                        "is_active": True,
                    }
                ],
                "error": None,
            }

        runner = CliRunner()
        self.assertNotIn("--result-json", runner.invoke(cli, ["list", "--help"]).output)
        with tempfile.TemporaryDirectory() as tmpdir:
            result_file = Path(tmpdir) / "result.json"
            with patch.object(main_module, "_list", fake_list):
                result = runner.invoke(
                    cli,
                    ["list", "--result-json", str(result_file)],
                )
            self.assertEqual(result.exit_code, 0, result.output)
            payload = json.loads(result_file.read_text())
            self.assertEqual(payload["addresses"][0]["email"], "example@icloud.com")

    def test_inbox_read_and_mutation_bridges_never_return_password(self):
        runner = CliRunner()
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            config_file = root / "inbox_config.json"
            db_file = root / "hidemyemail.db"
            save_config(
                InboxConfig(
                    host="imap.example.com",
                    port=993,
                    username="user@example.com",
                    password="super-secret",
                ),
                str(config_file),
            )
            conn = connect_db(str(db_file))
            upsert_address(conn, "example@icloud.com", label="Example")
            conn.close()

            status_file = root / "status.json"
            status = runner.invoke(
                cli,
                [
                    "inbox",
                    "status",
                    "--config-file",
                    str(config_file),
                    "--db-file",
                    str(db_file),
                    "--result-json",
                    str(status_file),
                ],
            )
            self.assertEqual(status.exit_code, 0, status.output)
            payload = json.loads(status_file.read_text())
            self.assertEqual(payload["counts"]["states"]["unused"], 1)
            self.assertNotIn("super-secret", status_file.read_text())

            mark_file = root / "mark.json"
            mark = runner.invoke(
                cli,
                [
                    "inbox",
                    "mark",
                    "example@icloud.com",
                    "used",
                    "--db-file",
                    str(db_file),
                    "--result-json",
                    str(mark_file),
                ],
            )
            self.assertEqual(mark.exit_code, 0, mark.output)
            self.assertEqual(json.loads(mark_file.read_text())["state"], "used")

            addresses_file = root / "addresses.json"
            addresses = runner.invoke(
                cli,
                [
                    "inbox",
                    "addresses",
                    "--db-file",
                    str(db_file),
                    "--result-json",
                    str(addresses_file),
                ],
            )
            self.assertEqual(addresses.exit_code, 0, addresses.output)
            self.assertEqual(
                json.loads(addresses_file.read_text())["addresses"][0]["state"],
                "used",
            )

            export_file = root / "export.json"
            exported = runner.invoke(
                cli,
                [
                    "inbox",
                    "export",
                    "--db-file",
                    str(db_file),
                    "--export-dir",
                    str(root / "exports"),
                    "--result-json",
                    str(export_file),
                ],
            )
            self.assertEqual(exported.exit_code, 0, exported.output)
            outputs = json.loads(export_file.read_text())["outputs"]
            self.assertTrue(Path(outputs["addresses"]).exists())
            self.assertTrue(Path(outputs["messages"]).exists())


if __name__ == "__main__":
    unittest.main()
