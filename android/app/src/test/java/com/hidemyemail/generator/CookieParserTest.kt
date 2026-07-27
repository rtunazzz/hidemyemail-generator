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
}
