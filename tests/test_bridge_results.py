import json
import tempfile
import unittest
from pathlib import Path

from hidemyemail_generator.main import (
    account_summary,
    bridge_error,
    write_result_json,
)


class BridgeResultTests(unittest.TestCase):
    def test_writes_success_result(self):
        payload = {"ok": True, "emails": ["example@icloud.com"], "error": None}
        with tempfile.TemporaryDirectory() as tmpdir:
            result_file = Path(tmpdir) / "result.json"
            write_result_json(str(result_file), payload)
            self.assertEqual(json.loads(result_file.read_text()), payload)

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
                    "fullName": "Example User",
                    "isHideMyEmailFeatureAvailable": True,
                },
            }
        )
        self.assertNotIn("cookie", json.dumps(summary).lower())
        self.assertEqual(summary["user_partition"], 68)
        self.assertEqual(summary["maildomain_host"], "p68-maildomainws.icloud.com")


if __name__ == "__main__":
    unittest.main()
