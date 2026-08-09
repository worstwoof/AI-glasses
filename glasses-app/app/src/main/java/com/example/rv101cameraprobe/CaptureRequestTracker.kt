package com.example.rv101cameraprobe

data class PendingCapture(
    val metadata: CaptureUploadMetadata,
    val cooldownMs: Long,
)

/**
 * Reserves request metadata before Camera2 starts a capture, so a fast preview
 * fallback callback cannot upload with stale food metadata.
 */
class CaptureRequestTracker {
    private var pending: PendingCapture? = null

    fun begin(metadata: CaptureUploadMetadata, cooldownMs: Long): Boolean {
        if (pending != null) return false
        pending = PendingCapture(metadata, cooldownMs)
        return true
    }

    fun take(): PendingCapture? = pending.also { pending = null }

    fun clear() {
        pending = null
    }
}
