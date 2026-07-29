package com.hidemyemail.generator

import org.junit.Assert.assertEquals
import org.junit.Test

class RegionProtocolTest {
    @Test
    fun usesWebLocaleForHideMyEmailGeneration() {
        assertEquals("en-us", ICloudRegion.Global.generateLangCode)
        assertEquals("zh-cn", ICloudRegion.China.generateLangCode)
    }

    @Test
    fun usesRegionAppropriateAcceptLanguage() {
        assertEquals("en-US,en;q=0.7", HmeRepository.acceptLanguage(ICloudRegion.Global))
        assertEquals("zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7", HmeRepository.acceptLanguage(ICloudRegion.China))
    }

    @Test
    fun chinaDomainWinsOverAStaleDeclaredGlobalRegion() {
        assertEquals(
            ICloudRegion.China,
            HmeRepository.detectRegion(
                "HIDEMYEMAIL_REGION=global\n" +
                    "HIDEMYEMAIL_REQUEST_URL=https://www.icloud.com.cn/applications/hidemyemail/2626Build17/zh-cn/index.html",
            ),
        )
    }
}
