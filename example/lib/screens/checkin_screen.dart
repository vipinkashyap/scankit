import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scankit/scankit.dart';

import '../core/providers/providers.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _controller = ScanKitController();
  final List<CheckinResult> _history = [];
  CheckinResult? _lastResult;
  bool _isProcessing = false;

  // Demo valid tickets
  final _validTickets = {'TICKET-001', 'TICKET-002', 'TICKET-003', 'VIP-100', 'VIP-101'};
  final _checkedIn = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeResult result) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final settings = ref.read(settingsProvider);
    await Future.delayed(const Duration(milliseconds: 300));

    final ticketId = result.value.trim().toUpperCase();
    CheckinResult checkinResult;

    if (_checkedIn.contains(ticketId)) {
      checkinResult = CheckinResult(
        ticketId: ticketId,
        status: CheckinStatus.duplicate,
        message: 'Already checked in',
        timestamp: DateTime.now(),
      );
      if (settings.hapticFeedback) HapticFeedback.heavyImpact();
    } else if (_validTickets.contains(ticketId)) {
      _checkedIn.add(ticketId);
      checkinResult = CheckinResult(
        ticketId: ticketId,
        status: CheckinStatus.success,
        message: ticketId.startsWith('VIP') ? 'VIP Guest' : 'General Admission',
        timestamp: DateTime.now(),
      );
      if (settings.hapticFeedback) HapticFeedback.mediumImpact();
    } else {
      checkinResult = CheckinResult(
        ticketId: ticketId,
        status: CheckinStatus.invalid,
        message: 'Ticket not found',
        timestamp: DateTime.now(),
      );
      if (settings.hapticFeedback) HapticFeedback.heavyImpact();
    }

    setState(() {
      _lastResult = checkinResult;
      _history.insert(0, checkinResult);
      _isProcessing = false;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _lastResult == checkinResult) {
        setState(() => _lastResult = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Check-in'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_checkedIn.length} checked in',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                ScanKitView(
                  controller: _controller,
                  formats: const [BarcodeFormat.qr],
                  onDetect: _handleScan,
                  overlay: const ScanKitOverlay(),
                ),
                if (_lastResult != null) _buildStatusOverlay(),
                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: _history.isEmpty ? _buildEmptyState() : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay() {
    final result = _lastResult!;
    final color = switch (result.status) {
      CheckinStatus.success => Colors.green,
      CheckinStatus.duplicate => Colors.orange,
      CheckinStatus.invalid => Colors.red,
    };
    final icon = switch (result.status) {
      CheckinStatus.success => Icons.check_circle,
      CheckinStatus.duplicate => Icons.warning,
      CheckinStatus.invalid => Icons.cancel,
    };

    return Positioned.fill(
      child: Container(
        color: color.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 80, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                result.status == CheckinStatus.success
                    ? 'Welcome!'
                    : result.status == CheckinStatus.duplicate
                        ? 'Already Scanned'
                        : 'Invalid Ticket',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.message,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Scan tickets to check in guests',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Demo tickets: TICKET-001, VIP-100',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text('Recent Scans', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _history.clear();
                    _checkedIn.clear();
                  });
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final result = _history[index];
              final color = switch (result.status) {
                CheckinStatus.success => Colors.green,
                CheckinStatus.duplicate => Colors.orange,
                CheckinStatus.invalid => Colors.red,
              };
              final icon = switch (result.status) {
                CheckinStatus.success => Icons.check_circle,
                CheckinStatus.duplicate => Icons.warning,
                CheckinStatus.invalid => Icons.cancel,
              };

              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(result.ticketId, style: const TextStyle(fontFamily: 'monospace')),
                subtitle: Text(result.message),
                trailing: Text(
                  '${result.timestamp.hour.toString().padLeft(2, '0')}:'
                  '${result.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum CheckinStatus { success, duplicate, invalid }

class CheckinResult {
  final String ticketId;
  final CheckinStatus status;
  final String message;
  final DateTime timestamp;

  CheckinResult({
    required this.ticketId,
    required this.status,
    required this.message,
    required this.timestamp,
  });
}
