import tempfile
import unittest
from pathlib import Path

import hidemyemail_generator.main as generator_main
from hidemyemail_generator.hidemyemail import HideMyEmail
from hidemyemail_generator.main import (
    HIDEMYEMAIL_APP_PATH,
    RichHideMyEmail,
    load_cookie_context,
)


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
        legacy_app_url = (
            "https://www.icloud.com.cn/applications/hidemyemail/"
            "current/zh-cn/index.html?rootDomain=www"
        )
        asset_url = (
            "https://www.icloud.com.cn/applications/hidemyemail/"
            "2626Build17/zh-cn/main.js"
        )

        self.assertIn(HIDEMYEMAIL_APP_PATH, current_app_url)
        self.assertTrue(
            hasattr(generator_main, "is_hidemyemail_app_request"),
            "Expected a helper that recognizes the current iCloud app request",
        )
        matcher = generator_main.is_hidemyemail_app_request
        self.assertTrue(matcher(current_app_url))
        self.assertTrue(matcher(legacy_app_url))
        self.assertFalse(matcher(asset_url))

    def test_builds_cookie_header_from_browser_cookie_records(self):
        self.assertTrue(
            hasattr(generator_main, "browser_cookie_header"),
            "Expected a helper that normalizes browser cookie records",
        )
        header = generator_main.browser_cookie_header(
            [
                {"name": "X-APPLE-WEBAUTH-USER", "value": "valid"},
                {"name": "session", "value": "valid"},
                {"name": "session", "value": "duplicate"},
                {"name": "", "value": "ignored"},
            ]
        )

        self.assertEqual(
            header,
            "X-APPLE-WEBAUTH-USER=valid; session=valid",
        )

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

    def test_recovers_china_region_and_shard_from_a_redirected_capture(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text(
                "HIDEMYEMAIL_REGION=global\n"
                "HIDEMYEMAIL_REQUEST_URL=https://www.icloud.com.cn/"
                "applications/hidemyemail/2626Build17/zh-cn/index.html?rootDomain=www\n"
                "HIDEMYEMAIL_MAILDOMAIN_HOST=p217-maildomainws.icloud.com\n"
                "Cookie: X-APPLE-WEBAUTH-USER=valid; session=valid\n",
                encoding="utf-8",
            )

            self.assertTrue(
                hasattr(generator_main, "resolve_cookie_region"),
                "Expected the iCloud region to be resolved from the capture URL",
            )
            region = generator_main.resolve_cookie_region(str(cookie_file), "global")
            cookie, maildomain_host = load_cookie_context(str(cookie_file), region)

            self.assertEqual(region, "china")
            self.assertEqual(cookie, "X-APPLE-WEBAUTH-USER=valid; session=valid")
            self.assertEqual(maildomain_host, "p217-maildomainws.icloud.com.cn")

    def test_client_uses_detected_china_region_from_cookie_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text(
                "HIDEMYEMAIL_REGION=global\n"
                "HIDEMYEMAIL_REQUEST_URL=https://www.icloud.com.cn/"
                "applications/hidemyemail/2626Build17/zh-cn/index.html?rootDomain=www\n"
                "HIDEMYEMAIL_MAILDOMAIN_HOST=p217-maildomainws.icloud.com\n"
                "Cookie: X-APPLE-WEBAUTH-USER=valid; session=valid\n",
                encoding="utf-8",
            )

            client = RichHideMyEmail(str(cookie_file), region="global")

            self.assertEqual(
                client.base_url_v1,
                "https://p217-maildomainws.icloud.com.cn/v1/hme",
            )
            self.assertEqual(client.generate_lang_code, "zh-cn")


if __name__ == "__main__":
    unittest.main()
