import asyncio
import aiohttp
import ssl
import certifi


REQUEST_TIMEOUT_SECONDS = 30
REQUEST_RETRIES = 2


class HideMyEmail:
    REGION_CONFIG = {
        "global": {
            "maildomain_host": "p68-maildomainws.icloud.com",
            "web_origin": "https://www.icloud.com",
            "accept_language": "en-US,en;q=0.7",
            "lang_code": "en-us",
        },
        "china": {
            "maildomain_host": "p217-maildomainws.icloud.com.cn",
            "web_origin": "https://www.icloud.com.cn",
            "accept_language": "zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7",
            "lang_code": "zh-cn",
        },
    }
    params = {
        "clientBuildNumber": "2626Build17",
        "clientMasteringNumber": "2626Build17",
        "clientId": "",
        "dsid": "",  # Directory Services Identifier (DSID) is a method of identifying AppleID accounts
    }
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/150.0.0.0 Safari/537.36"
    SEC_CH_UA = '"Not;A=Brand";v="8", "Chromium";v="150", "Brave";v="150"'

    @classmethod
    def browser_headers(cls, region: str, cookies: str = "") -> dict:
        """Headers mimicking the iCloud web client, shared by every request we send."""
        config = cls.REGION_CONFIG[region]
        return {
            "Connection": "keep-alive",
            "Pragma": "no-cache",
            "Cache-Control": "no-cache",
            "User-Agent": cls.USER_AGENT,
            "Content-Type": "text/plain",
            "Accept": "*/*",
            "Sec-GPC": "1",
            "Origin": config["web_origin"],
            "Sec-Fetch-Site": "same-site",
            "Sec-Fetch-Mode": "cors",
            "Sec-Fetch-Dest": "empty",
            "Referer": f"{config['web_origin']}/",
            "Accept-Language": config["accept_language"],
            "sec-ch-ua": cls.SEC_CH_UA,
            "sec-ch-ua-mobile": "?0",
            "sec-ch-ua-platform": '"macOS"',
            "Cookie": cookies.strip(),
        }

    def __init__(
        self, cookies: str = "", region: str = "global", maildomain_host: str = ""
    ):
        """Initializes the HideMyEmail class.

        Args:
            cookies (str) Cookie string to be used with requests. Required for authorization.
            region (str)  iCloud region to target. Either "global" or "china".
        """
        if region not in self.REGION_CONFIG:
            raise ValueError(f'Unsupported iCloud region "{region}"')

        config = self.REGION_CONFIG[region]
        resolved_maildomain_host = maildomain_host or config["maildomain_host"]
        self.base_url_v1 = f"https://{resolved_maildomain_host}/v1/hme"
        self.base_url_v2 = f"https://{resolved_maildomain_host}/v2/hme"
        self.region = region
        self.web_origin = config["web_origin"]
        self.lang_code = config["lang_code"]
        self.cookies = cookies

    async def __aenter__(self):
        connector = aiohttp.TCPConnector(
            ssl_context=ssl.create_default_context(cafile=certifi.where())
        )
        self.s = aiohttp.ClientSession(
            headers=self.browser_headers(self.region, self.__cookies),
            timeout=aiohttp.ClientTimeout(total=REQUEST_TIMEOUT_SECONDS),
            connector=connector,
        )

        return self

    async def __aexit__(self, exc_t, exc_v, exc_tb):
        await self.s.close()

    @property
    def cookies(self) -> str:
        return self.__cookies

    @cookies.setter
    def cookies(self, cookies: str):
        # remove new lines/whitespace for security reasons
        self.__cookies = cookies.strip()

    async def _request_json(self, method: str, url: str, **kwargs) -> dict:
        for attempt in range(REQUEST_RETRIES):
            try:
                async with self.s.request(method, url, **kwargs) as resp:
                    return await resp.json()
            except asyncio.TimeoutError:
                if attempt == REQUEST_RETRIES - 1:
                    return {
                        "error": 1,
                        "reason": f"Request timed out after {REQUEST_TIMEOUT_SECONDS}s",
                    }
            except Exception as e:
                if attempt == REQUEST_RETRIES - 1:
                    return {"error": 1, "reason": str(e)}

        return {"error": 1, "reason": "Request failed"}

    async def generate_email(self) -> dict:
        """Generates an email"""
        return await self._request_json(
            "POST",
            f"{self.base_url_v1}/generate",
            params=self.params,
            json={"langCode": self.lang_code},
        )

    async def reserve_email(self, email: str, label: str, note: str) -> dict:
        """Reserves an email and registers it for forwarding"""
        payload = {
            "hme": email,
            "label": label,
            "note": note,
        }
        return await self._request_json(
            "POST", f"{self.base_url_v1}/reserve", params=self.params, json=payload
        )

    async def list_email(self) -> dict:
        """List all HME"""
        return await self._request_json(
            "GET", f"{self.base_url_v2}/list", params=self.params
        )

    async def update_email_metadata(
        self, anonymous_id: str, label: str, note: str
    ) -> dict:
        """Updates the label and note of a reserved email"""
        payload = {
            "anonymousId": anonymous_id,
            "label": label,
            "note": note,
        }
        return await self._request_json(
            "POST",
            f"{self.base_url_v1}/updateMetaData",
            params=self.params,
            json=payload,
        )

    async def deactivate_email(self, anonymous_id: str) -> dict:
        """Deactivates an email so it stops forwarding"""
        return await self._request_json(
            "POST",
            f"{self.base_url_v1}/deactivate",
            params=self.params,
            json={"anonymousId": anonymous_id},
        )

    async def reactivate_email(self, anonymous_id: str) -> dict:
        """Reactivates a previously deactivated email"""
        return await self._request_json(
            "POST",
            f"{self.base_url_v1}/reactivate",
            params=self.params,
            json={"anonymousId": anonymous_id},
        )
