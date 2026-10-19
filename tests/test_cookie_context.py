import json
import tempfile
import unittest
from pathlib import Path

import click

from hidemyemail_generator.main import load_cookie_context


class CookieContextTests(unittest.TestCase):
    def test_empty_cookie_file_returns_empty_cookie(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text("", encoding="utf-8")

            cookie, maildomain_host = load_cookie_context(str(cookie_file), "global")

            self.assertEqual(cookie, "")
            self.assertEqual(maildomain_host, "")

    def test_copy_as_curl_formats_round_trip_cookie(self):
        cookie = 'X-APPLE-WEBAUTH-USER="v=1:s=0:d=111111111"; x-apple-group=false'
        escaped = cookie.replace('"', '\\"')
        url = "https://p68-maildomainws.icloud.com/v2/hme/list"
        inputs = {
            "raw header": cookie,
            "single quotes": f"curl '{url}' \\\n  -b '{cookie}'\n",
            "double quotes": f'curl "{url}" \\\n  -b "{escaped}"\n',
            "cookie header": f'curl "{url}" \\\n  -H "cookie: {escaped}"\n',
            "json export": json.dumps(
                [
                    {"name": "X-APPLE-WEBAUTH-USER", "value": '"v=1:s=0:d=111111111"'},
                    {"name": "x-apple-group", "value": "false"},
                ]
            ),
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            for name, text in inputs.items():
                with self.subTest(name):
                    cookie_file.write_text(text, encoding="utf-8")

                    parsed, _ = load_cookie_context(str(cookie_file), "global")

                    self.assertEqual(parsed, cookie)

    def test_unparseable_cookie_file_raises(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            cookie_file = Path(tmpdir) / "cookies.txt"
            cookie_file.write_text(
                "curl 'https://www.icloud.com/' -H 'accept: */*'\n", encoding="utf-8"
            )

            with self.assertRaises(click.ClickException):
                load_cookie_context(str(cookie_file), "global")


if __name__ == "__main__":
    unittest.main()
