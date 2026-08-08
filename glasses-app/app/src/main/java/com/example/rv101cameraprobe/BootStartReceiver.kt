package com.example.rv101cameraprobe

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class BootStartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        DebugStatus.write(context, "BootStartReceiver.onReceive action=${intent?.action}")
        val serviceIntent = CaptureService.standbyIntent(context)
        try {
            context.startService(serviceIntent)
        } catch (startError: Exception) {
            DebugStatus.write(
                context,
                "BootStartReceiver.startService error=${startError.javaClass.simpleName}:${startError.message}",
            )
            try {
                ContextCompat.startForegroundService(context, serviceIntent)
            } catch (foregroundError: Exception) {
                DebugStatus.write(
                    context,
                    "BootStartReceiver.startForegroundService error=${foregroundError.javaClass.simpleName}:${foregroundError.message}",
                )
            }
        }
    }
}
