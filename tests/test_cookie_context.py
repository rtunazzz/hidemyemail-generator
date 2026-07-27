import tempfile
import unittest
from pathlib import Path

from hidemyemail_generator.hidemyemail import HideMyEmail
from hidemyemail_generator.main import HIDEMYEMAIL_APP_PATH, load_cookie_context


class CookieContextTests(unittest.TestCase):
    def test_empty_cookie_file_returns_empty_cookie(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text("", encoding="utf-8")

            cookie, maildomain_host = load_cookie_context(str(cookie_file), "global")

            self.assertEqual(cookie, "")
            self.assertEqual(maildomain_host, "")

    def test_reads_utf8_copy_as_curl_input_on_windows(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text(
                "curl.exe 'https://p217-maildomainws.icloud.com.cn/v2/hme/list' "
                "-H 'Cookie: X-APPLE-WEBAUTH-USER=valid; session=valid'\n"
                "# copied from iCloud €\n",
                encoding="utf-8",
            )

            cookie, maildomain_host = load_cookie_context(str(cookie_file), "china")

            self.assertEqual(
                cookie, "X-APPLE-WEBAUTH-USER=valid; session=valid"
            )
            self.assertEqual(maildomain_host, "p217-maildomainws.icloud.com.cn")

    def test_capture_path_matches_current_versioned_hide_my_email_bundle(self):
        current_app_url = (
            "https://www.icloud.com.cn/applications/hidemyemail/"
            "2626Build17/zh-cn/index.html?rootDomain=www"
        )

        self.assertIn(HIDEMYEMAIL_APP_PATH, current_app_url)

    def test_uses_region_specific_generation_locale(self):
        self.assertEqual(
            HideMyEmail.REGION_CONFIG["global"].get("generate_lang_code"),
            "en-us",
        )
        self.assertEqual(
            HideMyEmail.REGION_CONFIG["china"].get("generate_lang_code"),
            "zh-cn",
        )

    def test_rejects_a_javascript_bundle_as_cookie_input(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text(
                "/*! iCloud application bundle */\n"
                "function app(){ return '/v1/hme/generate'; }\n",
                encoding="utf-8",
            )

            cookie, maildomain_host = load_cookie_context(str(cookie_file), "china")

            self.assertEqual(cookie, "")
            self.assertEqual(maildomain_host, "")

    def test_rejects_a_javascript_assignment_as_cookie_input(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text(
                "var session = 'not a Cookie header';\n",
                encoding="utf-8",
            )

            cookie, maildomain_host = load_cookie_context(str(cookie_file), "china")

            self.assertEqual(cookie, "")
            self.assertEqual(maildomain_host, "")


if __name__ == "__main__":
    unittest.main()
