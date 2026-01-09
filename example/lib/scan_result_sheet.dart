import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';
import 'package:url_launcher/url_launcher.dart';

class ScanResultSheet extends StatelessWidget {
  final BarcodeResult result;

  const ScanResultSheet({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final category = _detectCategory(result.value);
    final (icon, color, label) = _getCategoryInfo(category);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      result.format.name.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              result.value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _performAction(context, category),
                  icon: Icon(_getActionIcon(category)),
                  label: Text(_getActionLabel(category)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _detectCategory(String value) {
    if (value.startsWith('WIFI:')) return 'wifi';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return 'url';
    }
    if (value.startsWith('BEGIN:VCARD')) return 'contact';
    if (value.startsWith('tel:')) return 'phone';
    if (value.startsWith('mailto:')) return 'email';
    if (RegExp(r'^\d{8,14}$').hasMatch(value)) return 'product';
    return 'text';
  }

  (IconData, Color, String) _getCategoryInfo(String category) {
    return switch (category) {
      'wifi' => (Icons.wifi, Colors.teal, 'WiFi Network'),
      'url' => (Icons.link, Colors.blue, 'URL'),
      'contact' => (Icons.person, Colors.green, 'Contact'),
      'phone' => (Icons.phone, Colors.purple, 'Phone Number'),
      'email' => (Icons.email, Colors.red, 'Email'),
      'product' => (Icons.shopping_bag, Colors.orange, 'Product'),
      _ => (Icons.qr_code, Colors.grey, 'Text'),
    };
  }

  IconData _getActionIcon(String category) {
    return switch (category) {
      'url' => Icons.open_in_new,
      'phone' => Icons.call,
      'email' => Icons.send,
      'wifi' => Icons.settings,
      _ => Icons.share,
    };
  }

  String _getActionLabel(String category) {
    return switch (category) {
      'url' => 'Open',
      'phone' => 'Call',
      'email' => 'Send Email',
      'wifi' => 'Connect',
      _ => 'Share',
    };
  }

  Future<void> _performAction(BuildContext context, String category) async {
    Navigator.pop(context);

    Uri? uri;
    switch (category) {
      case 'url':
        uri = Uri.tryParse(result.value);
      case 'phone':
        final phone = result.value.startsWith('tel:')
            ? result.value
            : 'tel:${result.value}';
        uri = Uri.tryParse(phone);
      case 'email':
        final email = result.value.startsWith('mailto:')
            ? result.value
            : 'mailto:${result.value}';
        uri = Uri.tryParse(email);
      default:
        // Share for other types
        Clipboard.setData(ClipboardData(text: result.value));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
        }
        return;
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
