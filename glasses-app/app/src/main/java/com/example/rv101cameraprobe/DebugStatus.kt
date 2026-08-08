package com.example.rv101cameraprobe

import android.content.Context
import android.os.SystemClock
import java.io.File

object DebugStatus {
    fun write(context: Context, message: String) {
        runCatching {
            val directory = context.getExternalFilesDir(null) ?: return
            val file = File(directory, "rv101-status.txt")
            file.parentFile?.mkdirs()
            file.appendText("${SystemClock.elapsedRealtime()} $message\n")
        }
    }
}
