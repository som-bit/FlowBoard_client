import 'package:appflowy_board/appflowy_board.dart';
import 'package:client/features/boards/presentation/screens/board_activity_screen.dart';
import 'package:client/features/boards/presentation/widget/kanban_card.dart';
import 'package:client/features/boards/presentation/widget/task_edit_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/database.dart' as db;
import '../controllers/board_detail_controller.dart';

class BoardDetailScreen extends ConsumerStatefulWidget {
  final String boardId;
  const BoardDetailScreen({super.key, required this.boardId});

  @override
  ConsumerState<BoardDetailScreen> createState() => _BoardDetailScreenState();
}

class _BoardDetailScreenState extends ConsumerState<BoardDetailScreen> {
  late AppFlowyBoardController boardController;

  @override
  void initState() {
    super.initState();
    boardController = AppFlowyBoardController(
      onMoveGroupItemToGroup: (fromGroupId, fromIdx, toGroupId, toIdx) {
        final groupController = boardController.getGroupController(toGroupId)!;
        final movedItem = groupController.items[toIdx] as TaskItem;
        final siblings = groupController.items
            .cast<TaskItem>()
            .map((e) => e.task)
            .toList();

        ref
            .read(boardDetailProvider(widget.boardId))
            .handleTaskMove(movedItem.task.id, toGroupId, siblings, toIdx);
      },
    );

    Future.microtask(() {
      ref.read(boardDetailProvider(widget.boardId)).initializeBoard();
    });
  }

  @override
  void dispose() {
    boardController.dispose();
    super.dispose();
  }

  void _syncTasks(String columnId, List<db.Task>? tasks) {
    if (tasks == null) return;

    final newItems = tasks.map((t) => TaskItem(t)).toList();
    final groupCtrl = boardController.getGroupController(columnId);

    if (groupCtrl != null) {
      final existingIds = groupCtrl.items.map((e) => e.id).toSet();
      final newIds = newItems.map((e) => e.id).toSet();

      final idsToRemove = existingIds.difference(newIds).toList();
      for (final id in idsToRemove) {
        final index = groupCtrl.items.indexWhere((e) => e.id == id);
        if (index != -1) groupCtrl.removeAt(index);
      }

      for (final newItem in newItems) {
        if (!existingIds.contains(newItem.id)) {
          groupCtrl.replaceOrInsertItem(newItem);
        } else {
          final existingItem =
              groupCtrl.items.firstWhere((e) => e.id == newItem.id) as TaskItem;
          final oldTask = existingItem.task;
          final newTask = newItem.task;

          if (oldTask.title != newTask.title ||
              oldTask.priority != newTask.priority ||
              oldTask.description != newTask.description ||
              oldTask.dueDate != newTask.dueDate) {
            groupCtrl.replaceOrInsertItem(newItem);
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final columnsAsync = ref.watch(boardColumnsProvider(widget.boardId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          "Board Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.grey),
            tooltip: "Board Activity",
            onPressed: () {
              // Navigate to the new Activity Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BoardActivityScreen(boardId: widget.boardId),
                ),
              );
            },
          ),
          Container(
            margin: EdgeInsets.only(right: 16.w),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF3B82F6)),
              tooltip: "Add Column",
              onPressed: () => _showColumnDialog(context, isEditing: false),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: columnsAsync.when(
          data: (columns) {
            final existingGroupIds = boardController.groupDatas
                .map((g) => g.id)
                .toSet();
            final incomingGroupIds = columns.map((c) => c.id).toSet();

            for (final id in existingGroupIds.difference(incomingGroupIds)) {
              boardController.removeGroup(id);
            }

            for (var col in columns) {
              if (!existingGroupIds.contains(col.id)) {
                boardController.addGroup(
                  AppFlowyGroupData<TaskItem>(
                    id: col.id,
                    items: [],
                    name: col.title,
                  ),
                );
              }
            }

            for (var col in columns) {
              ref.listen(columnTasksProvider(col.id), (prev, next) {
                _syncTasks(col.id, next.value);
              });
              final currentTasks = ref.read(columnTasksProvider(col.id));
              if (currentTasks.hasValue) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _syncTasks(col.id, currentTasks.value);
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: AppFlowyBoard(
                controller: boardController,
                // --- NEW: PREMIUM COLUMN STYLING ---
                config: AppFlowyBoardConfig(
                  groupBackgroundColor: const Color(
                    0xFF1E293B,
                  ).withOpacity(0.5), // Semi-transparent lane
                  stretchGroupHeight: false,
                  // groupPadding: EdgeInsets.symmetric(horizontal: 12.w),
                  groupMargin: EdgeInsets.symmetric(horizontal: 8.w),
                  // cornerRadius: 16.r,
                ),
                cardBuilder: (context, group, item) {
                  final taskItem = item as TaskItem;
                  return GestureDetector(
                    key: ValueKey(item.id),
                    onTap: () => _showTaskEditModal(context, taskItem.task),
                    child: KanbanCard(task: taskItem.task),
                  );
                },
                headerBuilder: (context, group) => _buildHeader(group, columns),
                footerBuilder: (context, group) => _buildFooter(context, group),
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
          ),
          error: (err, _) => Center(
            child: Text(
              "Error: $err",
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppFlowyGroupData group, List<db.Column> columns) {
    final matchingColumns = columns.where((c) => c.id == group.id);
    final title = matchingColumns.isNotEmpty
        ? matchingColumns.first.title
        : group.headerData.groupName;

    return InkWell(
      onTap: () => _showColumnDialog(
        context,
        isEditing: true,
        columnId: group.id,
        currentTitle: title,
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.h,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const Icon(Icons.more_horiz, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, AppFlowyGroupData group) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 16.h),
      child: InkWell(
        onTap: () => _showAddTaskDialog(context, group.id),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.5),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Colors.grey.shade400, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                "Add Task",
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UPGRADED DIALOGS (Rounded, styled matching spec) ---
  void _showAddTaskDialog(BuildContext context, String columnId) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text("New Task", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "What needs to be done?",
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                ref
                    .read(boardDetailProvider(widget.boardId))
                    .addNewTask(
                      columnId,
                      titleController.text.trim(),
                      'Medium',
                    );
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Add Task",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColumnDialog(
    BuildContext context, {
    required bool isEditing,
    String? columnId,
    String? currentTitle,
  }) {
    final titleController = TextEditingController(text: currentTitle ?? "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          isEditing ? "Edit Column" : "New Column",
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Column Title...",
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          if (isEditing)
            TextButton(
              onPressed: () {
                ref
                    .read(boardDetailProvider(widget.boardId))
                    .deleteColumn(columnId!);
                Navigator.pop(context);
              },
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                if (isEditing)
                  ref
                      .read(boardDetailProvider(widget.boardId))
                      .updateColumn(columnId!, titleController.text.trim());
                else
                  ref
                      .read(boardDetailProvider(widget.boardId))
                      .createColumn(titleController.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text(
              isEditing ? "Save" : "Create",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskEditModal(BuildContext context, db.Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TaskEditModal(task: task, boardId: widget.boardId),
      ),
    );
  }
}
