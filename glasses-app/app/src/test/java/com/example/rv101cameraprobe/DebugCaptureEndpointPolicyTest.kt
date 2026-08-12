package com.example.rv101cameraprobe

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DebugCaptureEndpointPolicyTest {
    @Test
    fun `debug capture endpoint is available only in debug builds`() {
        assertTrue(
            DebugCaptureEndpointPolicy.isAllowed(
                debugBuild = true,
                method = "POST",
                path = "/api/v1/glasses/debug-capture",
            ),
        )
        assertFalse(
            DebugCaptureEndpointPolicy.isAllowed(
                debugBuild = false,
                method = "POST",
                path = "/api/v1/glasses/debug-capture",
            ),
        )
    }

    @Test
    fun `debug capture endpoint rejects non post requests`() {
        assertFalse(
            DebugCaptureEndpointPolicy.isAllowed(
                debugBuild = true,
                method = "GET",
                path = "/api/v1/glasses/debug-capture",
            ),
        )
    }

    @Test
    fun `release hides the debug capture path before authentication`() {
        assertTrue(
            DebugCaptureEndpointPolicy.shouldHideBeforeAuthentication(
                debugBuild = false,
                path = "/api/v1/glasses/debug-capture",
            ),
        )
        assertFalse(
            DebugCaptureEndpointPolicy.shouldHideBeforeAuthentication(
                debugBuild = true,
                path = "/api/v1/glasses/debug-capture",
            ),
        )
    }
}
