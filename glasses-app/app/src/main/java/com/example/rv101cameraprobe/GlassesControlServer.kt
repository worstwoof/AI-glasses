package com.example.rv101cameraprobe

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

data class GlassesControlResponse(
    val statusCode: Int,
    val body: JSONObject,
)

class GlassesControlServer(
    context: Context,
    private val listener: Listener,
) {
    interface Listener {
        fun onControlStartRequested(uploadEndpoint: String?, token: String?): GlassesControlResponse
        fun onControlStatusRequested(): GlassesControlResponse
    }

    private val appContext = context.applicationContext
    private val running = AtomicBoolean(false)
    @Volatile private var serverSocket: ServerSocket? = null
    private var acceptThread: Thread? = null

    fun start() {
        if (!running.compareAndSet(false, true)) return
        acceptThread = Thread({ acceptLoop() }, "RV101ControlServer").apply {
            isDaemon = true
            start()
        }
    }

    fun stop() {
        running.set(false)
        runCatching { serverSocket?.close() }
        serverSocket = null
        acceptThread?.interrupt()
        acceptThread = null
    }

    private fun acceptLoop() {
        try {
            val socket = ServerSocket().apply {
                reuseAddress = true
                bind(InetSocketAddress(CONTROL_PORT))
            }
            serverSocket = socket
            DebugStatus.write(appContext, "GlassesControlServer.listening port=$CONTROL_PORT")
            while (running.get()) {
                val client = try {
                    socket.accept()
                } catch (error: Exception) {
                    if (running.get()) {
                        DebugStatus.write(
                            appContext,
                            "GlassesControlServer.accept error=${error.javaClass.simpleName}:${error.message}",
                        )
                    }
                    break
                }
                Thread({ handleClient(client) }, "RV101ControlClient").apply {
                    isDaemon = true
                    start()
                }
            }
        } catch (error: Exception) {
            DebugStatus.write(
                appContext,
                "GlassesControlServer.listen error=${error.javaClass.simpleName}:${error.message}",
            )
            Log.w(TAG, "Unable to start control server", error)
        } finally {
            running.set(false)
            runCatching { serverSocket?.close() }
            serverSocket = null
        }
    }

    private fun handleClient(socket: Socket) {
        socket.use { client ->
            client.soTimeout = CLIENT_TIMEOUT_MS
            val reader = BufferedReader(InputStreamReader(client.getInputStream(), StandardCharsets.UTF_8))
            val requestLine = reader.readLine().orEmpty()
            if (requestLine.isBlank()) return
            val requestParts = requestLine.split(' ')
            val method = requestParts.getOrNull(0).orEmpty()
            val path = requestParts.getOrNull(1).orEmpty().substringBefore('?')
            val headers = readHeaders(reader)
            val contentLength = headers["content-length"]?.toIntOrNull()?.coerceAtLeast(0) ?: 0
            val body = if (contentLength > 0) readBody(reader, contentLength) else ""
            val response = route(method, path, headers, body)
            writeResponse(client, response)
        }
    }

    private fun readHeaders(reader: BufferedReader): Map<String, String> {
        val headers = mutableMapOf<String, String>()
        while (true) {
            val line = reader.readLine() ?: break
            if (line.isEmpty()) break
            val separator = line.indexOf(':')
            if (separator <= 0) continue
            headers[line.substring(0, separator).trim().lowercase(Locale.US)] =
                line.substring(separator + 1).trim()
        }
        return headers
    }

    private fun readBody(reader: BufferedReader, contentLength: Int): String {
        val buffer = CharArray(contentLength)
        var offset = 0
        while (offset < contentLength) {
            val count = reader.read(buffer, offset, contentLength - offset)
            if (count < 0) break
            offset += count
        }
        return String(buffer, 0, offset)
    }

    private fun route(
        method: String,
        path: String,
        headers: Map<String, String>,
        body: String,
    ): GlassesControlResponse {
        if (method == "GET" && path == STATUS_PATH) {
            return listener.onControlStatusRequested()
        }
        if (method != "POST" || path != START_PATH) {
            return GlassesControlResponse(
                404,
                JSONObject()
                    .put("accepted", false)
                    .put("device", DEVICE_NAME)
                    .put("message", "Not found"),
            )
        }
        val suppliedToken = headers["x-device-token"].orEmpty()
        val configuredToken = UploadConfiguration.load(appContext)?.token.orEmpty()
        if (suppliedToken.isBlank() || suppliedToken != configuredToken) {
            DebugStatus.write(appContext, "GlassesControlServer.unauthorized supplied=${suppliedToken.take(6)}")
            return GlassesControlResponse(
                401,
                JSONObject()
                    .put("accepted", false)
                    .put("device", DEVICE_NAME)
                    .put("message", "Pairing token rejected"),
            )
        }

        val json = runCatching { JSONObject(body.ifBlank { "{}" }) }.getOrElse { JSONObject() }
        val uploadEndpoint = json.optString("uploadEndpoint").trim().ifBlank { null }
        val token = json.optString("token").trim().ifBlank { null }
        DebugStatus.write(appContext, "GlassesControlServer.start endpoint=$uploadEndpoint")
        return listener.onControlStartRequested(uploadEndpoint, token)
    }

    private fun writeResponse(socket: Socket, response: GlassesControlResponse) {
        val output = socket.getOutputStream()
        val body = response.body.toString().toByteArray(StandardCharsets.UTF_8)
        val header = buildString {
            append("HTTP/1.1 ${response.statusCode} ${reasonPhrase(response.statusCode)}\r\n")
            append("Content-Type: application/json; charset=utf-8\r\n")
            append("Content-Length: ${body.size}\r\n")
            append("Connection: close\r\n")
            append("\r\n")
        }.toByteArray(StandardCharsets.UTF_8)
        output.write(header)
        output.write(body)
        output.flush()
    }

    private fun reasonPhrase(statusCode: Int): String = when (statusCode) {
        200 -> "OK"
        202 -> "Accepted"
        400 -> "Bad Request"
        401 -> "Unauthorized"
        404 -> "Not Found"
        else -> "OK"
    }

    companion object {
        const val CONTROL_PORT = 8088
        private const val TAG = "GlassesControlServer"
        private const val CLIENT_TIMEOUT_MS = 5_000
        private const val DEVICE_NAME = "rv101-camera-probe"
        private const val START_PATH = "/api/v1/glasses/start"
        private const val STATUS_PATH = "/api/v1/glasses/status"
    }
}
