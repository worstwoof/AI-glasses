package com.example.rv101cameraprobe

import kotlin.math.abs

/** Pure JVM representation of a camera output size. */
data class CaptureOutputSize(val width: Int, val height: Int)

/** Selects the supported output closest to the requested capture target. */
object CameraOutputSizeSelector {
    fun selectClosest(
        supported: List<CaptureOutputSize>,
        target: CaptureOutputSize,
    ): CaptureOutputSize? = supported.minByOrNull { size ->
        abs(size.width - target.width) + abs(size.height - target.height)
    }

    /** Select the largest usable output, preferring the sensor aspect ratio. */
    fun selectHighestQuality(
        supported: List<CaptureOutputSize>,
        preferredAspectRatio: Double,
    ): CaptureOutputSize? = supported.maxWithOrNull(
        compareBy<CaptureOutputSize> { it.width.toLong() * it.height.toLong() }
            .thenBy { -abs(it.width.toDouble() / it.height - preferredAspectRatio) },
    )
}
