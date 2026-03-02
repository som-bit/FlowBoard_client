import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../database/database.dart';

class TaskRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  TaskRepository(this._db);

  Stream<List<Task>> watchTasks(String columnId) {
    return (_db.select(_db.tasks)
          ..where(
            (t) => t.columnId.equals(columnId) & t.isDeleted.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<void> moveTask(
    String taskId,
    String newColumnId,
    int newPosition,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          columnId: Value(newColumnId),
          position: Value(newPosition),
          updatedAt: Value(now),
        ),
      );

      final payload = {
        'id': taskId,
        'columnId': newColumnId,
        'position': newPosition,
        'updatedAt': now,
      };
      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              queueId: _uuid.v4(),
              entityId: taskId,
              operationType: 'UPDATE',
              payload: jsonEncode(payload),
              createdAt: now,
            ),
          );
    });
  }

  Future<void> createTask({
    required String columnId,
    required String title,
    String? description,
    required String priority,
    required int position,
  }) async {
    final taskId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await _db.transaction(() async {
      // 1. Create the Task locally [cite: 104]
      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              id: taskId,
              columnId: columnId,
              title: title,
              description: Value(description ?? ''),
              status: 'To Do', // Derived from initial column [cite: 88]
              priority: priority,
              position: position,
              updatedAt: now,
              createdAt: now,
            ),
          );

      // 2. Queue for server sync [cite: 109, 149]
      final payload = {
        'id': taskId,
        'columnId': columnId,
        'title': title,
        'description': description,
        'priority': priority,
        'position': position,
        'updatedAt': now,
      };

      await _db
          .into(_db.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              queueId: _uuid.v4(),
              entityId: taskId,
              operationType: 'INSERT',
              payload: jsonEncode(payload),
              createdAt: now,
            ),
          );
    });
  }

Future<void> updateTaskDetails({
    required String taskId,
    required String title,
    required String description,
    required String priority,
    int? dueDate,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    
    await _db.transaction(() async {
      // 1. Update Locally
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          title: Value(title),
          description: Value(description),
          priority: Value(priority),
          dueDate: Value(dueDate),
          updatedAt: Value(now),
        ),
      );

      // 2. Queue for Sync
      final payload = {
        'id': taskId,
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate,
        'updatedAt': now,
      };
      
      await _db.into(_db.syncQueue).insert(
        SyncQueueCompanion.insert(
          queueId: _uuid.v4(),
          entityId: taskId,
          operationType: 'UPDATE',
          payload: jsonEncode(payload),
          createdAt: now,
        ),
      );
    });
  }

  // Also add the deleteTask method if you haven't already!
  Future<void> deleteTask(String taskId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(isDeleted: const drift.Value(true), updatedAt: drift.Value(now)),
      );

      final payload = {'id': taskId, 'isDeleted': true, 'updatedAt': now};
      await _db.into(_db.syncQueue).insert(
        SyncQueueCompanion.insert(
          queueId: _uuid.v4(),
          entityId: taskId,
          operationType: 'DELETE',
          payload: jsonEncode(payload),
          createdAt: now,
        ),
      );
    });
  }


}
