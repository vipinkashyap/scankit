import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scankit/scankit.dart';

import '../core/providers/providers.dart';

class WifiScannerScreen extends ConsumerStatefulWidget {
  const WifiScannerScreen({super.key});

  @override
  ConsumerState<WifiScannerScreen> createState() => _WifiScannerScreenState();
}

class _WifiScannerScreenState extends ConsumerState<WifiScannerScreen> {
  final _controller = ScanKitController();
  WifiCredentials? _credentials;
  bool _torchEnabled = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleScan(BarcodeResult result) {
    final credentials = WifiCredentials.parse(result.value);
    if (credentials != null) {
      final settings = ref.read(settingsProvider);
      if (settings.hapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      if (settings.saveToHistory) {
        ref.read(scanHistoryActionsProvider).addScan(result);
      }
      setState(() => _credentials = credentials);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Scanner'),
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.setTorch(!_torchEnabled);
              setState(() => _torchEnabled = !_torchEnabled);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: ScanKitView(
              controller: _controller,
              formats: const [BarcodeFormat.qr],
              onDetect: _handleScan,
              overlay: const LiquidGlassOverlay(),
            ),
          ),
          Expanded(
            flex: 4,
            child: _credentials == null
                ? _buildInstructions()
                : _buildCredentialsCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_find,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Scan a WiFi QR Code',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Point your camera at a WiFi QR code to get the network credentials.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsCard() {
    final creds = _credentials!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.wifi,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      creds.ssid,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _buildSecurityBadge(creds.security),
                ],
              ),
              const Divider(height: 32),
              if (creds.password != null) ...[
                Text(
                  'Password',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _passwordVisible ? creds.password! : '••••••••',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _passwordVisible = !_passwordVisible);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: creds.password!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password copied')),
                        );
                      },
                    ),
                  ],
                ),
              ] else
                Text(
                  'Open network (no password)',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _credentials = null;
                          _passwordVisible = false;
                        });
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Another'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityBadge(String security) {
    final color = security == 'nopass'
        ? Colors.orange
        : security == 'WPA' || security == 'WPA2'
            ? Colors.green
            : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        security == 'nopass' ? 'OPEN' : security,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class WifiCredentials {
  final String ssid;
  final String? password;
  final String security;
  final bool hidden;

  WifiCredentials({
    required this.ssid,
    this.password,
    required this.security,
    this.hidden = false,
  });

  static WifiCredentials? parse(String data) {
    if (!data.startsWith('WIFI:')) return null;

    final content = data.substring(5);
    String? ssid;
    String? password;
    String security = 'nopass';
    bool hidden = false;

    final parts = content.split(';');
    for (final part in parts) {
      if (part.isEmpty) continue;
      final colonIndex = part.indexOf(':');
      if (colonIndex == -1) continue;

      final key = part.substring(0, colonIndex);
      final value = part.substring(colonIndex + 1);

      switch (key) {
        case 'S':
          ssid = _unescape(value);
        case 'P':
          password = _unescape(value);
        case 'T':
          security = value.toUpperCase();
        case 'H':
          hidden = value.toLowerCase() == 'true';
      }
    }

    if (ssid == null || ssid.isEmpty) return null;

    return WifiCredentials(
      ssid: ssid,
      password: password,
      security: security,
      hidden: hidden,
    );
  }

  static String _unescape(String value) {
    return value
        .replaceAll(r'\;', ';')
        .replaceAll(r'\:', ':')
        .replaceAll(r'\\', r'\');
  }
}
