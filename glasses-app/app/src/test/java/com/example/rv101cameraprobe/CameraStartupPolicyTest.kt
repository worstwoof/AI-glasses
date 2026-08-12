package com.example.rv101cameraprobe

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CameraStartupPolicyTest {
    @Test
    fun `resumed RV101 activity without a window surface starts immediately`() {
        assertEquals(
            0L,
            CameraStartupPolicy.initialDelayMs(
                resumed = true,
                hasWindowFocus = false,
            ),
        )
        assertEquals(
            true,
            CameraStartupPolicy.shouldStartSynchronously(
                resumed = true,
                hasWindowFocus = false,
            ),
        )
    }

    @Test
    fun `paused activity has no automatic camera startup`() {
        assertNull(
            CameraStartupPolicy.initialDelayMs(
                resumed = false,
                hasWindowFocus = true,
            ),
        )
        assertEquals(
            false,
            CameraStartupPolicy.shouldStartSynchronously(
                resumed = false,
                hasWindowFocus = true,
            ),
        )
    }
}
