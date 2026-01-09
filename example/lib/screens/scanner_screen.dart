import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scankit/scankit.dart';

import '../core/providers/providers.dart';
import '../scan_result_sheet.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _controller = ScanKitController();
  bool _torchEnabled = false;
  bool _isFrontCamera = false;
  bool _isSheetOpen = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeResult result) async {
    // Prevent multiple sheets stacking
    if (_isSheetOpen) return;

    final settings = ref.read(settingsProvider);

    if (settings.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    if (settings.saveToHistory) {
      await ref.read(scanHistoryActionsProvider).addScan(result);
    }

    if (mounted) {
      _showResultSheet(result);
    }
  }

  void _showResultSheet(BarcodeResult result) {
    _isSheetOpen = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => ScanResultSheet(result: result),
    ).whenComplete(() {
      _isSheetOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scanner'),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? Colors.amber : Colors.white,
            ),
            onPressed: () async {
              await _controller.setTorch(!_torchEnabled);
              setState(() => _torchEnabled = !_torchEnabled);
            },
          ),
          IconButton(
            icon: Icon(
              _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
            ),
            onPressed: () async {
              await _controller.switchCamera();
              setState(() => _isFrontCamera = !_isFrontCamera);
            },
          ),
        ],
      ),
      body: ScanKitView(
        controller: _controller,
        onDetect: _handleScan,
        overlay: _buildOverlay(settings.defaultOverlay),
      ),
    );
  }

  Widget _buildOverlay(String overlayType) {
    return switch (overlayType) {
      'animated' => const ScanKitAnimatedOverlay(),
      'glass' => const LiquidGlassOverlay(),
      _ => const ScanKitOverlay(),
    };
  }
}
