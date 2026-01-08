/// Exception types for ScanKit errors
///
/// Provides typed exceptions for different error scenarios:
/// - [CameraPermissionDeniedException] - User denied camera access
/// - [CameraPermissionRestrictedException] - Camera restricted by policy
/// - [ScannerNotSupportedException] - Device doesn't support scanning
/// - [ScanFailedException] - Barcode scan failed
/// - [DocumentScanFailedException] - Document scan failed
/// - [TorchException] - Torch/flash operation failed
/// - [ImageProcessingException] - Failed to process image file
/// - [ScannerException] - General scanner error
library;

import 'package:flutter/services.dart';

/// Base exception for all ScanKit errors
///
/// Use pattern matching on the sealed class to handle specific error types:
/// ```dart
/// try {
///   await ScanKit.scan();
/// } on CameraPermissionDeniedException {
///   // Request permission
/// } on ScanKitException catch (e) {
///   // Handle other errors
/// }
/// ```
sealed class ScanKitException implements Exception {
  const ScanKitException(this.message, [this.details]);

  final String message;
  final Object? details;

  /// Creates appropriate exception from platform error code
  factory ScanKitException.fromPlatformException(PlatformException e) {
    return switch (e.code) {
      'camera_permission_denied' => CameraPermissionDeniedException(e.message ?? 'Camera permission denied'),
      'camera_permission_restricted' => CameraPermissionRestrictedException(e.message ?? 'Camera access restricted'),
      'NO_ACTIVITY' || 'NO_VIEW_CONTROLLER' => ScannerUnavailableException(e.message ?? 'Scanner UI unavailable'),
      'NO_CONTEXT' => ScannerUnavailableException(e.message ?? 'Context unavailable'),
      'NOT_SUPPORTED' => ScannerNotSupportedException(e.message ?? 'Scanner not supported on this device'),
      'TORCH_ERROR' => TorchException(e.message ?? 'Torch operation failed'),
      'SCAN_ERROR' => ScanFailedException(e.message ?? 'Scan failed'),
      'DOCUMENT_SCAN_ERROR' => DocumentScanFailedException(e.message ?? 'Document scan failed'),
      'SCANNER_ERROR' => ScannerException(e.message ?? 'Scanner error'),
      'IMAGE_ERROR' => ImageProcessingException(e.message ?? 'Failed to process image'),
      'channel-error' => ScannerUnavailableException(e.message ?? 'Platform channel error'),
      _ => ScannerException(e.message ?? 'Unknown error', e.details),
    };
  }

  @override
  String toString() => 'ScanKitException: $message';
}

/// Camera permission was denied by user
class CameraPermissionDeniedException extends ScanKitException {
  const CameraPermissionDeniedException([super.message = 'Camera permission denied']);

  @override
  String toString() => 'CameraPermissionDeniedException: $message';
}

/// Camera access is restricted (parental controls, MDM, etc.)
class CameraPermissionRestrictedException extends ScanKitException {
  const CameraPermissionRestrictedException([super.message = 'Camera access restricted']);

  @override
  String toString() => 'CameraPermissionRestrictedException: $message';
}

/// Scanner UI could not be presented
class ScannerUnavailableException extends ScanKitException {
  const ScannerUnavailableException([super.message = 'Scanner unavailable']);

  @override
  String toString() => 'ScannerUnavailableException: $message';
}

/// Device doesn't support barcode scanning
class ScannerNotSupportedException extends ScanKitException {
  const ScannerNotSupportedException([super.message = 'Scanner not supported']);

  @override
  String toString() => 'ScannerNotSupportedException: $message';
}

/// Torch/flash operation failed
class TorchException extends ScanKitException {
  const TorchException([super.message = 'Torch operation failed']);

  @override
  String toString() => 'TorchException: $message';
}

/// Barcode scanning failed
class ScanFailedException extends ScanKitException {
  const ScanFailedException([super.message = 'Scan failed']);

  @override
  String toString() => 'ScanFailedException: $message';
}

/// Document scanning failed
class DocumentScanFailedException extends ScanKitException {
  const DocumentScanFailedException([super.message = 'Document scan failed']);

  @override
  String toString() => 'DocumentScanFailedException: $message';
}

/// Image processing failed (gallery/file scan)
class ImageProcessingException extends ScanKitException {
  const ImageProcessingException([super.message = 'Image processing failed']);

  @override
  String toString() => 'ImageProcessingException: $message';
}

/// General scanner error
class ScannerException extends ScanKitException {
  const ScannerException([super.message = 'Scanner error', super.details]);

  @override
  String toString() => 'ScannerException: $message';
}
