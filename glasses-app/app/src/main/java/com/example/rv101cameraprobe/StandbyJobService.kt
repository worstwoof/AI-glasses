package com.example.rv101cameraprobe

import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import androidx.core.content.ContextCompat

class StandbyJobService : JobService() {
    override fun onStartJob(params: JobParameters?): Boolean {
        DebugStatus.write(this, "StandbyJobService.onStartJob")
        runCatching {
            ContextCompat.startForegroundService(
                applicationContext,
                CaptureService.standbyIntent(applicationContext),
            )
        }.onFailure { error ->
            DebugStatus.write(
                this,
                "StandbyJobService.start error=${error.javaClass.simpleName}:${error.message}",
            )
        }
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean = true

    companion object {
        private const val JOB_ID = 0x52563101
        private const val PERIOD_MS = 15 * 60 * 1000L

        fun schedule(context: Context) {
            val scheduler = context.getSystemService(JobScheduler::class.java)
            val job = JobInfo.Builder(
                JOB_ID,
                ComponentName(context, StandbyJobService::class.java),
            )
                .setPersisted(true)
                .setPeriodic(PERIOD_MS, PERIOD_MS)
                .build()
            val result = scheduler.schedule(job)
            DebugStatus.write(context, "StandbyJobService.schedule result=$result")
        }
    }
}
