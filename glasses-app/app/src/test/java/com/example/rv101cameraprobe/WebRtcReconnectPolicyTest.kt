package com.example.rv101cameraprobe

import org.junit.Assert.assertEquals
import org.junit.Test

class WebRtcReconnectPolicyTest {
    @Test
    fun `transport retry keeps the pending local offer and peer alive`() {
        assertEquals(
            WebRtcReconnectAction.REUSE_PENDING_OFFER,
            WebRtcReconnectPolicy.actionFor(
                hasPendingOffer = true,
                remoteDescriptionApplied = false,
            ),
        )
    }

    @Test
    fun `negotiated or incomplete peers are rebuilt before reconnecting`() {
        assertEquals(
            WebRtcReconnectAction.REBUILD_PEER,
            WebRtcReconnectPolicy.actionFor(
                hasPendingOffer = true,
                remoteDescriptionApplied = true,
            ),
        )
        assertEquals(
            WebRtcReconnectAction.REBUILD_PEER,
            WebRtcReconnectPolicy.actionFor(
                hasPendingOffer = false,
                remoteDescriptionApplied = false,
            ),
        )
    }
}
