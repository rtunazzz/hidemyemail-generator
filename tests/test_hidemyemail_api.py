import tempfile
import unittest
from pathlib import Path
from unittest.mock import AsyncMock

from click.testing import CliRunner

from hidemyemail_generator.hidemyemail import HideMyEmail
from hidemyemail_generator.main import RichHideMyEmail, cli


class RecordingHideMyEmail(HideMyEmail):
    """Capture API calls without making a network request."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.calls: list[dict] = []

    async def _request_json(self, method: str, url: str, **kwargs) -> dict:
        self.calls.append({"method": method, "url": url, **kwargs})
        return {"success": True, "result": {}}


class HideMyEmailAddressManagementApiTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.client = RecordingHideMyEmail(region="china")
        self.anonymous_id = "anonymous-id-for-test"

    async def test_updates_label_and_note_using_current_apple_payload(self):
        result = await self.client.update_email_metadata(
            self.anonymous_id, "New label", "New note"
        )

        self.assertTrue(result["success"])
        self.assertEqual(
            self.client.calls,
            [
                {
                    "method": "POST",
                    "url": "https://p217-maildomainws.icloud.com.cn/v1/hme/updateMetaData",
                    "params": self.client.params,
                    "json": {
                        "anonymousId": self.anonymous_id,
                        "label": "New label",
                        "note": "New note",
                    },
                }
            ],
        )

    async def test_deactivates_an_address_by_its_anonymous_id(self):
        await self.client.deactivate_email(self.anonymous_id)

        self.assertEqual(
            self.client.calls[0],
            {
                "method": "POST",
                "url": "https://p217-maildomainws.icloud.com.cn/v1/hme/deactivate",
                "params": self.client.params,
                "json": {"anonymousId": self.anonymous_id},
            },
        )

    async def test_reactivates_an_address_by_its_anonymous_id(self):
        await self.client.reactivate_email(self.anonymous_id)

        self.assertEqual(
            self.client.calls[0],
            {
                "method": "POST",
                "url": "https://p217-maildomainws.icloud.com.cn/v1/hme/reactivate",
                "params": self.client.params,
                "json": {"anonymousId": self.anonymous_id},
            },
        )


class RichHideMyEmailAddressManagementTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.cookie_file = Path(self.tmpdir.name) / "cookies.txt"
        self.cookie_file.write_text("X-APPLE-WEBAUTH-USER=valid", encoding="utf-8")
        self.client = RichHideMyEmail(str(self.cookie_file), no_output_file=True)
        self.row = {
            "anonymousId": "anonymous-id-for-test",
            "hme": "test-address@icloud.com",
            "isActive": True,
            "label": "Old label",
            "note": "Old note",
        }
        self.client.list_email = AsyncMock(
            return_value={"success": True, "result": {"hmeEmails": [self.row]}}
        )

    def tearDown(self):
        self.tmpdir.cleanup()

    async def test_updates_an_address_selected_by_hme_value(self):
        self.client.update_email_metadata = AsyncMock(return_value={"success": True})

        address = await self.client.update_address(
            "TEST-ADDRESS@ICLOUD.COM", "New label", "New note"
        )

        self.assertEqual(address, self.row["hme"])
        self.client.update_email_metadata.assert_awaited_once_with(
            self.row["anonymousId"], "New label", "New note"
        )

    async def test_keeps_an_existing_field_when_no_new_value_is_supplied(self):
        self.client.update_email_metadata = AsyncMock(return_value={"success": True})

        await self.client.update_address(self.row["hme"], None, "New note")

        self.client.update_email_metadata.assert_awaited_once_with(
            self.row["anonymousId"], self.row["label"], "New note"
        )

    async def test_deactivates_an_address_selected_by_hme_value(self):
        self.client.deactivate_email = AsyncMock(return_value={"success": True})

        address = await self.client.deactivate_address(self.row["hme"])

        self.assertEqual(address, self.row["hme"])
        self.client.deactivate_email.assert_awaited_once_with(self.row["anonymousId"])

    async def test_reactivates_an_address_selected_by_anonymous_id(self):
        self.client.reactivate_email = AsyncMock(return_value={"success": True})

        address = await self.client.reactivate_address(self.row["anonymousId"])

        self.assertEqual(address, self.row["hme"])
        self.client.reactivate_email.assert_awaited_once_with(self.row["anonymousId"])


class AddressManagementCliTests(unittest.TestCase):
    def test_exposes_address_management_commands_with_an_address_option(self):
        runner = CliRunner()

        for command in ("update", "deactivate", "reactivate"):
            result = runner.invoke(cli, [command, "--help"])
            self.assertEqual(result.exit_code, 0, result.output)
            self.assertIn("--address", result.output)


if __name__ == "__main__":
    unittest.main()
