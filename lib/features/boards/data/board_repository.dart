import 'dart:convert';
import 'package:client/database/database.dart';
import 'package:client/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final boardRepositoryProvider = Provider<BoardRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BoardRepository(db);
});

class BoardRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  BoardRepository(this._db);

  // --- Watch Boards (Reactive Stream for UI) ---
  /// Returns a stream of boards that are NOT deleted, sorted by newest first.
  /// The UI will listen to this stream and instantly update when the DB changes.
  Stream<List<Board>> watchBoards() {
    return (_db.select(_db.boards)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  // --- Create Board (Transactional Outbox Pattern) ---
  Future<void> createBoard(String title, String color, String ownerId) async {
    final boardId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    // We execute both inserts inside a single, unbreakable transaction
    await _db.transaction(() async {
      // 1. Create the Board locally
      final boardCompanion = BoardsCompanion.insert(
        id: boardId,
        title: title,
        color: drift.Value(color),
        isDeleted: const drift.Value(false),
        updatedAt: now,
        createdAt: now,
      );

      await _db.into(_db.boards).insert(boardCompanion);

      // 2. Add the operation to the Sync Queue
      final payload = {
        'id': boardId,
        'title': title,
        'color': color,
        'ownerId': ownerId,
        'updatedAt': now,
        'createdAt': now,
      };

      final queueCompanion = SyncQueueCompanion.insert(
        queueId: _uuid.v4(),
        entityId: boardId,
        operationType: 'INSERT',
        payload: jsonEncode(payload),
        createdAt: now,
      );

      await _db.into(_db.syncQueue).insert(queueCompanion);
    });
  }

  // --- Delete Board (Soft Delete + Outbox) ---
  Future<void> deleteBoard(String boardId) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      // 1. Soft delete the board locally
      await (_db.update(_db.boards)..where((t) => t.id.equals(boardId))).write(
        BoardsCompanion(
          isDeleted: const drift.Value(true),
          updatedAt: drift.Value(now),
        ),
      );

      // 2. Queue the delete operation for the server
      final payload = {'id': boardId, 'isDeleted': true, 'updatedAt': now};

      final queueCompanion = SyncQueueCompanion.insert(
        queueId: _uuid.v4(),
        entityId: boardId,
        operationType: 'DELETE',
        payload: jsonEncode(payload),
        createdAt: now,
      );

      await _db.into(_db.syncQueue).insert(queueCompanion);
    });
  }

  // --- Update Board ---
  Future<void> updateBoard(String boardId, String title, String color) async {
    final now = DateTime.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      // 1. Update Locally
      await (_db.update(_db.boards)..where((t) => t.id.equals(boardId))).write(
        BoardsCompanion(
          title: drift.Value(title),
          color: drift.Value(color),
          updatedAt: drift.Value(now),
        ),
      );

      // 2. Queue for Sync
      final payload = {
        'id': boardId,
        'title': title,
        'color': color,
        'updatedAt': now,
      };

      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              queueId: _uuid.v4(),
              entityId: boardId,
              operationType: 'UPDATE',
              payload: jsonEncode(payload),
              createdAt: now,
            ),
          );
    });
  }
}
