package com.example.rv101cameraprobe

import android.content.Context
import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

class VoiceAnnouncer(context: Context) : TextToSpeech.OnInitListener {
    private val appContext = context.applicationContext
    private var textToSpeech: TextToSpeech? = TextToSpeech(appContext, this)
    private var mediaPlayer: MediaPlayer? = null
    private var ready = false
    private var closed = false
    private var ttsUnavailable = false
    private var pendingMessage: String? = null

    override fun onInit(status: Int) {
        if (closed || status != TextToSpeech.SUCCESS) {
            Log.w(TAG, "System TTS is unavailable")
            ttsUnavailable = true
            pendingMessage?.let(::playFallback)
            pendingMessage = null
            return
        }
        val languageResult = textToSpeech?.setLanguage(Locale.SIMPLIFIED_CHINESE)
        if (languageResult == TextToSpeech.LANG_MISSING_DATA || languageResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            Log.w(TAG, "Chinese TTS voice data is unavailable")
            ttsUnavailable = true
            pendingMessage?.let(::playFallback)
            pendingMessage = null
            return
        }
        textToSpeech?.setSpeechRate(1.0f)
        ready = true
        Log.i(TAG, "Chinese system TTS is ready")
        pendingMessage?.let(::speakNow)
        pendingMessage = null
    }

    fun speak(message: String) {
        if (closed) return
        if (ttsUnavailable) {
            playFallback(message)
            return
        }
        if (!ready) {
            pendingMessage = message
            return
        }
        speakNow(message)
    }

    fun close() {
        closed = true
        ready = false
        textToSpeech?.stop()
        textToSpeech?.shutdown()
        textToSpeech = null
        mediaPlayer?.release()
        mediaPlayer = null
    }

    private fun speakNow(message: String) {
        Log.i(TAG, "Speaking: $message")
        val result = textToSpeech?.speak(message, TextToSpeech.QUEUE_FLUSH, null, "rv101-capture-status")
        if (result == TextToSpeech.ERROR) playFallback(message)
    }

    private fun playFallback(message: String) {
        val audio = when (message) {
            "图片已保存，正在上传到手机" -> R.raw.photo_saving
            "图片已上传到手机" -> R.raw.upload_success
            "图片已保存，上传失败" -> R.raw.upload_failed
            else -> return
        }
        Log.i(TAG, "Playing bundled voice: $message")
        mediaPlayer?.release()
        mediaPlayer = MediaPlayer.create(appContext, audio)?.apply {
            setOnCompletionListener {
                it.release()
                if (mediaPlayer === it) mediaPlayer = null
            }
            start()
        }
    }

    private companion object {
        const val TAG = "VoiceAnnouncer"
    }
}
