package com.liumzbra.synote

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.SeekBar
import androidx.core.app.NotificationCompat
import com.liumzbra.synote.databinding.LayoutFloatingWidgetBinding

class FloatingNoteService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var binding: LayoutFloatingWidgetBinding
    private lateinit var params: WindowManager.LayoutParams

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startMyForeground()
        initializeFloatingWindow()
    }

    private fun startMyForeground() {
        val channelId = "synote_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "Synote Service", NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val notification: Notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("Synote está ativo")
            .setContentText("Toque para configurar")
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .build()

        startForeground(1, notification)
    }

    private fun initializeFloatingWindow() {
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val inflater = LayoutInflater.from(this)
        binding = LayoutFloatingWidgetBinding.inflate(inflater)

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.TOP or Gravity.START
        params.x = 0
        params.y = 100

        windowManager.addView(binding.root, params)
        setupTouchListener()
        setupControls()
    }

    private fun setupControls() {
        binding.seekTransparency.setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                val alpha = (progress / 100f).coerceAtLeast(0.2f)
                binding.root.alpha = alpha
            }
            override fun onStartTrackingTouch(seekBar: SeekBar?) {}
            override fun onStopTrackingTouch(seekBar: SeekBar?) {}
        })

        binding.btnCloseApp.setOnClickListener { stopSelf() }

        binding.btnMinimize.setOnClickListener {
            binding.contentExpanded.visibility = View.GONE
            binding.iconMinimized.visibility = View.VISIBLE
            windowManager.updateViewLayout(binding.root, params)
        }

        binding.iconMinimized.setOnClickListener {
            binding.contentExpanded.visibility = View.VISIBLE
            binding.iconMinimized.visibility = View.GONE
            windowManager.updateViewLayout(binding.root, params)
        }
    }

    private fun setupTouchListener() {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f

        val onTouchListener = View.OnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    return@OnTouchListener true
                }
                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).toInt()
                    params.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager.updateViewLayout(binding.root, params)
                    return@OnTouchListener true
                }
            }
            false
        }
        binding.headerDragArea.setOnTouchListener(onTouchListener)
        binding.iconMinimized.setOnTouchListener(onTouchListener)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::binding.isInitialized) {
            windowManager.removeView(binding.root)
        }
    }
}
