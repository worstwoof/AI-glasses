package com.example.rv101cameraprobe

import android.content.Context
import android.media.Image
import android.net.Uri
import org.json.JSONObject
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class PreviewFrameReporter(context: Context) {
    private val appContext = context.applicationContext
    private val worker = Executors.newSingleThreadExecutor()
    private val uploading = AtomicBoolean(false)
    @Volatile private var running = false
    private var lastSubmitMs = 0L
    private var uploadedFrames = 0L

    fun start() {
        running = true
    }

    fun close() {
        running = false
        worker.shutdownNow()
    }

    fun submit(image: Image) {
        if (!running) return
        val now = System.currentTimeMillis()
        if (now - lastSubmitMs < FRAME_INTERVAL_MS) return
        if (!uploading.compareAndSet(false, true)) return
        lastSubmitMs = now

        val width = image.width
        val height = image.height
        val nv21 = try {
            YuvFrameConverter.toNv21(image)
        } catch (error: Exception) {
            uploading.set(false)
            DebugStatus.write(appContext, "PreviewFrameReporter.copy error=${error.javaClass.simpleName}")
            return
        }

        worker.execute {
            try {
                val jpeg = YuvFrameConverter.toUprightJpeg(nv21, width, height, JPEG_QUALITY)
                upload(jpeg, width, height)
            } catch (error: Exception) {
                DebugStatus.write(appContext, "PreviewFrameReporter.error ${error.javaClass.simpleName}:${error.message}")
            } finally {
                uploading.set(false)
            }
        }
    }

    private fun upload(jpeg: ByteArray, sourceWidth: Int, sourceHeight: Int) {
        val settings = UploadConfiguration.load(appContext) ?: return
        val endpoint = deriveSceneFrameEndpoint(settings.endpoint)
        val metadata = JSONObject()
            .put("deviceId", "RV101")
            .put("timestamp", System.currentTimeMillis())
            .put("sourceWidth", sourceWidth)
            .put("sourceHeight", sourceHeight)
            .put("format", "preview_jpeg")
            .toString()
        val boundary = "RV101-SCENE-${UUID.randomUUID()}"
        var connection: HttpURLConnection? = null
        try {
            connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                doOutput = true
                useCaches = false
                setRequestProperty("X-Device-Token", settings.token)
                setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
                setRequestProperty("Accept", "application/json")
            }
            DataOutputStream(connection.outputStream).use { output ->
                output.writeText("--$boundary\r\n")
                output.writeText("Content-Disposition: form-data; name=\"metadata\"\r\n")
                output.writeText("Content-Type: application/json; charset=utf-8\r\n\r\n")
                output.writeText(metadata)
                output.writeText("\r\n")
                output.writeText("--$boundary\r\n")
                output.writeText("Content-Disposition: form-data; name=\"image\"; filename=\"scene-frame.jpg\"\r\n")
                output.writeText("Content-Type: image/jpeg\r\n\r\n")
                output.write(jpeg)
                output.writeText("\r\n--$boundary--\r\n")
            }
            val responseCode = connection.responseCode
            if (responseCode in 200..299) {
                uploadedFrames += 1
                if (uploadedFrames == 1L || uploadedFrames % 10L == 0L) {
                    DebugStatus.write(appContext, "PreviewFrameReporter.uploaded count=$uploadedFrames")
                }
            } else {
                DebugStatus.write(appContext, "PreviewFrameReporter.http code=$responseCode")
            }
        } finally {
            connection?.disconnect()
        }
    }

    private fun deriveSceneFrameEndpoint(uploadEndpoint: String): String {
        val uri = Uri.parse(uploadEndpoint)
        require(uri.scheme in setOf("http", "https") && !uri.host.isNullOrBlank()) {
            "Upload endpoint is invalid"
        }
        return uri.buildUpon()
            .encodedPath("/api/v1/scene/frames")
            .encodedQuery(null)
            .fragment(null)
            .build()
            .toString()
    }

    private fun DataOutputStream.writeText(value: String) {
        write(value.toByteArray(Charsets.UTF_8))
    }

    private companion object {
        private const val FRAME_INTERVAL_MS = 1_000L
        private const val JPEG_QUALITY = 58
        private const val CONNECT_TIMEOUT_MS = 2_000
        private const val READ_TIMEOUT_MS = 3_000
    }
}
