package com.example.rv101cameraprobe

import android.content.Context
import android.media.Image
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.webrtc.DataChannel
import org.webrtc.DefaultVideoDecoderFactory
import org.webrtc.DefaultVideoEncoderFactory
import org.webrtc.EglBase
import org.webrtc.IceCandidate
import org.webrtc.JavaI420Buffer
import org.webrtc.MediaConstraints
import org.webrtc.MediaStream
import org.webrtc.PeerConnection
import org.webrtc.PeerConnectionFactory
import org.webrtc.RtpReceiver
import org.webrtc.RtpTransceiver
import org.webrtc.SdpObserver
import org.webrtc.SessionDescription
import org.webrtc.VideoFrame
import org.webrtc.VideoSource
import org.webrtc.VideoTrack
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

data class PreviewConnectionStatus(
    val state: String,
    val message: String,
    val fps: Double = 0.0,
    val frames: Long = 0,
    val controlReady: Boolean = false,
)

private data class RemoteAnswer(
    val description: SessionDescription,
    val candidates: List<IceCandidate>,
)

class WebRtcPreviewPublisher(
    context: Context,
    private val listener: Listener,
) {
    interface Listener {
        fun onPreviewStatus(status: PreviewConnectionStatus)
        fun onPreviewCaptureRequested(request: GlassesCaptureRequest)
    }

    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private val reconnectHandler = Handler(Looper.getMainLooper())
    private val frameBusy = AtomicBoolean(false)
    private val frameSourceLock = Any()
    private var eglBase: EglBase? = null
    private var factory: PeerConnectionFactory? = null
    @Volatile private var peerConnection: PeerConnection? = null
    @Volatile private var videoSource: VideoSource? = null
    private var videoTrack: VideoTrack? = null
    private var dataChannel: DataChannel? = null
    private var iceGatheringLatch: CountDownLatch? = null
    private val localCandidateLock = Any()
    private val localCandidates = mutableListOf<IceCandidate>()
    private var capturerStarted = false
    private var adaptedFrameSize: String? = null
    private var running = false
    private var connecting = false
    private var reconnectAttempt = 0
    private var lastFrameMs = 0L
    private var firstSentFrameMs = 0L
    private var sentFrames = 0L
    private var latestStatus = PreviewConnectionStatus("stopped", "WebRTC preview stopped")

    fun start() {
        if (running) return
        running = true
        DebugStatus.write(appContext, "WebRtcPreviewPublisher.start")
        report(PreviewConnectionStatus("starting", "Starting WebRTC preview publisher"))
        executor.execute { connect() }
    }

    fun stop() {
        running = false
        reconnectHandler.removeCallbacksAndMessages(null)
        executor.execute {
            releasePeerConnection()
            factory?.dispose()
            factory = null
            eglBase?.release()
            eglBase = null
            report(PreviewConnectionStatus("stopped", "WebRTC preview stopped"))
            executor.shutdown()
        }
    }

    fun publishFrame(image: Image) {
        if (!running) return
        val now = SystemClock.elapsedRealtime()
        if (now - lastFrameMs < FRAME_INTERVAL_MS) return
        if (!frameBusy.compareAndSet(false, true)) return
        lastFrameMs = now

        try {
            val buffer = image.toI420Buffer()
            val frame = VideoFrame(buffer, FRAME_ROTATION_DEGREES, System.nanoTime())
            var submitted = false
            synchronized(frameSourceLock) {
                val source = videoSource
                if (source != null && running) {
                    if (!capturerStarted) {
                        source.capturerObserver.onCapturerStarted(true)
                        capturerStarted = true
                    }
                    val frameSize = "${image.width}x${image.height}"
                    if (adaptedFrameSize != frameSize) {
                        source.adaptOutputFormat(image.width, image.height, TARGET_FPS)
                        adaptedFrameSize = frameSize
                    }
                    source.capturerObserver.onFrameCaptured(frame)
                    submitted = true
                }
            }
            frame.release()
            if (!submitted) return
            sentFrames += 1
            if (firstSentFrameMs == 0L) firstSentFrameMs = now
            if (sentFrames == 1L || sentFrames % 15L == 0L) {
                val elapsedSeconds = (now - firstSentFrameMs).coerceAtLeast(1L) / 1000.0
                val fps = sentFrames / elapsedSeconds
                report(latestStatus.copy(fps = fps, frames = sentFrames))
            }
        } catch (error: Exception) {
            Log.w(TAG, "Unable to publish preview frame", error)
        } finally {
            frameBusy.set(false)
        }
    }

    private fun connect() {
        if (!running || connecting) return
        connecting = true
        try {
            val settings = UploadConfiguration.load(appContext)
            if (settings == null) {
                DebugStatus.write(appContext, "WebRtcPreviewPublisher.noConfig")
                report(PreviewConnectionStatus("not_configured", "Phone endpoint/token not configured"))
                return
            }
            val signalingEndpoint = deriveSignalingEndpoint(settings.endpoint)
            val hotspotPrefix = ipv4Prefix(Uri.parse(signalingEndpoint).host.orEmpty())
            DebugStatus.write(appContext, "WebRtcPreviewPublisher.connect endpoint=$signalingEndpoint prefix=$hotspotPrefix")
            initializeFactoryIfNeeded()
            releasePeerConnection()
            report(PreviewConnectionStatus("connecting", "Creating WebRTC offer"))

            val localFactory = requireNotNull(factory)
            val localVideoSource = localFactory.createVideoSource(false)
            val localVideoTrack = localFactory.createVideoTrack(VIDEO_TRACK_ID, localVideoSource).apply {
                setEnabled(true)
            }
            val config = PeerConnection.RTCConfiguration(emptyList()).apply {
                sdpSemantics = PeerConnection.SdpSemantics.UNIFIED_PLAN
                continualGatheringPolicy = PeerConnection.ContinualGatheringPolicy.GATHER_ONCE
                iceTransportsType = PeerConnection.IceTransportsType.ALL
            }
            val localPeer = requireNotNull(localFactory.createPeerConnection(config, peerObserver))
            val controlChannel = localPeer.createDataChannel(CONTROL_CHANNEL_LABEL, DataChannel.Init().apply {
                ordered = true
            })
            controlChannel.registerObserver(controlObserver)
            localPeer.addTrack(localVideoTrack, listOf(STREAM_ID))

            peerConnection = localPeer
            videoSource = localVideoSource
            videoTrack = localVideoTrack
            dataChannel = controlChannel
            synchronized(localCandidateLock) {
                localCandidates.clear()
            }
            sentFrames = 0
            firstSentFrameMs = 0

            val offer = createOffer(localPeer)
            setLocalDescription(localPeer, offer)
            waitForIceGathering(localPeer)
            val localDescription = filterSdpCandidates(localPeer.localDescription ?: offer, hotspotPrefix)
            val offerCandidates = filterCandidates(snapshotLocalCandidates(), hotspotPrefix)
            DebugStatus.write(appContext, "WebRtcPreviewPublisher.offer candidates=${offerCandidates.size}")
            report(PreviewConnectionStatus("signaling", "Sending offer to phone"))
            val answer = postOffer(signalingEndpoint, settings.token, localDescription, offerCandidates)
            DebugStatus.write(appContext, "WebRtcPreviewPublisher.answer candidates=${answer.candidates.size}")
            setRemoteDescription(localPeer, answer.description)
            filterCandidates(answer.candidates, hotspotPrefix).forEach { candidate ->
                localPeer.addIceCandidate(candidate)
            }
            reconnectAttempt = 0
            report(PreviewConnectionStatus("connected", "Offer accepted; waiting for ICE/video", controlReady = false))
        } catch (error: Exception) {
            DebugStatus.write(appContext, "WebRtcPreviewPublisher.error ${error.javaClass.simpleName}:${error.message}")
            Log.w(TAG, "WebRTC preview connection failed", error)
            report(PreviewConnectionStatus("error", "WebRTC preview failed: ${error.javaClass.simpleName}"))
            scheduleReconnect()
        } finally {
            connecting = false
        }
    }

    private fun initializeFactoryIfNeeded() {
        if (factory != null) return
        if (factoryInitialized.compareAndSet(false, true)) {
            PeerConnectionFactory.initialize(
                PeerConnectionFactory.InitializationOptions.builder(appContext)
                    .setEnableInternalTracer(false)
                    .createInitializationOptions(),
            )
        }
        eglBase = EglBase.create()
        val eglContext = requireNotNull(eglBase).eglBaseContext
        factory = PeerConnectionFactory.builder()
            .setVideoEncoderFactory(DefaultVideoEncoderFactory(eglContext, true, true))
            .setVideoDecoderFactory(DefaultVideoDecoderFactory(eglContext))
            .createPeerConnectionFactory()
    }

    private fun releasePeerConnection() {
        iceGatheringLatch?.countDown()
        iceGatheringLatch = null
        dataChannel?.unregisterObserver()
        dataChannel?.close()
        dataChannel?.dispose()
        dataChannel = null
        peerConnection?.close()
        peerConnection?.dispose()
        peerConnection = null
        videoTrack?.dispose()
        videoTrack = null
        synchronized(frameSourceLock) {
            videoSource?.let { source ->
                if (capturerStarted) {
                    source.capturerObserver.onCapturerStopped()
                }
                source.dispose()
            }
            videoSource = null
            capturerStarted = false
            adaptedFrameSize = null
        }
        frameBusy.set(false)
    }

    private fun scheduleReconnect() {
        if (!running) return
        val delay = RECONNECT_DELAYS_MS[reconnectAttempt.coerceAtMost(RECONNECT_DELAYS_MS.lastIndex)]
        reconnectAttempt += 1
        report(latestStatus.copy(message = "${latestStatus.message}; retrying in ${delay / 1000}s"))
        reconnectHandler.removeCallbacksAndMessages(null)
        reconnectHandler.postDelayed({
            if (running) executor.execute { connect() }
        }, delay)
    }

    private val peerObserver = object : PeerConnection.Observer {
        override fun onSignalingChange(newState: PeerConnection.SignalingState) {
            report(latestStatus.copy(state = "signaling", message = "Signaling: $newState"))
        }

        override fun onIceConnectionChange(newState: PeerConnection.IceConnectionState) {
            report(latestStatus.copy(state = "ice", message = "ICE: $newState"))
            if (newState == PeerConnection.IceConnectionState.FAILED ||
                newState == PeerConnection.IceConnectionState.DISCONNECTED
            ) {
                scheduleReconnect()
            }
        }

        override fun onIceConnectionReceivingChange(receiving: Boolean) = Unit

        override fun onIceGatheringChange(newState: PeerConnection.IceGatheringState) {
            report(latestStatus.copy(state = "gathering", message = "ICE gathering: $newState"))
            if (newState == PeerConnection.IceGatheringState.COMPLETE) {
                iceGatheringLatch?.countDown()
            }
        }

        override fun onIceCandidate(candidate: IceCandidate) {
            synchronized(localCandidateLock) {
                localCandidates.add(candidate)
            }
        }

        override fun onIceCandidatesRemoved(candidates: Array<out IceCandidate>) = Unit

        override fun onAddStream(stream: MediaStream) = Unit

        override fun onRemoveStream(stream: MediaStream) = Unit

        override fun onDataChannel(channel: DataChannel) = Unit

        override fun onRenegotiationNeeded() = Unit

        override fun onAddTrack(receiver: RtpReceiver, streams: Array<out MediaStream>) = Unit

        override fun onTrack(transceiver: RtpTransceiver) = Unit
    }

    private val controlObserver = object : DataChannel.Observer {
        override fun onBufferedAmountChange(previousAmount: Long) = Unit

        override fun onStateChange() {
            val ready = dataChannel?.state() == DataChannel.State.OPEN
            report(latestStatus.copy(controlReady = ready, message = "Control channel: ${dataChannel?.state()}"))
        }

        override fun onMessage(buffer: DataChannel.Buffer) {
            if (buffer.binary) return
            val bytes = ByteArray(buffer.data.remaining())
            buffer.data.get(bytes)
            val text = String(bytes, StandardCharsets.UTF_8)
            val command = runCatching { JSONObject(text) }.getOrNull() ?: return
            if (command.optString("type") == "capture") {
                val request = GlassesCaptureRequest(
                    captureType = CaptureType.fromWireValue(command.optString("captureType")),
                    trigger = command.optString("trigger").trim().ifBlank { "app_button" },
                    scene = command.optString("scene").trim().ifBlank { null },
                    mealSessionId = command.optString("mealSessionId").trim().ifBlank { null },
                    timestamp = command.optLong("timestamp", System.currentTimeMillis()),
                )
                listener.onPreviewCaptureRequested(request)
                report(latestStatus.copy(message = "Phone requested ${request.captureType.wireValue} high-resolution capture"))
            }
        }
    }

    private fun createOffer(peer: PeerConnection): SessionDescription {
        val latch = CountDownLatch(1)
        var result: SessionDescription? = null
        var failure: String? = null
        peer.createOffer(object : SimpleSdpObserver() {
            override fun onCreateSuccess(description: SessionDescription) {
                result = description
                latch.countDown()
            }

            override fun onCreateFailure(message: String) {
                failure = message
                latch.countDown()
            }
        }, MediaConstraints())
        check(latch.await(SDP_TIMEOUT_SECONDS, TimeUnit.SECONDS)) { "createOffer timed out" }
        failure?.let { error(it) }
        return requireNotNull(result) { "createOffer returned no SDP" }
    }

    private fun setLocalDescription(peer: PeerConnection, description: SessionDescription) {
        val latch = CountDownLatch(1)
        var failure: String? = null
        peer.setLocalDescription(object : SimpleSdpObserver() {
            override fun onSetSuccess() {
                latch.countDown()
            }

            override fun onSetFailure(message: String) {
                failure = message
                latch.countDown()
            }
        }, description)
        check(latch.await(SDP_TIMEOUT_SECONDS, TimeUnit.SECONDS)) { "setLocalDescription timed out" }
        failure?.let { error(it) }
    }

    private fun setRemoteDescription(peer: PeerConnection, description: SessionDescription) {
        val latch = CountDownLatch(1)
        var failure: String? = null
        peer.setRemoteDescription(object : SimpleSdpObserver() {
            override fun onSetSuccess() {
                latch.countDown()
            }

            override fun onSetFailure(message: String) {
                failure = message
                latch.countDown()
            }
        }, description)
        check(latch.await(SDP_TIMEOUT_SECONDS, TimeUnit.SECONDS)) { "setRemoteDescription timed out" }
        failure?.let { error(it) }
    }

    private fun waitForIceGathering(peer: PeerConnection) {
        if (peer.iceGatheringState() == PeerConnection.IceGatheringState.COMPLETE) return
        val latch = CountDownLatch(1)
        iceGatheringLatch = latch
        latch.await(ICE_GATHER_TIMEOUT_SECONDS, TimeUnit.SECONDS)
        iceGatheringLatch = null
    }

    private fun snapshotLocalCandidates(): List<IceCandidate> =
        synchronized(localCandidateLock) { localCandidates.toList() }

    private fun filterSdpCandidates(description: SessionDescription, prefix: String?): SessionDescription {
        if (prefix == null) return description
        val filtered = filterSdpText(description.description, prefix)
        return if (filtered == description.description) {
            description
        } else {
            SessionDescription(description.type, filtered)
        }
    }

    private fun filterSdpText(sdp: String, prefix: String?): String {
        if (prefix == null) return sdp
        val lines = sdp.lineSequence().toList()
        val candidateLines = lines.filter { it.startsWith("a=candidate:") }
        val matchingCandidateLines = candidateLines.filter { it.contains(" $prefix") }
        if (candidateLines.isEmpty() || matchingCandidateLines.isEmpty()) return sdp
        return lines
            .filter { !it.startsWith("a=candidate:") || it in matchingCandidateLines }
            .joinToString("\r\n")
            .let { if (it.endsWith("\r\n")) it else "$it\r\n" }
    }

    private fun filterCandidates(candidates: List<IceCandidate>, prefix: String?): List<IceCandidate> {
        if (prefix == null) return candidates
        val filtered = candidates.filter { it.sdp.contains(" $prefix") }
        return filtered.ifEmpty { candidates }
    }

    private fun postOffer(
        signalingEndpoint: String,
        token: String,
        offer: SessionDescription,
        candidates: List<IceCandidate>,
    ): RemoteAnswer {
        var connection: HttpURLConnection? = null
        return try {
            val payload = JSONObject()
                .put("type", offer.type.canonicalForm())
                .put("sdp", offer.description)
                .put("candidates", candidates.toJsonArray())
                .toString()
            connection = (URL(signalingEndpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = CONNECT_TIMEOUT_MS
                readTimeout = READ_TIMEOUT_MS
                doOutput = true
                setRequestProperty("X-Device-Token", token)
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("Accept", "application/json")
            }
            DataOutputStream(connection.outputStream).use { output ->
                output.write(payload.toByteArray(StandardCharsets.UTF_8))
            }
            val responseCode = connection.responseCode
            val responseBody = (if (responseCode in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()
            if (responseCode !in 200..299) {
                DebugStatus.write(appContext, "WebRtcPreviewPublisher.http $responseCode $responseBody")
                error("Phone signaling rejected offer: HTTP $responseCode $responseBody")
            }
            val json = JSONObject(responseBody)
            val type = SessionDescription.Type.fromCanonicalForm(json.getString("type"))
            RemoteAnswer(
                SessionDescription(type, filterSdpText(json.getString("sdp"), ipv4Prefix(Uri.parse(signalingEndpoint).host.orEmpty()))),
                json.optJSONArray("candidates").toIceCandidates(),
            )
        } finally {
            connection?.disconnect()
        }
    }

    private fun List<IceCandidate>.toJsonArray(): JSONArray {
        val array = JSONArray()
        forEach { candidate ->
            if (candidate.sdpMid.isNullOrBlank() || candidate.sdpMLineIndex < 0 || candidate.sdp.isBlank()) {
                return@forEach
            }
            array.put(
                JSONObject()
                    .put("sdpMid", candidate.sdpMid)
                    .put("sdpMLineIndex", candidate.sdpMLineIndex)
                    .put("candidate", candidate.sdp),
            )
        }
        return array
    }

    private fun JSONArray?.toIceCandidates(): List<IceCandidate> {
        if (this == null) return emptyList()
        val candidates = mutableListOf<IceCandidate>()
        for (index in 0 until length()) {
            val item = optJSONObject(index) ?: continue
            val sdp = item.optString("candidate")
            if (sdp.isBlank()) continue
            val sdpMid = if (item.isNull("sdpMid")) null else item.optString("sdpMid")
            val sdpMLineIndex = item.optInt("sdpMLineIndex", -1)
            if (sdpMid.isNullOrBlank() || sdpMLineIndex < 0) continue
            candidates.add(
                IceCandidate(
                    sdpMid,
                    sdpMLineIndex,
                    sdp,
                ),
            )
        }
        return candidates
    }

    private fun deriveSignalingEndpoint(uploadEndpoint: String): String {
        val uri = Uri.parse(uploadEndpoint)
        require(uri.scheme in setOf("http", "https") && !uri.host.isNullOrBlank()) {
            "Upload endpoint is invalid"
        }
        return uri.buildUpon()
            .encodedPath("/api/v1/webrtc/offer")
            .encodedQuery(null)
            .fragment(null)
            .build()
            .toString()
    }

    private fun ipv4Prefix(host: String): String? {
        val parts = host.split('.')
        if (parts.size != 4 || parts.any { it.toIntOrNull() !in 0..255 }) return null
        return "${parts[0]}.${parts[1]}.${parts[2]}."
    }

    private fun Image.toI420Buffer(): JavaI420Buffer {
        val output = JavaI420Buffer.allocate(width, height)
        copyPlane(
            planes[0],
            width,
            height,
            output.dataY,
            output.strideY,
        )
        copyPlane(
            planes[1],
            width / 2,
            height / 2,
            output.dataU,
            output.strideU,
        )
        copyPlane(
            planes[2],
            width / 2,
            height / 2,
            output.dataV,
            output.strideV,
        )
        return output
    }

    private fun copyPlane(
        plane: Image.Plane,
        width: Int,
        height: Int,
        output: ByteBuffer,
        outputStride: Int,
    ) {
        val input = plane.buffer
        for (row in 0 until height) {
            val inputRowStart = row * plane.rowStride
            val outputRowStart = row * outputStride
            for (column in 0 until width) {
                output.put(outputRowStart + column, input.get(inputRowStart + column * plane.pixelStride))
            }
        }
    }

    private fun report(status: PreviewConnectionStatus) {
        latestStatus = status
        Log.i(TAG, "preview state=${status.state} fps=${status.fps} frames=${status.frames} message=${status.message}")
        listener.onPreviewStatus(status)
    }

    private open class SimpleSdpObserver : SdpObserver {
        override fun onCreateSuccess(description: SessionDescription) = Unit
        override fun onSetSuccess() = Unit
        override fun onCreateFailure(message: String) = Unit
        override fun onSetFailure(message: String) = Unit
    }

    companion object {
        private const val TAG = "WebRtcPreviewPublisher"
        private const val STREAM_ID = "rv101-preview"
        private const val VIDEO_TRACK_ID = "rv101-preview-video"
        private const val CONTROL_CHANNEL_LABEL = "rv101-control"
        private const val FRAME_INTERVAL_MS = 66L
        private const val TARGET_FPS = 15
        private const val FRAME_ROTATION_DEGREES = 270
        private const val SDP_TIMEOUT_SECONDS = 10L
        private const val ICE_GATHER_TIMEOUT_SECONDS = 4L
        private const val CONNECT_TIMEOUT_MS = 8_000
        private const val READ_TIMEOUT_MS = 15_000
        private val RECONNECT_DELAYS_MS = longArrayOf(1_000, 2_000, 4_000, 8_000)
        private val factoryInitialized = AtomicBoolean(false)
    }
}
