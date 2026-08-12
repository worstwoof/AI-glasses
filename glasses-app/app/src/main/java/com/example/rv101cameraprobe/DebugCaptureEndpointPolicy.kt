package com.example.rv101cameraprobe

object DebugCaptureEndpointPolicy {
    const val path = "/api/v1/glasses/debug-capture"

    fun shouldHideBeforeAuthentication(debugBuild: Boolean, path: String): Boolean =
        !debugBuild && path == this.path

    fun isAllowed(debugBuild: Boolean, method: String, path: String): Boolean =
        debugBuild && method == "POST" && path == this.path
}
