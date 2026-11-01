package com.example.rv101cameraprobe

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.IBinder
import android.view.WindowManager
import android.graphics.Color
import android.view.View
import android.widget.TextView
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat

class MainActivity : AppCompatActivity() {
    private lateinit var connectionText: TextView
    private lateinit var stateText: TextView
    private lateinit var hintText: TextView
    private lateinit var resultPanel: View
    private lateinit var resultTitle: TextView
    private lateinit var resultText: TextView
    private var resultVisible = false
    private var captureService: CaptureService? = null
    private var bound = false
    private var autoStartAttempted = false
    private var startWhenBound = false
    private var windowFocused = false
    private var activityResumed = false
    private var startAfterFocus = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, service: IBinder) {
            captureService = (service as CaptureService.LocalBinder).service()
            bound = true
            captureService?.setStatusListener(::showStatus)
            if (startWhenBound) {
                startWhenBound = false
                DebugStatus.write(this@MainActivity, "MainActivity.startWhenBound")
                captureService?.startFromActivityBinding()
            }
        }

        override fun onServiceDisconnected(name: ComponentName) {
            captureService = null
            bound = false
            showStatus(CaptureStatus())
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        DebugStatus.write(this, "MainActivity.onCreate")
        StandbyJobService.schedule(this)
        enableEdgeToEdge()
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { view, insets ->
            val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            insets
        }

        connectionText = findViewById(R.id.connectionText)
        stateText = findViewById(R.id.stateText)
        hintText = findViewById(R.id.hintText)
        resultPanel = findViewById(R.id.resultPanel)
        resultTitle = findViewById(R.id.resultTitle)
        resultText = findViewById(R.id.resultText)
        handleLaunchIntent(intent)
        scheduleAutoStart()
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
        DebugStatus.write(this, "MainActivity.onResume")
        scheduleAutoStart()
    }

    override fun onPause() {
        activityResumed = false
        super.onPause()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        windowFocused = hasFocus
        DebugStatus.write(this, "MainActivity.onWindowFocusChanged hasFocus=$hasFocus")
        if (hasFocus && (startAfterFocus || !autoStartAttempted)) {
            startAfterFocus = false
            autoStartAttempted = true
            requestStartCapture()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleLaunchIntent(intent)
    }

    override fun onStop() {
        if (bound) {
            captureService?.setStatusListener(null)
            unbindService(serviceConnection)
            bound = false
        }
        super.onStop()
    }

    private fun requestStartCapture() {
        DebugStatus.write(this, "MainActivity.requestStartCapture")
        if (!isWindowReadyForCamera()) {
            startAfterFocus = true
            DebugStatus.write(this, "MainActivity.deferStartUntilFocus")
            showStatus(CaptureStatus(state = CaptureState.STARTING, message = "Waiting for foreground window before opening Camera2"))
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            startCapture()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_REQUEST)
        }
    }

    private fun startCapture() {
        try {
            DebugStatus.write(this, "MainActivity.startService ACTION_START")
            if (bound && captureService?.currentStatus()?.state != CaptureState.STOPPED) {
                captureService?.startFromActivityBinding()
                return
            }
            // RV101's system image may reject startForegroundService even while
            // this visible Activity is in the foreground. The service promotes
            // itself to a camera foreground service immediately in onStartCommand.
            startService(CaptureService.startIntent(this))
            bindToCaptureService()
        } catch (error: Exception) {
            DebugStatus.write(this, "MainActivity.startService error=${error.javaClass.simpleName}:${error.message}")
            startWhenBound = true
            bindToCaptureService()
            showStatus(CaptureStatus(state = CaptureState.STARTING, message = "Binding capture service after startService rejection"))
        }
    }

    private fun stopCapture() {
        captureService?.stopCapture() ?: startService(CaptureService.stopIntent(this))
        showStatus(CaptureStatus(state = CaptureState.STOPPED, message = "Stopping service"))
    }

    private fun bindToCaptureService() {
        if (!bound) {
            bindService(
                Intent(this, CaptureService::class.java),
                serviceConnection,
                Context.BIND_AUTO_CREATE,
            )
        }
    }

    private fun handleLaunchIntent(intent: Intent) {
        DebugStatus.write(this, "MainActivity.handleLaunchIntent extras=${intent.extras?.keySet()?.joinToString() ?: "none"}")
        val endpoint = intent.getStringExtra(EXTRA_UPLOAD_ENDPOINT)
        val token = intent.getStringExtra(EXTRA_UPLOAD_TOKEN)
        if (endpoint != null || token != null) {
            if (endpoint == null || token == null) {
                showStatus(CaptureStatus(state = CaptureState.ERROR, message = "Upload endpoint and token must be provided together"))
            } else {
                val error = UploadConfiguration.save(applicationContext, endpoint, token)
                val message = error ?: "Phone upload configuration saved"
                showStatus(CaptureStatus(state = if (error == null) CaptureState.STOPPED else CaptureState.ERROR, message = message))
            }
        }
        if (intent.getBooleanExtra(EXTRA_START_CAPTURE, false)) {
            autoStartAttempted = true
            stateText.post { requestStartCapture() }
        }
    }

    private fun scheduleAutoStart() {
        if (autoStartAttempted) return
        DebugStatus.write(this, "MainActivity.scheduleAutoStart")
        val initialDelay = CameraStartupPolicy.initialDelayMs(
            resumed = activityResumed,
            hasWindowFocus = windowFocused || hasWindowFocus(),
        )
        if (initialDelay == null) {
            startAfterFocus = true
            DebugStatus.write(this, "MainActivity.scheduleAutoStart waitingForFocus")
            return
        }
        if (CameraStartupPolicy.shouldStartSynchronously(
                resumed = activityResumed,
                hasWindowFocus = windowFocused || hasWindowFocus(),
            )
        ) {
            autoStartAttempted = true
            DebugStatus.write(this, "MainActivity.autoStartImmediate")
            requestStartCapture()
            return
        }
        stateText.postDelayed({
            if (!autoStartAttempted && isWindowReadyForCamera()) {
                autoStartAttempted = true
                DebugStatus.write(this, "MainActivity.autoStartDelayed")
                requestStartCapture()
            } else if (!autoStartAttempted) {
                startAfterFocus = true
                DebugStatus.write(this, "MainActivity.autoStartDelayed waitingForFocus")
            }
        }, initialDelay)
    }

    private fun isWindowReadyForCamera(): Boolean = CameraStartEligibility.canStartCamera(
        resumed = activityResumed,
        hasWindowFocus = windowFocused || hasWindowFocus(),
    )

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_REQUEST && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startCapture()
        } else if (requestCode == CAMERA_PERMISSION_REQUEST) {
            showStatus(CaptureStatus(state = CaptureState.ERROR, message = "Camera permission denied"))
        }
    }

    private fun showStatus(current: CaptureStatus) {
        runOnUiThread {
            connectionText.text = if (current.previewControlReady) "已连接手机" else "正在连接手机"
            val display = current.display
            if (display.mode == "result" || display.mode == "error") {
                resultPanel.animate().cancel()
                resultPanel.alpha = 1f
                resultVisible = true
                resultPanel.visibility = View.VISIBLE
                resultTitle.text = display.title
                resultText.text = display.lines.joinToString("\n")
                val color = when (display.severity) {
                    GlassesDisplaySeverity.ERROR -> Color.rgb(255, 138, 122)
                    GlassesDisplaySeverity.WARNING -> Color.rgb(255, 202, 112)
                    else -> Color.rgb(185, 244, 213)
                }
                resultTitle.setTextColor(color)
                stateText.visibility = View.GONE
                hintText.text = "详细内容请查看手机"
            } else {
                stateText.visibility = View.VISIBLE
                if (resultVisible) {
                    resultVisible = false
                    resultPanel.animate().alpha(0f).setDuration(280).withEndAction {
                        if (!resultVisible) resultPanel.visibility = View.GONE
                    }.start()
                }
                when (current.state) {
                    CaptureState.CAPTURING -> {
                        stateText.text = "正在拍摄"
                        hintText.text = "请保持包装稳定"
                    }
                    CaptureState.ERROR -> {
                        stateText.text = "需要重试"
                        hintText.text = "请保持画面稳定，重新拍摄"
                    }
                    CaptureState.CAMERA_BUSY -> {
                        stateText.text = "相机暂不可用"
                        hintText.text = "正在等待相机恢复"
                    }
                    CaptureState.STOPPED, CaptureState.STARTING -> {
                        stateText.text = "正在准备"
                        hintText.text = "请打开手机识别页面"
                    }
                    else -> {
                        stateText.text = if (display.mode == "analyzing") display.title else "准备识别包装"
                        hintText.text = if (display.mode == "analyzing") "请稍候" else "OK 手势拍摄配料表"
                    }
                }
            }
        }
    }

    companion object {
        private const val CAMERA_PERMISSION_REQUEST = 100
        private const val EXTRA_START_CAPTURE = "start_capture"
        private const val EXTRA_UPLOAD_ENDPOINT = "upload_endpoint"
        private const val EXTRA_UPLOAD_TOKEN = "upload_token"
    }
}
