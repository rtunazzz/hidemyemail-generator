package com.hidemyemail.generator

import org.junit.Assert.assertEquals
import org.junit.Test

class CookieParserTest {
    @Test
    fun parsesWindowsCurlCookieWithoutTruncatingQuotedValues() {
        val curl = """
            curl.exe "https://www.icloud.com.cn/setup/ws/1/validate" ^
              -b ^"X-APPLE-WEBAUTH-USER={\"dsid\":\"123\"}; session=valid^" ^
              -H ^"Accept: */*^"
        """.trimIndent()

        val parsed = HmeRepository.parseCookieContext(curl, ICloudRegion.Global)

        assertEquals("X-APPLE-WEBAUTH-USER={\"dsid\":\"123\"}; session=valid", parsed.cookie)
    }

    @Test
    fun detectsChinaRegionFromCurlUrl() {
        assertEquals(
            ICloudRegion.China,
            HmeRepository.detectRegion("curl.exe https://www.icloud.com.cn/setup/ws/1/validate"),
        )
    }

    @Test
    fun normalizesStaleChinaShardHostFromCapturedCookieFile() {
        val parsed = HmeRepository.parseCookieContext(
            """
                HIDEMYEMAIL_REGION=global
                HIDEMYEMAIL_REQUEST_URL=https://www.icloud.com.cn/applications/hidemyemail/2626Build17/zh-cn/index.html
                HIDEMYEMAIL_MAILDOMAIN_HOST=p217-maildomainws.icloud.com
                Cookie: X-APPLE-WEBAUTH-USER=valid; session=valid
            """.trimIndent(),
            ICloudRegion.Global,
        )

        assertEquals("X-APPLE-WEBAUTH-USER=valid; session=valid", parsed.cookie)
        assertEquals("p217-maildomainws.icloud.com.cn", parsed.maildomainHost)
    }

    @Test
    fun rejectsJavaScriptBundleAsCookieInput() {
        val parsed = HmeRepository.parseCookieContext(
            "/*! iCloud application bundle */\nfunction app() { return '/v1/hme/generate' }",
            ICloudRegion.China,
        )

        assertEquals("", parsed.cookie)
    }

    @Test
    fun rejectsJavaScriptAssignmentAsCookieInput() {
        val parsed = HmeRepository.parseCookieContext(
            "var session = 'not a Cookie header';",
            ICloudRegion.China,
        )

        assertEquals("", parsed.cookie)
    }
}
