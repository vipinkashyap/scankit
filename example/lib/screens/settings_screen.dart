import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Scanning section
          _SectionHeader('Scanning'),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibrate when barcode detected'),
            value: settings.hapticFeedback,
            onChanged: notifier.setHapticFeedback,
          ),
          SwitchListTile(
            title: const Text('Save to History'),
            subtitle: const Text('Automatically save scanned codes'),
            value: settings.saveToHistory,
            onChanged: notifier.setSaveToHistory,
          ),
          SwitchListTile(
            title: const Text('Auto-open URLs'),
            subtitle: const Text('Open links automatically when scanned'),
            value: settings.autoOpenUrls,
            onChanged: notifier.setAutoOpenUrls,
          ),

          // Appearance section
          _SectionHeader('Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_themeName(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(context, ref),
          ),
          ListTile(
            title: const Text('Scanner Overlay'),
            subtitle: Text(_overlayName(settings.defaultOverlay)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showOverlayPicker(context, ref),
          ),

          // About section
          _SectionHeader('About'),
          ListTile(
            title: const Text('ScanKit'),
            subtitle: const Text('Barcode & QR code scanner for Flutter'),
            trailing: const Text('v0.1.1'),
          ),
          ListTile(
            title: const Text('GitHub'),
            subtitle: const Text('github.com/vipinkashyap/scankit'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Open GitHub
            },
          ),
        ],
      ),
    );
  }

  String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'System',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  String _overlayName(String overlay) => switch (overlay) {
        'standard' => 'Standard',
        'animated' => 'Animated',
        'glass' => 'Frosted Glass',
        _ => 'Standard',
      };

  void _showThemePicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Theme'),
        children: [
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              title: Text(_themeName(mode)),
              value: mode,
              groupValue: settings.themeMode,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setThemeMode(value!);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void _showOverlayPicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Scanner Overlay'),
        children: [
          for (final overlay in ['standard', 'animated', 'glass'])
            RadioListTile<String>(
              title: Text(_overlayName(overlay)),
              value: overlay,
              groupValue: settings.defaultOverlay,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setDefaultOverlay(value!);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
