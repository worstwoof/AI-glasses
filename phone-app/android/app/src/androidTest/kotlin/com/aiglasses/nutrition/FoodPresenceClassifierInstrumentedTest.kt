package com.aiglasses.nutrition

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import java.io.ByteArrayOutputStream
import org.junit.Assert.assertTrue
import org.junit.Test

class FoodPresenceClassifierInstrumentedTest {
    @Test
    fun cpuInterpreterLoadsAndRunsTenFrames() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val classifier = FoodPresenceClassifier(context)
        try {
            assertTrue(classifier.runtimeName == "cpu")
            assertTrue(classifier.inputShape.contentEquals(intArrayOf(1, 224, 224, 3)))
            assertTrue(classifier.outputShape.contentEquals(intArrayOf(1, 3)))

            val jpeg = sampleJpeg()
            repeat(10) {
                val probability = classifier.predictFoodProbability(jpeg)
                assertTrue("probability=$probability", probability in 0.0..1.0)
            }
        } finally {
            classifier.close()
        }
    }

    private fun sampleJpeg(): ByteArray {
        val bitmap = Bitmap.createBitmap(640, 480, Bitmap.Config.ARGB_8888)
        return try {
            ByteArrayOutputStream().use { output ->
                check(bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output))
                output.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }
}
