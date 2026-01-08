package dev.scankit.scankit

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.view.View

class ScanOverlayView(context: Context) : View(context) {

    private val backgroundPaint = Paint().apply {
        color = Color.parseColor("#80000000")
        style = Paint.Style.FILL
    }

    private val clearPaint = Paint().apply {
        xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
        isAntiAlias = true
    }

    private val cornerPaint = Paint().apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = 8f
        isAntiAlias = true
        strokeCap = Paint.Cap.ROUND
    }

    private val scanRect = RectF()
    private val cornerLength = 60f

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val viewWidth = width.toFloat()
        val viewHeight = height.toFloat()

        // Calculate scan area (70% of min dimension, centered)
        val scanSize = minOf(viewWidth, viewHeight) * 0.7f
        val left = (viewWidth - scanSize) / 2
        val top = (viewHeight - scanSize) / 2
        scanRect.set(left, top, left + scanSize, top + scanSize)

        // Save layer for transparency
        val saveCount = canvas.saveLayer(0f, 0f, viewWidth, viewHeight, null)

        // Draw semi-transparent background
        canvas.drawRect(0f, 0f, viewWidth, viewHeight, backgroundPaint)

        // Clear the scan area
        canvas.drawRect(scanRect, clearPaint)

        // Restore layer
        canvas.restoreToCount(saveCount)

        // Draw corner brackets
        drawCorners(canvas)
    }

    private fun drawCorners(canvas: Canvas) {
        val left = scanRect.left
        val top = scanRect.top
        val right = scanRect.right
        val bottom = scanRect.bottom

        // Top-left corner
        canvas.drawLine(left, top + cornerLength, left, top, cornerPaint)
        canvas.drawLine(left, top, left + cornerLength, top, cornerPaint)

        // Top-right corner
        canvas.drawLine(right - cornerLength, top, right, top, cornerPaint)
        canvas.drawLine(right, top, right, top + cornerLength, cornerPaint)

        // Bottom-left corner
        canvas.drawLine(left, bottom - cornerLength, left, bottom, cornerPaint)
        canvas.drawLine(left, bottom, left + cornerLength, bottom, cornerPaint)

        // Bottom-right corner
        canvas.drawLine(right - cornerLength, bottom, right, bottom, cornerPaint)
        canvas.drawLine(right, bottom, right, bottom - cornerLength, cornerPaint)
    }
}
