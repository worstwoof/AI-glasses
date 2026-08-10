package com.example.rv101cameraprobe

import android.content.Context
import android.graphics.BitmapFactory
import org.json.JSONObject
import java.io.DataOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.concurrent.Executors

data class UploadResult(
    val success: Boolean,
    val message: String,
)

data class CaptureUploadMetadata(
    val trigger: String,
    val scene: String,
    val sceneConfidence: Float,
    val captureType: CaptureType = CaptureType.FOOD,
    val timestamp: Long = System.currentTimeMillis(),
    val captureSource: String = "unknown",
    val mealSessionId: String? = null,
    val captureTaskId: String? = null,
)

object PhotoUploader {
    private val executor = Executors.newSingleThreadExecutor()

    fun uploadCapture(
        context: Context,
        image: File,
        metadata: CaptureUploadMetadata,
        callback: (UploadResult) -> Unit,
    ) {
        val settings = UploadConfiguration.load(context)
        if (settings == null) {
            callback(UploadResult(false, "Upload not configured; photo kept locally"))
            return
        }
        if (!image.isFile) {
            callback(UploadResult(false, "Saved photo file is missing"))
            return
        }
        executor.execute {
            callback(upload(settings, image, metadata))
        }
    }

    private fun upload(settings: UploadSettings, image: File, capture: CaptureUploadMetadata): UploadResult {
        var connection: HttpURLConnection? = null
        return try {
            val dimensions = BitmapFactory.Options().also { options ->
                options.inJustDecodeBounds = true
                BitmapFactory.decodeFile(image.absolutePath, options)
            }
            if (dimensions.outWidth <= 0 || dimensions.outHeight <= 0) {
                return UploadResult(false, "Saved file is not a readable JPEG")
            }
            val metadataJson = JSONObject()
                .put("deviceId", "RV101")
                .put("timestamp", capture.timestamp)
                .put("trigger", capture.trigger)
                .put("type", capture.captureType.wireValue)
                .put("captureSource", capture.captureSource)
                .put("scene", capture.scene)
                .put("sceneConfidence", capture.sceneConfidence)
                .put("width", dimensions.outWidth)
                .put("height", dimensions.outHeight)
            capture.mealSessionId?.let { metadataJson.put("mealSessionId", it) }
            capture.captureTaskId?.takeIf { it.isNotBlank() }?.let {
                metadataJson.put("captureTaskId", it)
            }
            val metadata = metadataJson.toString()
            val boundary = "RV101-${UUID.randomUUID()}"
            connection = (URL(settings.endpoint).openConnection() as HttpURLConnection).apply {
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
                writeTextPart(output, boundary, "metadata", metadata)
                writeFilePart(output, boundary, "image", image)
                output.writeText("--$boundary--\r\n")
            }
            val responseCode = connection.responseCode
            val responseBody = (if (responseCode in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()
            val accepted = runCatching { JSONObject(responseBody).optBoolean("accepted") }.getOrDefault(false)
            if (responseCode == HttpURLConnection.HTTP_CREATED && accepted) {
                UploadResult(true, "Photo uploaded to phone")
            } else {
                UploadResult(false, "Phone rejected upload (HTTP $responseCode); photo kept locally")
            }
        } catch (error: Exception) {
            UploadResult(false, "Upload failed: ${error.javaClass.simpleName}; photo kept locally")
        } finally {
            connection?.disconnect()
        }
    }

    private fun writeTextPart(output: DataOutputStream, boundary: String, name: String, value: String) {
        output.writeText("--$boundary\r\n")
        output.writeText("Content-Disposition: form-data; name=\"$name\"\r\n")
        output.writeText("Content-Type: application/json; charset=utf-8\r\n\r\n")
        output.writeText(value)
        output.writeText("\r\n")
    }

    private fun writeFilePart(output: DataOutputStream, boundary: String, name: String, file: File) {
        output.writeText("--$boundary\r\n")
        output.writeText("Content-Disposition: form-data; name=\"$name\"; filename=\"${file.name}\"\r\n")
        output.writeText("Content-Type: image/jpeg\r\n\r\n")
        file.inputStream().use { input -> input.copyTo(output) }
        output.writeText("\r\n")
    }

    private fun DataOutputStream.writeText(value: String) {
        write(value.toByteArray(Charsets.UTF_8))
    }

    private const val CONNECT_TIMEOUT_MS = 8_000
    private const val READ_TIMEOUT_MS = 30_000
}
