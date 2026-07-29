import unittest
from unittest.mock import patch

from hidemyemail_generator import launcher


class LauncherAddressManagementTests(unittest.TestCase):
    @patch("hidemyemail_generator.launcher.clear")
    @patch("hidemyemail_generator.launcher.inbox_menu")
    @patch("hidemyemail_generator.launcher.manage_hme_addresses")
    @patch("builtins.input", side_effect=["5", "7"])
    def test_main_menu_keeps_cookie_at_four_and_opens_address_management_at_five(
        self, _input, manage_addresses, _inbox_menu, _clear
    ):
        launcher.main_menu()

        manage_addresses.assert_called_once_with()

    @patch("hidemyemail_generator.launcher.pause")
    @patch("hidemyemail_generator.launcher.run_cli", return_value=0)
    @patch("hidemyemail_generator.launcher.ensure_cookies", return_value=True)
    @patch("builtins.input", side_effect=["alias@icloud.com", "New label", "-"])
    def test_update_menu_forwards_address_label_and_an_explicitly_cleared_note(
        self, _input, _cookies, run_cli, _pause
    ):
        launcher.update_hme_address()

        self.assertEqual(
            run_cli.call_args.args,
            (
                "update",
                "--address",
                "alias@icloud.com",
                "--label",
                "New label",
                "--note",
                "",
                "--cookie-file",
                launcher.COOKIE_FILE,
                "--region",
                launcher.REGION,
            ),
        )

    @patch("hidemyemail_generator.launcher.pause")
    @patch("hidemyemail_generator.launcher.run_cli", return_value=0)
    @patch("hidemyemail_generator.launcher.ensure_cookies", return_value=True)
    @patch("builtins.input", side_effect=["alias@icloud.com", "YES"])
    def test_deactivate_menu_requires_confirmation_then_calls_cli(
        self, _input, _cookies, run_cli, _pause
    ):
        launcher.deactivate_hme_address()

        self.assertEqual(
            run_cli.call_args.args,
            (
                "deactivate",
                "--address",
                "alias@icloud.com",
                "--cookie-file",
                launcher.COOKIE_FILE,
                "--region",
                launcher.REGION,
            ),
        )

    @patch("hidemyemail_generator.launcher.pause")
    @patch("hidemyemail_generator.launcher.run_cli", return_value=0)
    @patch("hidemyemail_generator.launcher.ensure_cookies", return_value=True)
    @patch("builtins.input", side_effect=["alias@icloud.com"])
    def test_reactivate_menu_calls_cli(self, _input, _cookies, run_cli, _pause):
        launcher.reactivate_hme_address()

        self.assertEqual(
            run_cli.call_args.args,
            (
                "reactivate",
                "--address",
                "alias@icloud.com",
                "--cookie-file",
                launcher.COOKIE_FILE,
                "--region",
                launcher.REGION,
            ),
        )


if __name__ == "__main__":
    unittest.main()
