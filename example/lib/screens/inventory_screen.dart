import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scankit/scankit.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import '../core/providers/providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _controller = ScanKitController();
  final Map<String, InventoryItem> _items = {};
  String? _lastScanned;
  bool _torchEnabled = false;

  int get _totalItems => _items.values.fold(0, (sum, item) => sum + item.quantity);
  int get _uniqueItems => _items.length;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeResult result) {
    final code = result.value;
    final settings = ref.read(settingsProvider);

    setState(() {
      _lastScanned = code;
      if (_items.containsKey(code)) {
        _items[code]!.quantity++;
      } else {
        _items[code] = InventoryItem(
          barcode: code,
          format: result.format,
          quantity: 1,
          firstScanned: DateTime.now(),
        );
      }
    });

    if (settings.hapticFeedback) {
      HapticFeedback.lightImpact();
    }
  }

  void _adjustQuantity(String code, int delta) {
    setState(() {
      final item = _items[code];
      if (item != null) {
        item.quantity += delta;
        if (item.quantity <= 0) {
          _items.remove(code);
        }
      }
    });
  }

  void _exportList() {
    final csv = _items.values
        .map((item) => '${item.barcode},${item.quantity},${item.format.name}')
        .join('\n');
    final header = 'Barcode,Quantity,Format\n';

    SharePlus.instance.share(ShareParams(text: header + csv, subject: 'Inventory Export'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.setTorch(!_torchEnabled);
              setState(() => _torchEnabled = !_torchEnabled);
            },
          ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: _exportList,
              tooltip: 'Export',
            ),
        ],
      ),
      body: Column(
        children: [
          // Scanner
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                ScanKitView(
                  controller: _controller,
                  onDetect: _handleScan,
                  overlay: const ScanKitAnimatedOverlay(
                    scanAreaSize: 0.8,
                    cornerLength: 20,
                    borderWidth: 2,
                  ),
                ),
                if (_lastScanned != null)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _lastScanned!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                _buildStat('Items', _totalItems.toString()),
                const SizedBox(width: 24),
                _buildStat('Unique', _uniqueItems.toString()),
                const Spacer(),
                if (_items.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear All?'),
                          content: Text('Remove all $_totalItems items?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => _items.clear());
                                Navigator.pop(context);
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),

          // Item list
          Expanded(
            child: _items.isEmpty ? _buildEmptyState() : _buildItemList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Start scanning items',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Scanned barcodes will appear here',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    final items = _items.values.toList()
      ..sort((a, b) => b.firstScanned.compareTo(a.firstScanned));

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: Key(item.barcode),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => setState(() => _items.remove(item.barcode)),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  item.quantity.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            title: Text(item.barcode, style: const TextStyle(fontFamily: 'monospace')),
            subtitle: Text(item.format.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _adjustQuantity(item.barcode, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _adjustQuantity(item.barcode, 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class InventoryItem {
  final String barcode;
  final BarcodeFormat format;
  int quantity;
  final DateTime firstScanned;

  InventoryItem({
    required this.barcode,
    required this.format,
    required this.quantity,
    required this.firstScanned,
  });
}
