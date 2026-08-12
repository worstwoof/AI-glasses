package com.example.rv101cameraprobe

/**
 * RV101 may resume an Activity without assigning it a drawable window surface.
 * A resumed Activity is still an eligible foreground caller for Camera2 startup.
 */
object CameraStartEligibility {
    fun canStartCamera(resumed: Boolean, hasWindowFocus: Boolean): Boolean = resumed
}
