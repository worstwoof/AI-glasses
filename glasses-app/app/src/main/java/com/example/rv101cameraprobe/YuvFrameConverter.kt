package com.example.rv101cameraprobe

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
import android.media.Image
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

object YuvFrameConverter {
    fun toNv21(image: Image): ByteArray {
        val width = image.width
        val height = image.height
        val output = ByteArray(width * height * 3 / 2)
        var offset = 0
        val yPlane = image.planes[0]

        for (row in 0 until height) {
            val rowStart = row * yPlane.rowStride
            for (column in 0 until width) {
                output[offset++] = yPlane.buffer.get(rowStart + column * yPlane.pixelStride)
            }
        }

        val uPlane = image.planes[1]
        val vPlane = image.planes[2]
        for (row in 0 until height / 2) {
            val uRowStart = row * uPlane.rowStride
            val vRowStart = row * vPlane.rowStride
            for (column in 0 until width / 2) {
                output[offset++] = vPlane.buffer.get(vRowStart + column * vPlane.pixelStride)
                output[offset++] = uPlane.buffer.get(uRowStart + column * uPlane.pixelStride)
            }
        }
        return output
    }

    fun toUprightBitmap(nv21: ByteArray, width: Int, height: Int): Bitmap {
        val jpegBytes = ByteArrayOutputStream().use { stream ->
            check(YuvImage(nv21, ImageFormat.NV21, width, height, null).compressToJpeg(
                Rect(0, 0, width, height),
                80,
                stream,
            )) { "YUV frame encoding failed" }
            stream.toByteArray()
        }
        val rawBitmap = requireNotNull(BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)) {
            "Unable to decode camera frame"
        }
        val uprightBitmap = Bitmap.createBitmap(
            rawBitmap,
            0,
            0,
            rawBitmap.width,
            rawBitmap.height,
            Matrix().apply { postRotate(270f) },
            true,
        )
        if (uprightBitmap !== rawBitmap) rawBitmap.recycle()
        return uprightBitmap
    }

    fun saveUprightJpeg(nv21: ByteArray, width: Int, height: Int, outputFile: File) {
        val bitmap = toUprightBitmap(nv21, width, height)
        try {
            FileOutputStream(outputFile).use { stream ->
                check(bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)) {
                    "Preview JPEG encoding failed"
                }
            }
        } finally {
            bitmap.recycle()
        }
    }

    fun toUprightJpeg(nv21: ByteArray, width: Int, height: Int, quality: Int): ByteArray {
        val bitmap = toUprightBitmap(nv21, width, height)
        return try {
            ByteArrayOutputStream().use { stream ->
                check(bitmap.compress(Bitmap.CompressFormat.JPEG, quality.coerceIn(30, 95), stream)) {
                    "Preview JPEG encoding failed"
                }
                stream.toByteArray()
            }
        } finally {
            bitmap.recycle()
        }
    }
}
