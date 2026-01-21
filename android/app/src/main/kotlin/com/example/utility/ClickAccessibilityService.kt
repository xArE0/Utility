package com.example.utility

import com.example.utility.R
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
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
import android.widget.ImageView

class ClickAccessibilityService : AccessibilityService() {

    companion object {
        const val ACTION_SHOW_DOT = "com.example.utility.SHOW_DOT"
        const val ACTION_START_AUTOCLICK = "com.example.utility.START_AUTOCLICK"
        const val ACTION_STOP_AUTOCLICK = "com.example.utility.STOP_AUTOCLICK"
    }

    private lateinit var windowManager: WindowManager
    private var floatingView: View? = null
    private var handler: Handler? = null
    private var runnable: Runnable? = null
    private var isClicking = false
    
    private val showDotReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_SHOW_DOT -> showFloatingDotSafe()
                ACTION_START_AUTOCLICK -> {
                    val x = intent.getIntExtra("x", -1)
                    val y = intent.getIntExtra("y", -1)
                    val delay = intent.getLongExtra("delay", 1000L)
                    if (x >= 0 && y >= 0) startClicking(x, y, delay)
                }
                ACTION_STOP_AUTOCLICK -> stopClicking()
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        if (handler == null) handler = Handler(Looper.getMainLooper())
        
        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction(ACTION_SHOW_DOT)
            addAction(ACTION_START_AUTOCLICK)
            addAction(ACTION_STOP_AUTOCLICK)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(showDotReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(showDotReceiver, filter)
        }
        
        android.widget.Toast.makeText(this, "Accessibility Service Connected", android.widget.Toast.LENGTH_SHORT).show()
        showFloatingDotSafe()
    }
    
    private fun showFloatingDotSafe() {
        try {
            if (floatingView == null) {
                showFloatingDot()
            } else {
                android.widget.Toast.makeText(this, "Dot already visible", android.widget.Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            android.widget.Toast.makeText(this, "Error showing dot: ${e.message}", android.widget.Toast.LENGTH_LONG).show()
            e.printStackTrace()
        }
    }

    private fun showFloatingDot() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val inflater = LayoutInflater.from(this)
        floatingView = inflater.inflate(R.layout.floating_dot, null)

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY, 
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = 200
        layoutParams.y = 200

        floatingView?.setOnTouchListener(object : View.OnTouchListener {
            var initialX = 0
            var initialY = 0
            var initialTouchX = 0f
            var initialTouchY = 0f
            var clickStartTime = 0L

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
                        windowManager.updateViewLayout(floatingView, layoutParams)
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        // Only start clicking if it's a quick tap, not drag
                        if (System.currentTimeMillis() - clickStartTime < 200) {
                            if (!isClicking) {
                                startClicking(layoutParams.x + 40, layoutParams.y + 40)
                                isClicking = true
                            } else {
                                stopClicking()
                                isClicking = false
                            }
                        }
                        return true
                    }
                }
                return false
            }
        })

        windowManager.addView(floatingView, layoutParams)
    }

    fun startClicking(x: Int, y: Int) {
        startClicking(x, y, null)
    }

    private fun startClicking(x: Int, y: Int, explicitDelay: Long?) {
        if (handler == null) handler = Handler(Looper.getMainLooper())
        // stop any existing loop
        stopClicking()

        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val delayFromPrefs = prefs.getInt("autoclick_delay", 1000).toLong()
        val delay = explicitDelay ?: delayFromPrefs
        isClicking = true

        runnable = object : Runnable {
            override fun run() {
                performClick(x, y)
                handler?.postDelayed(this, delay)
            }
        }
        handler?.post(runnable!!)
    }

    fun stopClicking() {
        runnable?.let { handler?.removeCallbacks(it) }
        runnable = null
        isClicking = false
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
            unregisterReceiver(showDotReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        floatingView?.let {
            if (::windowManager.isInitialized) {
                windowManager.removeView(it)
            }
        }
        floatingView = null
    }
}
