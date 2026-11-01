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

enum class GlassesDisplaySeverity { NEUTRAL, SUCCESS, WARNING, ERROR }

data class GlassesDisplayState(
    val mode: String = "ready",
    val title: String = "准备识别包装",
    val lines: List<String> = listOf("OK 手势拍摄配料表"),
    val severity: GlassesDisplaySeverity = GlassesDisplaySeverity.NEUTRAL,
    val expiresAtMs: Long = 0L,
)

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
    val display: GlassesDisplayState = GlassesDisplayState(),
)
