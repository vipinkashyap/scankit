import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class ScanRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get value => text()();
  TextColumn get format => text()();
  TextColumn get category => text().nullable()();
  DateTimeColumn get scannedAt => dateTime()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [ScanRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Scan Records CRUD
  Future<List<ScanRecord>> getAllScans() => select(scanRecords).get();

  Stream<List<ScanRecord>> watchAllScans() {
    return (select(scanRecords)..orderBy([(t) => OrderingTerm.desc(t.scannedAt)])).watch();
  }

  Future<int> insertScan(ScanRecordsCompanion scan) =>
      into(scanRecords).insert(scan);

  Future<void> updateScan(ScanRecord record) =>
      update(scanRecords).replace(record);

  Future<int> deleteScan(int id) =>
      (delete(scanRecords)..where((t) => t.id.equals(id))).go();

  Future<int> deleteAllScans() => delete(scanRecords).go();

  Future<void> toggleFavorite(ScanRecord record) {
    return (update(scanRecords)..where((t) => t.id.equals(record.id)))
        .write(ScanRecordsCompanion(isFavorite: Value(!record.isFavorite)));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'scankit_example.db'));
    return NativeDatabase.createInBackground(file);
  });
}
