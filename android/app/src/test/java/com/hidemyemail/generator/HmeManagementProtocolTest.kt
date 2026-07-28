package com.hidemyemail.generator

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HmeManagementProtocolTest {
    @Test
    fun parsesAnonymousIdAndNoteFromTheCurrentHmeListResponse() {
        val addresses = HmeRepository.parseHmeAddresses(
            JSONObject(
                """
                {
                  "result": {
                    "hmeEmails": [
                      {
                        "anonymousId": "anonymous-id",
                        "hme": "example@icloud.com",
                        "label": "Example",
                        "note": "Example note",
                        "isActive": true,
                        "createTimestamp": 123456789
                      }
                    ]
                  }
                }
                """.trimIndent(),
            ),
        )

        assertEquals(1, addresses.size)
        assertEquals("anonymous-id", addresses.single().anonymousId)
        assertEquals("Example note", addresses.single().note)
    }

    @Test
    fun exposesCurrentAppleManagementEndpointsAndPayloads() {
        assertEquals("2626Build17", HmeRequestDefaults.clientBuildNumber)
        assertEquals("2626Build17", HmeRequestDefaults.clientMasteringNumber)
        assertEquals("/v1/hme/updateMetaData", HmeEndpoints.updateMetadata)
        assertEquals("/v1/hme/deactivate", HmeEndpoints.deactivate)
        assertEquals("/v1/hme/reactivate", HmeEndpoints.reactivate)

        val update = HmeRepository.updateMetadataPayload("anonymous-id", "New label", "New note")
        val stateChange = HmeRepository.anonymousIdPayload("anonymous-id")

        assertEquals("anonymous-id", update.getString("anonymousId"))
        assertEquals("New label", update.getString("label"))
        assertEquals("New note", update.getString("note"))
        assertEquals("anonymous-id", stateChange.getString("anonymousId"))
        assertFalse(update.has("hme"))
        assertTrue(stateChange.length() == 1)
    }
}
