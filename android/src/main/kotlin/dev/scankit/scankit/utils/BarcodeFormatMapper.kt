/**
 * BarcodeFormatMapper.kt
 * ScanKit - Modern barcode scanner for Flutter
 *
 * This file provides mapping between string format identifiers
 * and ML Kit barcode format constants.
 */
package dev.scankit.scankit.utils

import com.google.mlkit.vision.barcode.common.Barcode

/**
 * Maps between ScanKit format strings and ML Kit barcode format constants.
 *
 * Format string identifiers:
 * - 2D codes: "qr", "aztec", "dataMatrix", "pdf417"
 * - 1D product: "ean8", "ean13", "upca", "upce"
 * - 1D industrial: "code39", "code93", "code128", "codabar", "itf"
 */
object BarcodeFormatMapper {

    /**
     * Convert a format string to ML Kit format constant.
     * @param format The format string identifier
     * @return ML Kit format constant, or null if unknown
     */
    fun formatStringToMlKit(format: String): Int? {
        return when (format) {
            "qr" -> Barcode.FORMAT_QR_CODE
            "aztec" -> Barcode.FORMAT_AZTEC
            "dataMatrix" -> Barcode.FORMAT_DATA_MATRIX
            "pdf417" -> Barcode.FORMAT_PDF417
            "ean8" -> Barcode.FORMAT_EAN_8
            "ean13" -> Barcode.FORMAT_EAN_13
            "upca" -> Barcode.FORMAT_UPC_A
            "upce" -> Barcode.FORMAT_UPC_E
            "code39" -> Barcode.FORMAT_CODE_39
            "code93" -> Barcode.FORMAT_CODE_93
            "code128" -> Barcode.FORMAT_CODE_128
            "codabar" -> Barcode.FORMAT_CODABAR
            "itf" -> Barcode.FORMAT_ITF
            else -> null
        }
    }

    /**
     * Convert ML Kit format constant to format string.
     * @param format ML Kit format constant
     * @return Format string identifier
     */
    fun mlKitFormatToString(format: Int): String {
        return when (format) {
            Barcode.FORMAT_QR_CODE -> "qr"
            Barcode.FORMAT_AZTEC -> "aztec"
            Barcode.FORMAT_DATA_MATRIX -> "dataMatrix"
            Barcode.FORMAT_PDF417 -> "pdf417"
            Barcode.FORMAT_EAN_8 -> "ean8"
            Barcode.FORMAT_EAN_13 -> "ean13"
            Barcode.FORMAT_UPC_A -> "upca"
            Barcode.FORMAT_UPC_E -> "upce"
            Barcode.FORMAT_CODE_39 -> "code39"
            Barcode.FORMAT_CODE_93 -> "code93"
            Barcode.FORMAT_CODE_128 -> "code128"
            Barcode.FORMAT_CODABAR -> "codabar"
            Barcode.FORMAT_ITF -> "itf"
            else -> "unknown"
        }
    }

    /**
     * Convert a list of format strings to ML Kit format constants.
     * @param formats List of format string identifiers, or null for all formats
     * @return List of ML Kit format constants (empty if all formats should be used)
     */
    fun mapFormatsToMlKit(formats: List<String>?): List<Int> {
        if (formats.isNullOrEmpty()) return emptyList()
        return formats.mapNotNull { formatStringToMlKit(it) }
    }
}
