package com.example.utility

import com.example.utility.R
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.*
import android.view.accessibility.AccessibilityEvent
import android.widget.Toast
import androidx.core.app.NotificationCompat
import androidx.core.content.edit

class ClickAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_SHOW_DOT = "com.example.utility.SHOW_DOT"
        const val ACTION_START_AUTOCLICK = "com.example.utility.START_AUTOCLICK"
        const val ACTION_STOP_AUTOCLICK = "com.example.utility.STOP_AUTOCLICK"
        const val NOTIFICATION_ID = 1001
        const val CHANNEL_ID = "autoclicker_channel"
    }

    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null
    private var handler: Handler? = null
    private var runnable: Runnable? = null
    private var isClicking = false
    private var lastX = 200
    private var lastY = 200
    
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_SHOW_DOT -> {
                    markDotPending(false)
                    showFloatingDotSafe()
                }
                ACTION_START_AUTOCLICK -> {
                    markDotPending(false)
                    val x = intent.getIntExtra("x", lastX)
                    val y = intent.getIntExtra("y", lastY)
                    val delay = intent.getLongExtra("delay", 1000L)
                    startClicking(x, y, delay)
                }
                ACTION_STOP_AUTOCLICK -> removeDotAndStop()
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler = Handler(Looper.getMainLooper())
        
        createNotificationChannel()
        
        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction(ACTION_SHOW_DOT)
            addAction(ACTION_START_AUTOCLICK)
            addAction(ACTION_STOP_AUTOCLICK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }

        // Recover missed command if Flutter sent SHOW_DOT before receiver registration.
        if (isDotPending()) {
            markDotPending(false)
            showFloatingDotSafe()
        }

        Toast.makeText(this, "Accessibility Service Connected", Toast.LENGTH_SHORT).show()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AutoClicker Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun showNotification(isClicking: Boolean) {
        val stopIntent = Intent(this, NotificationActionReceiver::class.java).apply {
            action = ACTION_STOP_AUTOCLICK
        }
        val stopPendingIntent = PendingIntent.getBroadcast(
            this, 0, stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("AutoClicker Active")
            .setContentText(if (isClicking) "Clicking at ($lastX, $lastY)" else "Floating dot is active")
            .setSmallIcon(R.mipmap.ic_launcher)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun showFloatingDotSafe() {
        if (floatingView == null) {
            showFloatingDot()
            showNotification(false)
        }
    }

    private fun isDotPending(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getBoolean("flutter.autoclick_show_dot_pending", false)
    }

    private fun markDotPending(value: Boolean) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit {
            putBoolean("flutter.autoclick_show_dot_pending", value)
        }
    }

    private fun showFloatingDot() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val inflater = LayoutInflater.from(this)
        floatingView = inflater.inflate(R.layout.floating_dot, null)

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = lastX
        layoutParams.y = lastY

        floatingView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var clickStartTime = 0L

            override fun onTouch(view: View?, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        clickStartTime = System.currentTimeMillis()
                        initialX = layoutParams.x
                        initialY = layoutParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        layoutParams.x = initialX + (event.rawX - initialTouchX).toInt()
                        layoutParams.y = initialY + (event.rawY - initialTouchY).toInt()
                        lastX = layoutParams.x
                        lastY = layoutParams.y
                        windowManager.updateViewLayout(floatingView, layoutParams)
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (System.currentTimeMillis() - clickStartTime < 200) {
                            toggleClicking()
                        }
                        return true
                    }
                }
                return false
            }
        })

        windowManager.addView(floatingView, layoutParams)
    }

    private fun toggleClicking() {
        if (!isClicking) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val delay = prefs.getLong("flutter.autoclick_delay", 1000L) // shared_preferences uses long for int if stored as such
            // Or better, handle both
            val d = try { prefs.getInt("flutter.autoclick_delay", 1000).toLong() } catch (e: Exception) { prefs.getLong("flutter.autoclick_delay", 1000L) }
            
            startClicking(lastX + 30, lastY + 30, d)
        } else {
            stopClicking()
        }
    }

    private fun minimizeApp() {
        val startMain = Intent(Intent.ACTION_MAIN)
        startMain.addCategory(Intent.CATEGORY_HOME)
        startMain.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(startMain)
    }

    private fun startClicking(x: Int, y: Int, delay: Long) {
        showFloatingDotSafe()
        stopClicking()
        isClicking = true
        lastX = x - 30
        lastY = y - 30
        
        // Update floating dot position to match x, y center
        floatingView?.let {
            val lp = it.layoutParams as WindowManager.LayoutParams
            lp.x = lastX
            lp.y = lastY
            windowManager.updateViewLayout(it, lp)
        }

        showNotification(true)

        runnable = object : Runnable {
            override fun run() {
                if (isClicking) {
                    performClick(x, y)
                    handler?.postDelayed(this, delay)
                }
            }
        }
        handler?.post(runnable!!)
        Toast.makeText(this, "Started clicking", Toast.LENGTH_SHORT).show()
        minimizeApp()
    }

    private fun stopClicking() {
        isClicking = false
        runnable?.let { handler?.removeCallbacks(it) }
        runnable = null
        showNotification(false)
        Toast.makeText(this, "Stopped clicking", Toast.LENGTH_SHORT).show()
    }
    
    fun removeDotAndStop() {
        markDotPending(false)
        stopClicking()
        floatingView?.let {
            if (::windowManager.isInitialized) {
                windowManager.removeView(it)
            }
        }
        floatingView = null
        stopForeground(true)
    }

    private fun performClick(x: Int, y: Int) {
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
            .build()
        dispatchGesture(gesture, null, null)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(receiver)
        } catch (e: Exception) {}
        
        floatingView?.let {
            if (::windowManager.isInitialized) {
                windowManager.removeView(it)
            }
        }
        floatingView = null
        stopForeground(true)
    }
}
