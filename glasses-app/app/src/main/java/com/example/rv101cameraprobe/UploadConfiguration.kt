package com.example.rv101cameraprobe

import android.content.Context
import android.net.Uri

data class UploadSettings(
    val endpoint: String,
    val token: String,
)

object UploadConfiguration {
    private const val PREFS_NAME = "upload_configuration"
    private const val ENDPOINT_KEY = "endpoint"
    private const val TOKEN_KEY = "token"
    private const val HOTSPOT_DEBUG_ENDPOINT = "http://192.168.43.1:8080/api/v1/captures"
    private const val HOTSPOT_DEBUG_TOKEN = "CsF8V6pEOWqlfcktClawh60N"

    fun save(context: Context, endpoint: String, token: String): String? {
        val normalizedEndpoint = endpoint.trim().trimEnd('/')
        val normalizedToken = token.trim()
        val uri = Uri.parse(normalizedEndpoint)
        if (uri.scheme !in setOf("http", "https") || uri.host.isNullOrBlank()) {
            return "Upload endpoint must be a valid http(s) URL"
        }
        if (normalizedToken.length < 16) return "Upload token is invalid"
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(ENDPOINT_KEY, normalizedEndpoint)
            .putString(TOKEN_KEY, normalizedToken)
            .apply()
        return null
    }

    fun load(context: Context): UploadSettings? {
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val endpoint = preferences.getString(ENDPOINT_KEY, null)?.trim().orEmpty()
        val token = preferences.getString(TOKEN_KEY, null)?.trim().orEmpty()
        if (endpoint.isNotEmpty() && token.isNotEmpty() && !shouldUseHotspotDebugDefault(endpoint, token)) {
            return UploadSettings(endpoint, token)
        }
        return UploadSettings(HOTSPOT_DEBUG_ENDPOINT, HOTSPOT_DEBUG_TOKEN)
    }

    private fun shouldUseHotspotDebugDefault(endpoint: String, token: String): Boolean {
        val host = Uri.parse(endpoint).host.orEmpty()
        return host.startsWith("10.128.") ||
            (host == "192.168.43.1" && token != HOTSPOT_DEBUG_TOKEN)
    }
}
