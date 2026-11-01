package com.example.rv101cameraprobe

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.util.Size
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class CaptureService : Service(),
    CameraCaptureController.Callback,
    WebRtcPreviewPublisher.Listener,
    GlassesControlServer.Listener {
    inner class LocalBinder : Binder() {
        fun service(): CaptureService = this@CaptureService
    }

    private val binder = LocalBinder()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val statusLock = Any()
    private var statusListener: ((CaptureStatus) -> Unit)? = null
    private var status = CaptureStatus()
    private var controller: CameraCaptureController? = null
    private var previewPublisher: WebRtcPreviewPublisher? = null
    private var previewFrameReporter: PreviewFrameReporter? = null
    private var controlServer: GlassesControlServer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var running = false
    private var cooldownUntilMs = 0L
    private val captureRequestTracker = CaptureRequestTracker()
    private var uploadMessage = "Photo saved"
    private var startupRunnable: Runnable? = null
    private var displayExpiryRunnable: Runnable? = null
    private val displayedResults = mutableSetOf<String>()

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        DebugStatus.write(this, "CaptureService.onStartCommand action=${intent?.action}")
        when (intent?.action) {
            ACTION_START -> if (isAuthorizedStart(intent)) {
                DebugStatus.write(this, "CaptureService.start authorized")
                startCapture()
            } else {
                DebugStatus.write(this, "CaptureService.start rejected")
                Log.w(TAG, "Rejected unauthenticated capture start request")
                stopSelf(startId)
            }
            ACTION_STOP -> stopCapture()
            ACTION_STANDBY, null -> startStandby()
        }
        return START_STICKY
    }

    fun setStatusListener(listener: ((CaptureStatus) -> Unit)?) {
        statusListener = listener
        listener?.invoke(status)
    }

    fun currentStatus(): CaptureStatus = status

    fun startFromActivityBinding() {
        DebugStatus.write(this, "CaptureService.startFromActivityBinding")
        if (running) {
            DebugStatus.write(this, "CaptureService.foregroundRetryCamera")
            controller?.retryNow()
            return
        }
        startCapture()
    }

    fun stopCapture() {
        if (!running) {
            controlServer?.stop()
            controlServer = null
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return
        }
        releaseCapturePipeline()
        controlServer?.stop()
        controlServer = null
        publish(CaptureStatus(state = CaptureState.STOPPED, message = "Service stopped"))
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        releaseCapturePipeline()
        controlServer?.stop()
        controlServer = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun startStandby() {
        ensureControlServerStarted()
        if (running) return
        DebugStatus.write(this, "CaptureService.startStandby")
        startInForeground(cameraActive = false)
        publish(CaptureStatus(state = CaptureState.STOPPED, message = "Waiting for phone app connection"))
    }

    private fun startCapture() {
        if (running) return
        DebugStatus.write(this, "CaptureService.startCapture")
        running = true
        ensureControlServerStarted()
        startInForeground(cameraActive = true)
        acquireWakeLock()
        publish(CaptureStatus(state = CaptureState.STARTING, message = "Starting foreground camera service"))
        startupRunnable = Runnable {
            if (!running) return@Runnable
            startCameraPipeline()
        }.also { runnable ->
            mainHandler.postDelayed(runnable, CAMERA_START_DELAY_MS)
        }
    }

    private fun releaseCapturePipeline() {
        if (!running &&
            controller == null &&
            previewPublisher == null &&
            previewFrameReporter == null &&
            displayExpiryRunnable == null
        ) {
            return
        }
        running = false
        mainHandler.removeCallbacksAndMessages(null)
        startupRunnable = null
        displayExpiryRunnable = null
        controller?.stop()
        controller = null
        previewPublisher?.stop()
        previewPublisher = null
        previewFrameReporter?.close()
        previewFrameReporter = null
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        clearPendingCapture()
    }

    private fun startCameraPipeline() {
        if (!running || controller != null) return
        DebugStatus.write(this, "CaptureService.startCameraPipeline")
        ensurePreviewPublisherStarted()
        ensurePreviewFrameReporterStarted()
        controller = CameraCaptureController(applicationContext, this) { image ->
            previewPublisher?.publishFrame(image)
            previewFrameReporter?.submit(image)
        }.also { it.start() }
    }

    private fun isAuthorizedStart(intent: Intent): Boolean {
        val suppliedToken = intent.getStringExtra(EXTRA_START_TOKEN)?.trim().orEmpty()
        val configuredToken = UploadConfiguration.load(applicationContext)?.token.orEmpty()
        DebugStatus.write(this, "CaptureService.auth supplied=${suppliedToken.take(6)} configured=${configuredToken.take(6)} match=${suppliedToken == configuredToken}")
        return suppliedToken.isNotEmpty() && suppliedToken == configuredToken
    }

    private fun startInForeground(cameraActive: Boolean) {
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "RV101 capture",
                NotificationManager.IMPORTANCE_LOW,
            ),
        )
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle(if (cameraActive) "RV101 capture active" else "RV101 ready for phone")
            .setContentText(
                if (cameraActive) {
                    "Camera, WebRTC preview, and phone-side scene frames are running"
                } else {
                    "Waiting for the phone app to connect on the local network"
                },
            )
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        if (cameraActive && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun ensureControlServerStarted() {
        if (controlServer != null) return
        controlServer = GlassesControlServer(applicationContext, this).also { server ->
            server.start()
        }
        DebugStatus.write(this, "CaptureService.controlServer.start")
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(PowerManager::class.java)
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:Capture").apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    override fun onCameraReady(previewSize: Size, photoSize: Size) {
        DebugStatus.write(this, "CaptureService.onCameraReady ${previewSize.width}x${previewSize.height}")
        DebugStatus.write(this, "Camera.jpegSelected ${photoSize.width}x${photoSize.height}")
        ensurePreviewPublisherStarted()
        publish(status.copy(
            state = if (cooldownUntilMs > System.currentTimeMillis()) CaptureState.COOLDOWN else CaptureState.DETECTING,
            message = "Camera ready: ${previewSize.width}x${previewSize.height}; photo ${photoSize.width}x${photoSize.height}",
        ))
    }

    private fun ensurePreviewPublisherStarted() {
        if (previewPublisher != null) return
        previewPublisher = WebRtcPreviewPublisher(applicationContext, this).also { it.start() }
        DebugStatus.write(this, "CaptureService.previewPublisher.start")
    }

    private fun ensurePreviewFrameReporterStarted() {
        if (previewFrameReporter != null) return
        previewFrameReporter = PreviewFrameReporter(applicationContext).also { it.start() }
        DebugStatus.write(this, "CaptureService.previewFrameReporter.start")
    }

    override fun onCameraBusy(message: String) {
        DebugStatus.write(this, "CaptureService.onCameraBusy $message")
        clearPendingCapture()
        publish(status.copy(state = CaptureState.CAMERA_BUSY, message = message))
    }

    override fun onCameraError(message: String) {
        DebugStatus.write(this, "CaptureService.onCameraError $message")
        clearPendingCapture()
        publish(status.copy(state = CaptureState.ERROR, message = message))
    }

    override fun onCameraStats(frames: Long, fps: Double) {
        publish(status.copy(cameraFps = fps, frames = frames))
    }

    override fun onPhotoSaved(path: String) {
        val pendingCapture = captureRequestTracker.take()
            ?: PendingCapture(DEFAULT_CAPTURE_METADATA, GESTURE_COOLDOWN_MS)
        val uploadMetadata = pendingCapture.metadata.copy(
            captureSource = if (path.endsWith("_full.jpg")) "high_res_jpeg" else "preview_fallback",
        )
        DebugStatus.write(
            this,
            "Capture.saved source=${uploadMetadata.captureSource} type=${uploadMetadata.captureType.wireValue} " +
                "scene=${uploadMetadata.scene} session=${uploadMetadata.mealSessionId ?: "none"} " +
                "task=${uploadMetadata.captureTaskId ?: "none"} path=${java.io.File(path).name}",
        )
        val cooldownMs = pendingCapture.cooldownMs
        uploadMessage = "Photo saved; uploading to phone"
        beginCooldown(path, cooldownMs)
        PhotoUploader.uploadCapture(applicationContext, java.io.File(path), uploadMetadata) { result ->
            mainHandler.post {
                if (!running) return@post
                uploadMessage = result.message
                if (!result.success) {
                    previewPublisher?.sendCaptureFailure(uploadMetadata, result.message)
                }
                val remaining = cooldownUntilMs - System.currentTimeMillis()
                publish(status.copy(
                    state = if (remaining > 0) CaptureState.COOLDOWN else CaptureState.DETECTING,
                    message = uploadMessage,
                    cooldownRemainingMs = remaining.coerceAtLeast(0),
                    lastPhotoPath = path,
                ))
            }
        }
    }

    override fun onPhotoFallback(message: String) {
        publish(status.copy(state = CaptureState.CAPTURING, message = message))
    }

    override fun onPhotoError(message: String) {
        val failed = captureRequestTracker.take()
        mainHandler.post {
            failed?.let { previewPublisher?.sendCaptureFailure(it.metadata, message) }
            publish(status.copy(state = CaptureState.ERROR, message = message,
                display = GlassesDisplayState(mode = "error", title = "拍摄失败",
                    lines = listOf("请保持稳定，等待手机重试"), severity = GlassesDisplaySeverity.ERROR)))
        }
    }

    override fun onPhoneAnalysisMessage(message: JSONObject) {
        mainHandler.post {
            if (!running) return@post
            if (message.optString("analysisType") != "packaging_ocr") return@post
            val type = message.optString("type")
            val statusValue = message.optString("status")
            val taskId = message.optString("captureTaskId")
            if (type == "analysis_result" && taskId.isNotEmpty()) {
                if (!displayedResults.add(taskId)) return@post
                if (displayedResults.size > 128) displayedResults.remove(displayedResults.first())
            }
            val display = when {
                type == "analysis_status" && statusValue == "analyzing" -> GlassesDisplayState(
                    mode = "analyzing",
                    title = "正在识别配料表",
                    lines = listOf("请稍候"),
                )
                type == "analysis_result" && statusValue == "completed" -> GlassesDisplayState(
                    mode = "result",
                    title = "识别完成",
                    lines = readDisplayLines(message),
                    severity = if ((message.optJSONArray("allergens")?.length() ?: 0) > 0) {
                        GlassesDisplaySeverity.ERROR
                    } else if (message.optString("severity") == "warning") {
                        GlassesDisplaySeverity.WARNING
                    } else {
                        GlassesDisplaySeverity.SUCCESS
                    },
                    expiresAtMs = System.currentTimeMillis() + message.optLong("displayDurationMs", 6_000L).coerceIn(2_000L, 10_000L),
                )
                type == "analysis_status" && statusValue == "error" -> GlassesDisplayState(
                    mode = "error",
                    title = "识别失败",
                    lines = listOf(sanitizeDisplayText(message.optString("message").ifBlank { "请正对配料表重新拍摄" })),
                    severity = GlassesDisplaySeverity.ERROR,
                    expiresAtMs = System.currentTimeMillis() + 6_000L,
                )
                else -> return@post
            }
            displayExpiryRunnable?.let(mainHandler::removeCallbacks)
            displayExpiryRunnable = null
            DebugStatus.write(this, "Analysis.display mode=${display.mode} task=${taskId.take(80)} lines=${display.lines.size}")
            publish(status.copy(display = display))
            if (display.expiresAtMs > 0L) {
                displayExpiryRunnable = Runnable {
                    if (running) publish(status.copy(display = GlassesDisplayState()))
                }.also { mainHandler.postDelayed(it, display.expiresAtMs - System.currentTimeMillis()) }
            }
        }
    }

    private fun readDisplayLines(message: JSONObject): List<String> {
        val lines = message.optJSONArray("displayLines")?.let { array ->
            (0 until array.length()).mapNotNull { index ->
                array.optString(index).trim().takeIf { it.isNotEmpty() }
            }
        }.orEmpty()
        return lines.ifEmpty {
            listOf(
                "商品：${message.optString("productName").ifBlank { "未识别" }}",
                "过敏原：${if ((message.optJSONArray("allergens")?.length() ?: 0) > 0) "请查看手机" else "未发现档案匹配项"}",
                "提示：${message.optString("riskSummary").ifBlank { "详见手机端分析" }}",
            )
        }.take(3).map(::sanitizeDisplayText)
    }

    private fun sanitizeDisplayText(text: String): String = text.replace(Regex("\\s+"), " ").trim().let {
        if (it.length > 22) it.take(21) + "…" else it
    }

    override fun onPreviewStatus(status: PreviewConnectionStatus) {
        mainHandler.post {
            if (!running) return@post
            publish(this.status.copy(
                previewState = status.state,
                previewMessage = status.message,
                previewFps = status.fps,
                previewFrames = status.frames,
                previewControlReady = status.controlReady,
            ))
        }
    }

    override fun onPreviewCaptureRequested(request: GlassesCaptureRequest) {
        mainHandler.post {
            if (!running) return@post
            requestPhoto(
                metadata = CaptureUploadMetadata(
                    trigger = request.trigger,
                    scene = request.scene
                        ?: if (request.captureType == CaptureType.PACKAGING) {
                            "ingredient_label"
                        } else {
                            "remote_preview"
                        },
                    sceneConfidence = 0f,
                    captureType = request.captureType,
                    timestamp = request.timestamp,
                    mealSessionId = request.mealSessionId,
                    captureTaskId = request.captureTaskId,
                ),
                cooldownMs = GESTURE_COOLDOWN_MS,
                nextStatus = status,
                message = "Phone requested ${request.captureType.wireValue} JPEG capture",
            )
        }
    }

    override fun onControlStartRequested(uploadEndpoint: String?, token: String?): GlassesControlResponse {
        if (!uploadEndpoint.isNullOrBlank() || !token.isNullOrBlank()) {
            if (uploadEndpoint.isNullOrBlank() || token.isNullOrBlank()) {
                return GlassesControlResponse(
                    400,
                    JSONObject()
                        .put("accepted", false)
                        .put("message", "uploadEndpoint and token must be provided together"),
                )
            }
            UploadConfiguration.save(applicationContext, uploadEndpoint, token)?.let { error ->
                return GlassesControlResponse(
                    400,
                    JSONObject()
                        .put("accepted", false)
                        .put("message", error),
                )
            }
        }

        mainHandler.post {
            if (running) {
                DebugStatus.write(this, "CaptureService.control restartPreview")
                previewPublisher?.stop()
                previewPublisher = null
                ensurePreviewPublisherStarted()
                publish(status.copy(message = "Phone app requested preview reconnect"))
            } else {
                DebugStatus.write(this, "CaptureService.control startCapture")
                startCapture()
            }
        }
        return GlassesControlResponse(
            202,
            JSONObject()
                .put("accepted", true)
                .put("device", "rv101-camera-probe")
                .put("running", running)
                .put("message", "Capture start requested"),
        )
    }

    override fun onControlStatusRequested(): GlassesControlResponse =
        GlassesControlResponse(
            200,
            JSONObject()
                .put("accepted", true)
                .put("device", "rv101-camera-probe")
                .put("running", running)
                .put("state", status.state.name)
                .put("message", status.message)
                .put("previewState", status.previewState)
                .put("previewControlReady", status.previewControlReady),
        )

    override fun onDebugCaptureRequested(): GlassesControlResponse {
        if (!BuildConfig.DEBUG) {
            return GlassesControlResponse(
                404,
                JSONObject().put("accepted", false).put("message", "Not found"),
            )
        }
        if (!running) {
            return GlassesControlResponse(
                409,
                JSONObject().put("accepted", false).put("message", "Camera service is not running"),
            )
        }
        mainHandler.post {
            requestPhoto(
                metadata = CaptureUploadMetadata(
                    trigger = "debug_http",
                    scene = "rv101_diagnostic",
                    sceneConfidence = 0f,
                    captureType = CaptureType.FOOD,
                    timestamp = System.currentTimeMillis(),
                ),
                cooldownMs = 0L,
                nextStatus = status,
                message = "Debug endpoint requested JPEG capture",
            )
        }
        return GlassesControlResponse(
            202,
            JSONObject().put("accepted", true).put("message", "JPEG capture requested"),
        )
    }

    private fun requestPhoto(
        metadata: CaptureUploadMetadata,
        cooldownMs: Long,
        nextStatus: CaptureStatus,
        message: String,
    ) {
        DebugStatus.write(
            this,
            "Capture.request trigger=${metadata.trigger} type=${metadata.captureType.wireValue} " +
                "scene=${metadata.scene} session=${metadata.mealSessionId ?: "none"} " +
                "task=${metadata.captureTaskId ?: "none"}",
        )
        if (!captureRequestTracker.begin(metadata, cooldownMs)) {
            publish(nextStatus.copy(state = CaptureState.CAPTURING, message = "A JPEG capture is already in progress"))
            return
        }
        val strictHighResolution = metadata.captureType == CaptureType.PACKAGING || metadata.scene == "ingredient_label"
        displayExpiryRunnable?.let(mainHandler::removeCallbacks)
        publish(status.copy(display = GlassesDisplayState()))
        if (controller?.captureStill(allowPreviewFallback = !strictHighResolution) == true) {
            publish(status.copy(state = CaptureState.CAPTURING, message = message))
        } else {
            if (strictHighResolution) {
                onPhotoError("High-resolution JPEG is not ready")
            } else {
                captureRequestTracker.clear()
                publish(nextStatus.copy(state = CaptureState.ERROR, message = "Camera is not ready for JPEG capture"))
            }
        }
    }

    private fun clearPendingCapture() {
        captureRequestTracker.clear()
    }

    private fun beginCooldown(photoPath: String, cooldownMs: Long) {
        cooldownUntilMs = System.currentTimeMillis() + cooldownMs
        val updateCooldown = object : Runnable {
            override fun run() {
                if (!running) return
                val remaining = cooldownUntilMs - System.currentTimeMillis()
                if (remaining <= 0) {
                    publish(status.copy(
                        state = CaptureState.DETECTING,
                        message = "Camera preview running; phone app handles scene classification",
                        cooldownRemainingMs = 0,
                        lastPhotoPath = photoPath,
                    ))
                } else {
                    publish(status.copy(
                        state = CaptureState.COOLDOWN,
                        message = uploadMessage,
                        cooldownRemainingMs = remaining,
                        lastPhotoPath = photoPath,
                    ))
                    mainHandler.postDelayed(this, 250)
                }
            }
        }
        mainHandler.post(updateCooldown)
    }

    private fun publish(next: CaptureStatus) {
        val listener: ((CaptureStatus) -> Unit)?
        synchronized(statusLock) {
            status = next
            listener = statusListener
        }
        Log.i(
            TAG,
            "state=${next.state} frames=${next.frames} cameraFps=${next.cameraFps} " +
                "preview=${next.previewState} previewFps=${next.previewFps} " +
                "control=${next.previewControlReady} message=${next.message}",
        )
        listener?.invoke(next)
    }

    companion object {
        const val ACTION_START = "com.example.rv101cameraprobe.action.START"
        const val ACTION_STOP = "com.example.rv101cameraprobe.action.STOP"
        const val ACTION_STANDBY = "com.example.rv101cameraprobe.action.STANDBY"
        private const val EXTRA_START_TOKEN = "start_token"
        private const val TAG = "CaptureService"
        private const val CHANNEL_ID = "rv101_capture"
        private const val NOTIFICATION_ID = 1001
        private const val GESTURE_COOLDOWN_MS = 3_000L
        private const val CAMERA_START_DELAY_MS = 1_200L
        private val DEFAULT_CAPTURE_METADATA = CaptureUploadMetadata("manual", "unknown", 0f)

        fun startIntent(context: Context): Intent = Intent(context, CaptureService::class.java)
            .setAction(ACTION_START)
            .putExtra(EXTRA_START_TOKEN, UploadConfiguration.load(context)?.token)
        fun standbyIntent(context: Context): Intent = Intent(context, CaptureService::class.java).setAction(ACTION_STANDBY)
        fun stopIntent(context: Context): Intent = Intent(context, CaptureService::class.java).setAction(ACTION_STOP)
    }
}
