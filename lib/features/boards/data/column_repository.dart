import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';

class ColumnRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  ColumnRepository(this._db);

  static const int spacing = 65536; // 2^16 for Spaced Indexing [cite: 114]

  // --- 1. THE FIX: Filter out deleted columns from the UI stream ---
  Stream<List<Column>> watchColumns(String boardId) {
    return (_db.select(_db.columns)
          ..where(
            (t) => t.boardId.equals(boardId) & t.isDeleted.equals(false),
          ) // CRITICAL FILTER
          ..orderBy([(t) => drift.OrderingTerm.asc(t.position)]))
        .watch();
  }

  // --- 2. Default Column Creation ---
  Future<void> ensureDefaultColumns(String boardId) async {
    final existing =
        await (_db.select(_db.columns)..where(
              (t) => t.boardId.equals(boardId) & t.isDeleted.equals(false),
            ))
            .get();

    if (existing.isEmpty) {
      await _db.transaction(() async {
        final titles = ['To Do', 'In Progress', 'Done'];
        for (int i = 0; i < titles.length; i++) {
          final now = DateTime.now().toUtc().toIso8601String();
          final id = _uuid.v4();
          final pos = (i + 1) * spacing;

          await _db
              .into(_db.columns)
              .insert(
                ColumnsCompanion.insert(
                  id: id,
                  boardId: boardId,
                  title: titles[i],
                  position: pos,
                  updatedAt: now,
                  createdAt: now,
                ),
              );

          // Queue for Sync [cite: 61]
          await _db
              .into(_db.syncQueue)
              .insert(
                SyncQueueCompanion.insert(
                  queueId: _uuid.v4(),
                  entityId: id,
                  operationType: 'INSERT',
                  payload: jsonEncode({
                    'id': id,
                    'boardId': boardId,
                    'title': titles[i],
                    'position': pos,
                    'updatedAt': now,
                  }),
                  createdAt: now,
                ),
              );
        }
      });
    }
  }

  // --- 3. Create New Column ---
  Future<void> createColumn(String boardId, String title) async {
    final columnId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      final existing =
          await (_db.select(_db.columns)
                ..where((t) => t.boardId.equals(boardId))
                ..orderBy([(t) => drift.OrderingTerm.desc(t.position)]))
              .get();

      int newPosition = spacing;
      if (existing.isNotEmpty) {
        newPosition = existing.first.position + spacing;
      }

      await _db
          .into(_db.columns)
          .insert(
            ColumnsCompanion.insert(
              id: columnId,
              boardId: boardId,
              title: title,
              position: newPosition,
              updatedAt: now,
              createdAt: now,
            ),
          );

      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              queueId: _uuid.v4(),
              entityId: columnId,
              operationType: 'INSERT',
              payload: jsonEncode({
                'id': columnId,
                'boardId': boardId,
                'title': title,
                'position': newPosition,
                'updatedAt': now,
              }),
              createdAt: now,
            ),
          );
    });
  }

  // --- 4. Update Column (Rename) ---
  Future<void> updateColumn(String columnId, String newTitle) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction(() async {
      await (_db.update(
        _db.columns,
      )..where((t) => t.id.equals(columnId))).write(
        ColumnsCompanion(
          title: drift.Value(newTitle),
          updatedAt: drift.Value(now),
        ),
      );

      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              queueId: _uuid.v4(),
              entityId: columnId,
              operationType: 'UPDATE',
              payload: jsonEncode({
                'id': columnId,
                'title': newTitle,
                'updatedAt': now,
              }),
              createdAt: now,
            ),
          );
    });
  }

  // --- 5. Delete Column (Soft Delete) ---
  Future<void> deleteColumn(String columnId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction(() async {
      // Mark as deleted locally so the stream (updated above) hides it
      await (_db.update(
        _db.columns,
      )..where((t) => t.id.equals(columnId))).write(
        ColumnsCompanion(
          isDeleted: const drift.Value(true),
          updatedAt: drift.Value(now),
        ),
      );

      // Generate the delete operation for the backend
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              queueId: _uuid.v4(),
              entityId: columnId,
              operationType: 'DELETE',
              payload: jsonEncode({
                'id': columnId,
                'isDeleted': true,
                'updatedAt': now,
              }),
              createdAt: now,
            ),
          );
    });
  }
}
