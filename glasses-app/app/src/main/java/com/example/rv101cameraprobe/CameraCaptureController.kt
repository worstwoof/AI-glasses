package com.example.rv101cameraprobe

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import android.util.Size
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class CameraCaptureController(
    context: Context,
    private val callback: Callback,
    private val frameConsumer: (android.media.Image) -> Unit,
) {
    interface Callback {
        fun onCameraReady(previewSize: Size, photoSize: Size)
        fun onCameraBusy(message: String)
        fun onCameraError(message: String)
        fun onCameraStats(frames: Long, fps: Double)
        fun onPhotoSaved(path: String)
        fun onPhotoFallback(message: String)
        fun onPhotoError(message: String)
    }

    private val appContext = context.applicationContext
    private val cameraManager = appContext.getSystemService(CameraManager::class.java)
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var yuvReader: ImageReader? = null
    private var jpegReader: ImageReader? = null
    private var activeCameraId: String? = null
    private var previewSize: Size? = null
    private var photoSize: Size? = null
    private var jpegOrientation = 270
    private var repeatingRequest: CaptureRequest? = null
    @Volatile private var active = false
    private var opening = false
    private var retryScheduled = false
    private var openGeneration = 0L
    private var photoCaptureInFlight = false
    private var fallbackPending = false
    private var highResolutionEnabled = true
    private var previewFallbackAfterRestore: String? = null
    private var retryIndex = 0
    private var frames = 0L
    private var startedAtMs = 0L
    private val photoExecutor = Executors.newSingleThreadExecutor()

    private val retryDelaysMs = longArrayOf(1_000, 2_000, 4_000, 8_000, 15_000, 30_000)
    private val openRunnable = Runnable { openCamera() }
    private val photoTimeoutRunnable = Runnable {
        if (photoCaptureInFlight) {
            photoCaptureInFlight = false
            restorePreviewSession("High-resolution JPEG timed out; saving preview fallback")
        }
    }
    private val fallbackTimeoutRunnable = Runnable {
        if (fallbackPending) {
            fallbackPending = false
            callback.onPhotoError("Preview fallback timed out")
        }
    }

    fun start() {
        if (active) return
        active = true
        val thread = HandlerThread("RV101Camera").also { it.start() }
        val handler = Handler(thread.looper)
        cameraThread = thread
        cameraHandler = handler
        handler.post {
            if (!active) return@post
            cameraManager.registerAvailabilityCallback(availabilityCallback, handler)
            openCamera()
        }
    }

    fun stop() {
        active = false
        val handler = cameraHandler
        val thread = cameraThread
        if (handler == null) {
            photoExecutor.shutdownNow()
            return
        }
        handler.removeCallbacksAndMessages(null)
        handler.post {
            try {
                cameraManager.unregisterAvailabilityCallback(availabilityCallback)
            } catch (_: Exception) {
                // The callback may not have been registered after a failed startup.
            }
            closeCameraResources()
            photoExecutor.shutdownNow()
            thread?.quitSafely()
            cameraThread = null
            cameraHandler = null
        }
    }

    fun retryNow() {
        val handler = cameraHandler ?: return
        handler.post {
            if (!active) return@post
            DebugStatus.write(appContext, "CameraCaptureController.retryNow")
            retryScheduled = false
            handler.removeCallbacks(openRunnable)
            if (cameraDevice == null && !opening) {
                openCamera()
            }
        }
    }

    fun captureStill(): Boolean {
        if (!active || yuvReader == null || fallbackPending || photoCaptureInFlight) return false
        val camera = cameraDevice
        val jpegSurface = jpegReader?.surface
        if (camera == null || captureSession == null || jpegSurface == null) return startPreviewFallback()
        return try {
            photoCaptureInFlight = true
            callback.onPhotoFallback("Capturing ${photoSize?.width}x${photoSize?.height} JPEG")
            switchToStillSession(camera, jpegSurface)
            true
        } catch (error: CameraAccessException) {
            photoCaptureInFlight = false
            requestPreviewFallback("High-resolution JPEG unavailable; saving preview fallback")
            true
        }
    }

    @SuppressLint("MissingPermission")
    private fun openCamera() {
        if (!active || opening || cameraDevice != null || retryScheduled) return
        val handler = cameraHandler ?: return

        try {
            val id = selectCameraId() ?: run {
                callback.onCameraError("No Camera2 YUV camera found")
                return
            }
            val preview = selectOutputSize(id, ImageFormat.YUV_420_888, Size(640, 480)) ?: run {
                callback.onCameraError("Camera has no YUV output")
                return
            }
            val photo = if (highResolutionEnabled) {
                selectOutputSize(id, ImageFormat.JPEG, HIGH_RESOLUTION_TARGET) ?: run {
                    callback.onCameraError("Camera has no JPEG output")
                    return
                }
            } else {
                preview
            }
            activeCameraId = id
            previewSize = preview
            photoSize = photo
            jpegOrientation = cameraManager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 270
            createReaders(preview, photo, handler)
            opening = true
            retryScheduled = false
            val generation = ++openGeneration
            Log.i(
                TAG,
                "Opening camera generation=$generation id=$id " +
                    "preview=${preview.width}x${preview.height} " +
                    "photo=${photo.width}x${photo.height}",
            )
            cameraManager.openCamera(id, createCameraStateCallback(generation), handler)
        } catch (error: CameraAccessException) {
            opening = false
            retryOpen("Camera unavailable: ${error.message}")
        }
    }

    private fun createReaders(preview: Size, photo: Size, handler: Handler) {
        yuvReader?.close()
        jpegReader?.close()
        if (highResolutionEnabled) {
            jpegReader = ImageReader.newInstance(photo.width, photo.height, ImageFormat.JPEG, 2).apply {
                setOnImageAvailableListener({ reader ->
                    reader.acquireNextImage()?.use { image ->
                        if (photoCaptureInFlight) saveHighResolutionJpeg(image)
                    }
                }, handler)
            }
        } else {
            jpegReader = null
        }
        yuvReader = ImageReader.newInstance(preview.width, preview.height, ImageFormat.YUV_420_888, 2).apply {
            setOnImageAvailableListener({ reader ->
                reader.acquireLatestImage()?.use { image ->
                    frames += 1
                    val elapsedSeconds = (System.currentTimeMillis() - startedAtMs) / 1000.0
                    val fps = if (elapsedSeconds > 0) frames / elapsedSeconds else 0.0
                    if (frames == 1L || frames % 15L == 0L) callback.onCameraStats(frames, fps)
                    if (fallbackPending) savePreviewFallback(image)
                    frameConsumer(image)
                }
            }, handler)
        }
    }

    private fun configureSession(camera: CameraDevice) {
        val yuvSurface = yuvReader?.surface ?: return
        try {
            camera.createCaptureSession(listOf(yuvSurface), object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (!active) {
                        session.close()
                        return
                    }
                    captureSession = session
                    try {
                        val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                            addTarget(yuvSurface)
                        }.build()
                        repeatingRequest = request
                        frames = 0
                        startedAtMs = System.currentTimeMillis()
                        retryIndex = 0
                        session.setRepeatingRequest(request, null, cameraHandler)
                        callback.onCameraReady(requireNotNull(previewSize), requireNotNull(photoSize))
                        Log.i(
                            TAG,
                            "Camera session configured id=${camera.id} " +
                                "preview=${previewSize?.width}x${previewSize?.height}",
                        )
                        previewFallbackAfterRestore?.let { message ->
                            previewFallbackAfterRestore = null
                            requestPreviewFallback(message)
                        }
                    } catch (error: CameraAccessException) {
                        retryOpen("Repeating request failed: ${error.message}")
                    }
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    session.close()
                    retryOpen(
                        "Camera session configuration failed " +
                            "(id=${camera.id}, preview=${previewSize?.width}x${previewSize?.height})",
                    )
                }
            }, cameraHandler)
        } catch (error: CameraAccessException) {
            retryOpen("Capture session failed: ${error.message}")
        }
    }

    private fun retryOpen(message: String) {
        if (!active) return
        if (retryScheduled) return
        Log.w(TAG, message)
        callback.onCameraBusy(message)
        closeCameraResources()
        val delay = retryDelaysMs[retryIndex.coerceAtMost(retryDelaysMs.lastIndex)]
        retryIndex += 1
        retryScheduled = true
        cameraHandler?.removeCallbacks(openRunnable)
        cameraHandler?.postDelayed(
            {
                retryScheduled = false
                openCamera()
            },
            delay,
        )
    }

    private fun closeCameraResources() {
        openGeneration += 1
        try {
            captureSession?.stopRepeating()
        } catch (_: CameraAccessException) {
            // The session may already be closing.
        }
        captureSession?.close()
        captureSession = null
        repeatingRequest = null
        cameraDevice?.close()
        cameraDevice = null
        yuvReader?.close()
        yuvReader = null
        jpegReader?.close()
        jpegReader = null
        opening = false
        photoCaptureInFlight = false
        cameraHandler?.removeCallbacks(photoTimeoutRunnable)
        fallbackPending = false
        previewFallbackAfterRestore = null
        cameraHandler?.removeCallbacks(fallbackTimeoutRunnable)
    }

    private fun requestPreviewFallback(message: String) {
        fallbackPending = true
        callback.onPhotoFallback(message)
        resumeRepeating()
        cameraHandler?.removeCallbacks(fallbackTimeoutRunnable)
        cameraHandler?.postDelayed(fallbackTimeoutRunnable, PREVIEW_FALLBACK_TIMEOUT_MS)
    }

    private fun startPreviewFallback(): Boolean {
        fallbackPending = true
        callback.onPhotoFallback("High-resolution JPEG unavailable; saving 640x480 preview fallback")
        cameraHandler?.removeCallbacks(fallbackTimeoutRunnable)
        cameraHandler?.postDelayed(fallbackTimeoutRunnable, PREVIEW_FALLBACK_TIMEOUT_MS)
        return true
    }

    private fun switchToStillSession(camera: CameraDevice, jpegSurface: android.view.Surface) {
        try {
            captureSession?.stopRepeating()
        } catch (_: CameraAccessException) {
            // The session may already be stopped while changing outputs.
        }
        captureSession?.close()
        captureSession = null
        camera.createCaptureSession(listOf(jpegSurface), object : CameraCaptureSession.StateCallback() {
            override fun onConfigured(session: CameraCaptureSession) {
                if (!active || !photoCaptureInFlight) {
                    session.close()
                    restorePreviewSession()
                    return
                }
                captureSession = session
                try {
                    val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE).apply {
                        addTarget(jpegSurface)
                        set(CaptureRequest.JPEG_QUALITY, 95.toByte())
                        set(CaptureRequest.JPEG_ORIENTATION, jpegOrientation)
                    }.build()
                    session.capture(request, object : CameraCaptureSession.CaptureCallback() {
                        override fun onCaptureFailed(
                            session: CameraCaptureSession,
                            request: CaptureRequest,
                            failure: android.hardware.camera2.CaptureFailure,
                        ) {
                            photoCaptureInFlight = false
                            cameraHandler?.removeCallbacks(photoTimeoutRunnable)
                            restorePreviewSession("High-resolution JPEG capture failed; saving preview fallback")
                        }
                    }, cameraHandler)
                    cameraHandler?.removeCallbacks(photoTimeoutRunnable)
                    cameraHandler?.postDelayed(photoTimeoutRunnable, HIGH_RES_JPEG_TIMEOUT_MS)
                } catch (error: CameraAccessException) {
                    photoCaptureInFlight = false
                    restorePreviewSession("High-resolution JPEG unavailable; saving preview fallback")
                }
            }

            override fun onConfigureFailed(session: CameraCaptureSession) {
                photoCaptureInFlight = false
                restorePreviewSession("High-resolution JPEG session failed; saving preview fallback")
            }
        }, cameraHandler)
    }

    private fun restorePreviewSession(fallbackMessage: String? = null) {
        if (!active) return
        if (fallbackMessage != null) previewFallbackAfterRestore = fallbackMessage
        captureSession?.close()
        captureSession = null
        cameraDevice?.let(::configureSession)
    }

    private fun saveHighResolutionJpeg(image: android.media.Image) {
        photoCaptureInFlight = false
        cameraHandler?.removeCallbacks(photoTimeoutRunnable)
        val bytes = ByteArray(image.planes[0].buffer.remaining()).also { image.planes[0].buffer.get(it) }
        restorePreviewSession()
        val outputFile = File(
            requireNotNull(appContext.getExternalFilesDir(Environment.DIRECTORY_PICTURES)),
            "captures/capture_${System.currentTimeMillis()}_full.jpg",
        ).apply { parentFile?.mkdirs() }
        photoExecutor.execute {
            try {
                FileOutputStream(outputFile).use { it.write(bytes) }
                callback.onPhotoSaved(outputFile.absolutePath)
            } catch (error: Exception) {
                callback.onPhotoError("High-resolution JPEG save failed: ${error.javaClass.simpleName}")
            }
        }
    }

    private fun savePreviewFallback(image: android.media.Image) {
        fallbackPending = false
        cameraHandler?.removeCallbacks(fallbackTimeoutRunnable)
        try {
            val outputDir = File(
                requireNotNull(appContext.getExternalFilesDir(Environment.DIRECTORY_PICTURES)),
                "captures",
            ).apply { mkdirs() }
            val outputFile = File(outputDir, "capture_${System.currentTimeMillis()}_preview.jpg")
            YuvFrameConverter.saveUprightJpeg(
                YuvFrameConverter.toNv21(image),
                image.width,
                image.height,
                outputFile,
            )
            callback.onPhotoSaved(outputFile.absolutePath)
        } catch (error: Exception) {
            callback.onPhotoError("Preview fallback save failed: ${error.javaClass.simpleName}")
        }
    }

    private fun resumeRepeating() {
        val session = captureSession ?: return
        val request = repeatingRequest ?: return
        try {
            session.setRepeatingRequest(request, null, cameraHandler)
        } catch (error: CameraAccessException) {
            retryOpen("Unable to resume preview: ${error.message}")
        }
    }

    private fun selectCameraId(): String? = cameraManager.cameraIdList.firstOrNull { id ->
        cameraManager.getCameraCharacteristics(id)
            .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?.getOutputSizes(ImageFormat.YUV_420_888)
            ?.isNotEmpty() == true
    }

    private fun selectOutputSize(cameraId: String, format: Int, preferred: Size): Size? {
        val sizes = cameraManager.getCameraCharacteristics(cameraId)
            .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            ?.getOutputSizes(format)
            ?: return null
        val selected = CameraOutputSizeSelector.selectClosest(
            supported = sizes.map { size -> CaptureOutputSize(size.width, size.height) },
            target = CaptureOutputSize(preferred.width, preferred.height),
        ) ?: return null
        return sizes.firstOrNull { size ->
            size.width == selected.width && size.height == selected.height
        }
    }

    private val availabilityCallback = object : CameraManager.AvailabilityCallback() {
        override fun onCameraAvailable(cameraId: String) {
            if (active && cameraDevice == null && !opening && !retryScheduled) {
                cameraHandler?.removeCallbacks(openRunnable)
                cameraHandler?.post(openRunnable)
            }
        }

        override fun onCameraUnavailable(cameraId: String) {
            if (active && cameraDevice == null && !opening && !retryScheduled) {
                callback.onCameraBusy("Camera is in use by the system (id=$cameraId)")
            }
        }
    }

    private fun createCameraStateCallback(generation: Long) = object : CameraDevice.StateCallback() {
        override fun onOpened(camera: CameraDevice) {
            if (!active || generation != openGeneration) {
                camera.close()
                return
            }
            opening = false
            cameraDevice = camera
            Log.i(TAG, "Camera opened generation=$generation id=${camera.id}")
            configureSession(camera)
        }

        override fun onDisconnected(camera: CameraDevice) {
            camera.close()
            if (generation != openGeneration) return
            opening = false
            cameraDevice = null
            retryOpen("Camera disconnected (id=${camera.id})")
        }

        override fun onError(camera: CameraDevice, error: Int) {
            camera.close()
            if (generation != openGeneration) return
            opening = false
            cameraDevice = null
            retryOpen("Camera error: $error (id=${camera.id})")
        }
    }

    companion object {
        private const val TAG = "CameraCaptureController"
        private val HIGH_RESOLUTION_TARGET = Size(4032, 3024)
        private const val HIGH_RES_JPEG_TIMEOUT_MS = 8_000L
        private const val PREVIEW_FALLBACK_TIMEOUT_MS = 3_000L
    }
}
