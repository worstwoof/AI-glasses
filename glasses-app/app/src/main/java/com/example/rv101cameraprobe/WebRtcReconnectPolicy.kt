package com.example.rv101cameraprobe

enum class WebRtcReconnectAction {
    REUSE_PENDING_OFFER,
    REBUILD_PEER,
}

object WebRtcReconnectPolicy {
    fun actionFor(
        hasPendingOffer: Boolean,
        remoteDescriptionApplied: Boolean,
    ): WebRtcReconnectAction =
        if (hasPendingOffer && !remoteDescriptionApplied) {
            WebRtcReconnectAction.REUSE_PENDING_OFFER
        } else {
            WebRtcReconnectAction.REBUILD_PEER
        }
}
