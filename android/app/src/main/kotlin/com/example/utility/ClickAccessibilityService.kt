package com.example.utility

import com.example.utility.R
import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Context
import android.graphics.Path
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.view.*
import android.view.accessibility.AccessibilityEvent
import android.widget.ImageView

class ClickAccessibilityService : AccessibilityService() {

    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: View
    private var handler: Handler? = null
    private var runnable: Runnable? = null
    private var isClicking = false

    override fun onServiceConnected() {
        super.onServiceConnected()
        handler = Handler(Looper.getMainLooper())
        showFloatingDot()
    }

    private fun showFloatingDot() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val inflater = LayoutInflater.from(this)
        floatingView = inflater.inflate(R.layout.floating_dot, null)

        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,  // ✅ this is critical
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )

        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = 200
        layoutParams.y = 200

        floatingView.setOnTouchListener(object : View.OnTouchListener {
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
                                startClicking(layoutParams.x + 40, layoutParams.y + 40, 1000)
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

    fun startClicking(x: Int, y: Int, delay: Long) {
        runnable = object : Runnable {
            override fun run() {
                performClick(x, y)
                handler?.postDelayed(this, delay)
            }
        }
        handler?.post(runnable!!)
    }

    fun stopClicking() {
        handler?.removeCallbacks(runnable!!)
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
        if (::windowManager.isInitialized && ::floatingView.isInitialized) {
            windowManager.removeView(floatingView)
        }
    }
}
