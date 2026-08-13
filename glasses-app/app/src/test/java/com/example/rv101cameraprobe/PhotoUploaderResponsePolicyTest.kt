package com.example.rv101cameraprobe

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PhotoUploaderResponsePolicyTest {
    @Test
    fun `accepts created and duplicate success responses from the phone`() {
        assertTrue(PhotoUploader.isAcceptedResponse(201, true))
        assertTrue(PhotoUploader.isAcceptedResponse(200, true))
        assertTrue(PhotoUploader.isAcceptedResponse(202, true))
    }

    @Test
    fun `rejects unsuccessful or unaccepted phone responses`() {
        assertFalse(PhotoUploader.isAcceptedResponse(400, true))
        assertFalse(PhotoUploader.isAcceptedResponse(201, false))
    }
}
