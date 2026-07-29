import asyncio
import unittest
from unittest.mock import patch

from hidemyemail_generator.hidemyemail import HideMyEmail


# Mirrors the iCloud web client request the values were captured from. Update
# this together with HideMyEmail when Apple ships a new web client.
CAPTURED_HEADERS = {
    "Connection": "keep-alive",
    "Pragma": "no-cache",
    "Cache-Control": "no-cache",
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36",
    "Content-Type": "text/plain",
    "Accept": "*/*",
    "Sec-GPC": "1",
    "Origin": "https://www.icloud.com",
    "Sec-Fetch-Site": "same-site",
    "Sec-Fetch-Mode": "cors",
    "Sec-Fetch-Dest": "empty",
    "Referer": "https://www.icloud.com/",
    "Accept-Language": "en-US,en;q=0.7",
    "sec-ch-ua": '"Not;A=Brand";v="8", "Chromium";v="150", "Brave";v="150"',
    "sec-ch-ua-mobile": "?0",
    "sec-ch-ua-platform": '"macOS"',
}


class RequestProtocolTests(unittest.TestCase):
    def test_global_headers_match_captured_web_client(self):
        headers = HideMyEmail.browser_headers("global", "cookie=value")
        self.assertEqual({k: v for k, v in headers.items() if k != "Cookie"}, CAPTURED_HEADERS)
        self.assertEqual(headers["Cookie"], "cookie=value")

    def test_client_version_matches_captured_request(self):
        self.assertEqual(HideMyEmail.params["clientBuildNumber"], "2626Build17")
        self.assertEqual(HideMyEmail.params["clientMasteringNumber"], "2626Build17")

    def test_china_region_swaps_origin_and_locale(self):
        headers = HideMyEmail.browser_headers("china")
        self.assertEqual(headers["Origin"], "https://www.icloud.com.cn")
        self.assertEqual(headers["Referer"], "https://www.icloud.com.cn/")
        self.assertEqual(headers["Accept-Language"], "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7")

    def test_cookie_whitespace_is_stripped(self):
        self.assertEqual(HideMyEmail.browser_headers("global", "  a=b\n")["Cookie"], "a=b")

    def test_generate_sends_region_lang_code(self):
        seen = []

        async def fake_request(self, method, url, **kwargs):
            seen.append(kwargs.get("json"))
            return {"success": True, "result": {}}

        for region, expected in [("global", "en-us"), ("china", "zh-cn")]:
            with patch.object(HideMyEmail, "_request_json", fake_request):
                asyncio.run(HideMyEmail(region=region).generate_email())
            self.assertEqual(seen[-1], {"langCode": expected})


if __name__ == "__main__":
    unittest.main()
