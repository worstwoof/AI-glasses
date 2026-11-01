package com.example.rv101cameraprobe

import org.junit.Assert.assertEquals
import org.junit.Test

class CameraOutputSizeSelectorTest {
    @Test
    fun `selects the closest supported JPEG to the high-resolution target`() {
        val selected = CameraOutputSizeSelector.selectClosest(
            supported = listOf(
                CaptureOutputSize(4032, 3024),
                CaptureOutputSize(1920, 1080),
                CaptureOutputSize(1280, 720),
            ),
            target = CaptureOutputSize(4032, 3024),
        )

        assertEquals(CaptureOutputSize(4032, 3024), selected)
    }

    @Test
    fun `uses the best available JPEG when the high-resolution target is absent`() {
        val selected = CameraOutputSizeSelector.selectClosest(
            supported = listOf(CaptureOutputSize(1920, 1080), CaptureOutputSize(1280, 720)),
            target = CaptureOutputSize(4032, 3024),
        )

        assertEquals(CaptureOutputSize(1920, 1080), selected)
    }

    @Test
    fun `selects the largest supported JPEG for packaging capture`() {
        val selected = CameraOutputSizeSelector.selectHighestQuality(
            supported = listOf(
                CaptureOutputSize(1920, 1080),
                CaptureOutputSize(4032, 3024),
                CaptureOutputSize(3264, 2448),
            ),
            preferredAspectRatio = 4.0 / 3.0,
        )

        assertEquals(CaptureOutputSize(4032, 3024), selected)
    }
}
