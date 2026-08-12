package com.example.rv101cameraprobe

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CameraStartEligibilityTest {
    @Test
    fun `resumed RV101 activity may start camera without a visible window surface`() {
        assertTrue(
            CameraStartEligibility.canStartCamera(
                resumed = true,
                hasWindowFocus = false,
            ),
        )
    }

    @Test
    fun `activity must be resumed before camera startup`() {
        assertFalse(
            CameraStartEligibility.canStartCamera(
                resumed = false,
                hasWindowFocus = true,
            ),
        )
    }
}
