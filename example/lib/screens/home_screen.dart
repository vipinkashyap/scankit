import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/providers.dart';
import '../core/router/app_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanCount = ref.watch(scanCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScanKit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.history),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Scans',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        scanCount.when(
                          data: (count) => Text(
                            count.toString(),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          loading: () => const Text('...'),
                          error: (_, _) => const Text('0'),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => context.push(AppRoutes.scanner),
                    child: const Text('Scan'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Quick scan
          _ActionCard(
            icon: Icons.qr_code_scanner,
            title: 'Quick Scan',
            subtitle: 'Scan any barcode or QR code',
            color: Colors.blue,
            onTap: () => context.push(AppRoutes.scanner),
          ),

          const SizedBox(height: 24),
          Text(
            'Use Cases',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Domain-specific scanners
          _ActionCard(
            icon: Icons.wifi,
            title: 'WiFi Connect',
            subtitle: 'Scan WiFi QR codes to get credentials',
            color: Colors.teal,
            onTap: () => context.push(AppRoutes.wifiScanner),
          ),
          _ActionCard(
            icon: Icons.event_available,
            title: 'Event Check-in',
            subtitle: 'Scan tickets and badges',
            color: Colors.orange,
            onTap: () => context.push(AppRoutes.checkin),
          ),
          _ActionCard(
            icon: Icons.inventory_2,
            title: 'Inventory',
            subtitle: 'Batch scanning with quantities',
            color: Colors.purple,
            onTap: () => context.push(AppRoutes.inventory),
          ),

          const SizedBox(height: 24),
          Text(
            'Code Examples',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          // Code examples grid
          _ExampleGrid(),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExampleGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final examples = [
      ('One-Shot', Icons.flash_on, AppRoutes.simpleOneShot),
      ('QR Only', Icons.qr_code, AppRoutes.qrOnly),
      ('Products', Icons.shopping_cart, AppRoutes.productBarcode),
      ('Embedded', Icons.crop_free, AppRoutes.basicEmbedded),
      ('Styled', Icons.palette, AppRoutes.styledOverlay),
      ('Glass', Icons.blur_on, AppRoutes.liquidGlass),
      ('Continuous', Icons.repeat, AppRoutes.continuous),
      ('Custom UI', Icons.dashboard_customize, AppRoutes.customUI),
      ('Gallery', Icons.photo_library, AppRoutes.gallery),
      ('Document', Icons.document_scanner, AppRoutes.document),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: examples.map((e) {
        final (title, icon, route) = e;
        return ActionChip(
          avatar: Icon(icon, size: 18),
          label: Text(title),
          onPressed: () => context.push(route),
        );
      }).toList(),
    );
  }
}
