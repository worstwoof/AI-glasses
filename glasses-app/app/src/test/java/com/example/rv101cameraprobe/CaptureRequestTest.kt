package com.example.rv101cameraprobe

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CaptureRequestTest {
    @Test
    fun mealRequestRetainsSceneAndSessionMetadata() {
        val request = GlassesCaptureRequest(
            captureType = CaptureType.FOOD,
            trigger = "meal_start",
            scene = "meal_before",
            mealSessionId = "meal_test_1",
            captureTaskId = "capture_test_1",
        )

        assertEquals("meal_before", request.scene)
        assertEquals("meal_test_1", request.mealSessionId)
        assertEquals("capture_test_1", request.captureTaskId)
    }

    @Test
    fun legacyRequestKeepsExistingDefaults() {
        val request = GlassesCaptureRequest()

        assertEquals(CaptureType.FOOD, request.captureType)
        assertEquals("app_button", request.trigger)
        assertNull(request.scene)
        assertNull(request.mealSessionId)
        assertNull(request.captureTaskId)
    }
}
