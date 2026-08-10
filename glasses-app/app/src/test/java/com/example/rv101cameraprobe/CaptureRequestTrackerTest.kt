package com.example.rv101cameraprobe

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CaptureRequestTrackerTest {
    @Test
    fun `begin reserves packaging metadata before camera callback and rejects duplicate`() {
        val tracker = CaptureRequestTracker()
        val packaging = CaptureUploadMetadata(
            trigger = "phone_ok_gesture",
            scene = "ingredient_label",
            sceneConfidence = 0f,
            captureType = CaptureType.PACKAGING,
            timestamp = 123L,
            captureTaskId = "capture_packaging_1",
        )
        val food = CaptureUploadMetadata("app_button", "remote_preview", 0f)

        assertTrue(tracker.begin(packaging, 4_000L))
        assertFalse(tracker.begin(food, 2_000L))

        val pending = tracker.take()
        assertEquals(CaptureType.PACKAGING, pending?.metadata?.captureType)
        assertEquals("phone_ok_gesture", pending?.metadata?.trigger)
        assertEquals("capture_packaging_1", pending?.metadata?.captureTaskId)
        assertEquals(4_000L, pending?.cooldownMs)
        assertNull(tracker.take())
    }
}
