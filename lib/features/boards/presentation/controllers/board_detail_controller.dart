import 'package:client/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../database/database.dart';
import '../../data/column_repository.dart';
import '../../data/task_repository.dart';

final boardDetailProvider = Provider.family<BoardDetailController, String>((
  ref,
  boardId,
) {
  final db = ref.watch(databaseProvider);
  return BoardDetailController(
    ColumnRepository(db),
    TaskRepository(db),
    boardId,
  );
});

// Reactive stream for board columns
final boardColumnsProvider = StreamProvider.family<List<Column>, String>((
  ref,
  boardId,
) {
  return ref.watch(boardDetailProvider(boardId)).watchColumns();
});

// Reactive stream for tasks within a specific column
final columnTasksProvider = StreamProvider.family<List<Task>, String>((
  ref,
  columnId,
) {
  final db = ref.watch(databaseProvider);
  return TaskRepository(db).watchTasks(columnId);
});

class BoardDetailController {
  final ColumnRepository _colRepo;
  final TaskRepository _taskRepo;
  final String boardId;
  static const int spacing = 65536;

  BoardDetailController(this._colRepo, this._taskRepo, this.boardId);

  // --- Initialization & Streams ---
  Future<void> initializeBoard() async =>
      await _colRepo.ensureDefaultColumns(boardId);
  Stream<List<Column>> watchColumns() => _colRepo.watchColumns(boardId);
  Stream<List<Task>> watchTasks(String columnId) =>
      _taskRepo.watchTasks(columnId);

  // --- Task Operations ---
  Future<void> addNewTask(
    String columnId,
    String title,
    String priority,
  ) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _taskRepo.createTask(
      columnId: columnId,
      title: title,
      priority: priority,
      position: now,
    );
  }

  Future<void> handleTaskMove(
    String taskId,
    String toColId,
    List<Task> siblings,
    int toIdx,
  ) async {
    int newPos;
    if (siblings.isEmpty) {
      newPos = spacing;
    } else if (toIdx == 0) {
      newPos = siblings.first.position ~/ 2;
    } else if (toIdx >= siblings.length) {
      newPos = siblings.last.position + spacing;
    } else {
      final posAbove = siblings[toIdx - 1].position;
      final posBelow = siblings[toIdx].position;
      newPos = (posAbove + posBelow) ~/ 2;
    }

    await _taskRepo.moveTask(taskId, toColId, newPos);
  }

  Future<void> updateTaskDetails(
    String taskId,
    String title,
    String description,
    String priority,
    int? dueDate,
  ) async {
    await _taskRepo.updateTaskDetails(
      taskId: taskId,
      title: title,
      description: description,
      priority: priority,
      dueDate: dueDate,
    );
  }

  Future<void> deleteTask(String taskId) async {
    await _taskRepo.deleteTask(taskId);
  }

  // --- Column Operations ---
  Future<void> createColumn(String title) async {
    await _colRepo.createColumn(boardId, title);
  }

  Future<void> updateColumn(String columnId, String title) async {
    await _colRepo.updateColumn(columnId, title);
  }

  Future<void> deleteColumn(String columnId) async {
    await _colRepo.deleteColumn(columnId);
  }
}
