package com.example.rv101cameraprobe

enum class CaptureState {
    STOPPED,
    STARTING,
    DETECTING,
    CAPTURING,
    COOLDOWN,
    CAMERA_BUSY,
    ERROR,
}

data class CaptureStatus(
    val state: CaptureState = CaptureState.STOPPED,
    val message: String = "Service stopped",
    val cameraFps: Double = 0.0,
    val frames: Long = 0,
    val cooldownRemainingMs: Long = 0,
    val lastPhotoPath: String? = null,
    val previewState: String = "stopped",
    val previewMessage: String = "WebRTC preview stopped",
    val previewFps: Double = 0.0,
    val previewFrames: Long = 0,
    val previewControlReady: Boolean = false,
)
