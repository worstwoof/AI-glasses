package com.example.rv101cameraprobe

enum class CaptureType(val wireValue: String) {
    FOOD("food"),
    PACKAGING("packaging"),
    UNKNOWN("unknown");

    companion object {
        fun fromWireValue(value: String?): CaptureType = when (value?.trim()?.lowercase()) {
            null, "", "food" -> FOOD
            "packaging" -> PACKAGING
            else -> UNKNOWN
        }
    }
}

data class GlassesCaptureRequest(
    val captureType: CaptureType = CaptureType.FOOD,
    val trigger: String = "app_button",
    val timestamp: Long = System.currentTimeMillis(),
)
