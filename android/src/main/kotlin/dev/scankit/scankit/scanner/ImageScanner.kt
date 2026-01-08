/**
 * ImageScanner.kt
 * ScanKit - Modern barcode scanner for Flutter
 *
 * This file implements barcode scanning from static images,
 * including from file paths and InputImage objects.
 */
package dev.scankit.scankit.scanner

import android.graphics.BitmapFactory
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import dev.scankit.scankit.BarcodeResult
import dev.scankit.scankit.BoundingBox
import dev.scankit.scankit.FlutterError
import dev.scankit.scankit.Point
import dev.scankit.scankit.utils.BarcodeFormatMapper
import java.io.File

/**
 * Scans barcodes from static images using ML Kit.
 */
object ImageScanner {

    /**
     * Scan a barcode from an image file.
     * @param imagePath Path to the image file
     * @param formats List of format strings to detect (null = all)
     * @param callback Called with the result or null if not found
     */
    fun scanFromFile(
        imagePath: String,
        formats: List<String>?,
        callback: (Result<BarcodeResult?>) -> Unit
    ) {
        val file = File(imagePath)
        if (!file.exists()) {
            callback(Result.success(null))
            return
        }

        val bitmap = BitmapFactory.decodeFile(imagePath)
        if (bitmap == null) {
            callback(Result.success(null))
            return
        }

        val image = InputImage.fromBitmap(bitmap, 0)
        scanFromImage(image, formats, bitmap.width, bitmap.height, callback)
    }

    /**
     * Scan a barcode from an InputImage.
     * @param image The image to scan
     * @param formats List of format strings to detect (null = all)
     * @param width Image width for normalizing coordinates
     * @param height Image height for normalizing coordinates
     * @param callback Called with the result or null if not found
     */
    fun scanFromImage(
        image: InputImage,
        formats: List<String>?,
        width: Int,
        height: Int,
        callback: (Result<BarcodeResult?>) -> Unit
    ) {
        val optionsBuilder = BarcodeScannerOptions.Builder()

        val mlKitFormats = BarcodeFormatMapper.mapFormatsToMlKit(formats)
        if (mlKitFormats.isNotEmpty()) {
            optionsBuilder.setBarcodeFormats(
                mlKitFormats.first(),
                *mlKitFormats.drop(1).toIntArray()
            )
        } else {
            optionsBuilder.setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
        }

        val scanner = BarcodeScanning.getClient(optionsBuilder.build())

        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                val barcode = barcodes.firstOrNull()
                if (barcode != null && barcode.rawValue != null) {
                    val result = createBarcodeResult(barcode, width, height)
                    callback(Result.success(result))
                } else {
                    callback(Result.success(null))
                }
            }
            .addOnFailureListener { e ->
                callback(Result.failure(FlutterError(
                    "SCAN_ERROR",
                    e.message ?: "Failed to scan barcode",
                    null
                )))
            }
    }

    /**
     * Create a BarcodeResult from an ML Kit Barcode.
     */
    private fun createBarcodeResult(barcode: Barcode, width: Int, height: Int): BarcodeResult {
        val format = BarcodeFormatMapper.mlKitFormatToString(barcode.format)

        // Get normalized bounding box
        val boundingBox = barcode.boundingBox?.let { box ->
            if (width > 0 && height > 0) {
                BoundingBox(
                    left = box.left.toDouble() / width,
                    top = box.top.toDouble() / height,
                    right = box.right.toDouble() / width,
                    bottom = box.bottom.toDouble() / height
                )
            } else null
        }

        // Get normalized corner points
        val cornerPoints = barcode.cornerPoints?.let { points ->
            if (points.size >= 4 && width > 0 && height > 0) {
                points.take(4).map { point ->
                    Point(
                        x = point.x.toDouble() / width,
                        y = point.y.toDouble() / height
                    )
                }
            } else null
        }

        return BarcodeResult(
            value = barcode.rawValue!!,
            format = format,
            rawBytes = barcode.rawBytes,
            boundingBox = boundingBox,
            cornerPoints = cornerPoints
        )
    }
}
