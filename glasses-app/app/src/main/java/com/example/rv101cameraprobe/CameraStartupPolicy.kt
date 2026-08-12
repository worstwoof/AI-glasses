package com.example.rv101cameraprobe

object CameraStartupPolicy {
    fun initialDelayMs(resumed: Boolean, hasWindowFocus: Boolean): Long? =
        if (resumed) 0L else null

    fun shouldStartSynchronously(resumed: Boolean, hasWindowFocus: Boolean): Boolean = resumed
}
