import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// --- TABLE DEFINITIONS ---
class Boards extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get color => text().withDefault(const Constant('#3B82F6'))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text()(); // Changed from integer()
  TextColumn get createdAt => text()(); // Changed from integer()

  @override
  get primaryKey => {id};
}

class Columns extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text().references(Boards, #id)();
  TextColumn get title => text()();
  IntColumn get position => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text()(); // Changed from integer()
  TextColumn get createdAt => text()(); // Changed from integer()

  @override
  get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get columnId => text().references(Columns, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  TextColumn get priority => text()();
  IntColumn get dueDate => integer().nullable()();
  TextColumn get assigneeId => text().nullable()();
  IntColumn get position => integer()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text()(); // Changed from integer()
  TextColumn get createdAt => text()(); // Changed from integer()

  @override
  get primaryKey => {id};
}

class SyncQueue extends Table {
  TextColumn get queueId => text()();
  TextColumn get entityId => text()();
  TextColumn get operationType => text()();
  TextColumn get payload => text()();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()(); // Changed from integer()
  @override
  get primaryKey => {queueId};
}

// --- DATABASE CONNECTION & CONFIGURATION ---

@DriftDatabase(tables: [Boards, Columns, Tasks, SyncQueue])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}

// Exactly like your Vitality Sync app!
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'flowboard.sqlite'));

    // Fallback to the highly stable system SQLite
    return NativeDatabase.createInBackground(file);
  });
}
