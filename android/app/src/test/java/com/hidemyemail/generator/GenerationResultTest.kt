package com.hidemyemail.generator

import okhttp3.Request
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class GenerationResultTest {
    @Test
    fun retainsEachReservedAddressWhenALaterReservationIsRateLimited() {
        val requests = mutableListOf<Request>()
        val transport = HmeTransport { request ->
            requests += request
            when (requests.size) {
                1 -> HmeHttpResponse(200, """{"success":true,"result":{"hme":"first@icloud.com"}}""")
                2 -> HmeHttpResponse(200, """{"success":true,"result":{}}""")
                3 -> HmeHttpResponse(200, """{"success":true,"result":{"hme":"second@icloud.com"}}""")
                4 -> HmeHttpResponse(
                    429,
                    """{"success":false,"error":{"errorMessage":"Rate limited"}}""",
                    retryAfterSeconds = 1800,
                )
                else -> error("Unexpected request")
            }
        }
        val saved = mutableListOf<HmeAddress>()

        val result = HmeRepository(transport).generate(
            context = CookieContext("session=valid"),
            region = ICloudRegion.Global,
            label = "batch",
            count = 2,
            onReserved = { saved += it },
        )

        assertEquals(listOf("first@icloud.com"), result.addresses.map { it.email })
        assertEquals(listOf("first@icloud.com"), saved.map { it.email })
        assertNotNull(result.failure)
        assertEquals(1800, result.retryAfterSeconds)
        assertTrue(requests[1].url.encodedPath.endsWith(HmeEndpoints.reserve))
    }
}
