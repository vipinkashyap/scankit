import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scankit/scankit.dart';

import '../../data/database/database.dart';

/// Singleton database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Stream provider for scan history (reactive)
final scanHistoryProvider = StreamProvider<List<ScanRecord>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllScans();
});

/// Provider for scan count derived from history
final scanCountProvider = Provider<AsyncValue<int>>((ref) {
  final history = ref.watch(scanHistoryProvider);
  return history.whenData((records) => records.length);
});

/// Notifier for scan history mutations
final scanHistoryActionsProvider = Provider<ScanHistoryActions>((ref) {
  return ScanHistoryActions(ref);
});

class ScanHistoryActions {
  final Ref _ref;

  ScanHistoryActions(this._ref);

  Future<void> addScan(BarcodeResult result) async {
    final db = _ref.read(databaseProvider);
    await db.insertScan(ScanRecordsCompanion.insert(
      value: result.value,
      format: result.format.name,
      category: Value(_detectCategory(result.value)),
      scannedAt: DateTime.now(),
    ));
  }

  Future<void> toggleFavorite(ScanRecord record) async {
    final db = _ref.read(databaseProvider);
    await db.toggleFavorite(record);
  }

  Future<void> deleteScan(ScanRecord record) async {
    final db = _ref.read(databaseProvider);
    await db.deleteScan(record.id);
  }

  Future<void> clearHistory() async {
    final db = _ref.read(databaseProvider);
    await db.deleteAllScans();
  }

  String? _detectCategory(String value) {
    if (value.startsWith('WIFI:')) return 'wifi';
    if (value.startsWith('http://') || value.startsWith('https://')) return 'url';
    if (value.startsWith('BEGIN:VCARD')) return 'contact';
    if (value.startsWith('tel:') || RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(value)) return 'phone';
    if (value.startsWith('mailto:') || value.contains('@')) return 'email';
    if (RegExp(r'^\d{8,14}$').hasMatch(value)) return 'product';
    return null;
  }
}
