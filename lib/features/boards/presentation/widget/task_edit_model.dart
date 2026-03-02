import 'package:client/database/database.dart' hide Column;
import 'package:client/features/boards/presentation/controllers/board_detail_controller.dart';
import 'package:client/features/sync/presentation/controllers/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class TaskEditModal extends ConsumerStatefulWidget {
  final Task task;
  final String boardId;
  const TaskEditModal({super.key, required this.task, required this.boardId});

  @override
  ConsumerState<TaskEditModal> createState() => _TaskEditModalState();
}

class _TaskEditModalState extends ConsumerState<TaskEditModal> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedPriority;
  DateTime? _selectedDate;

  // --- MOCK ASSIGNEE DATA ---
  final List<Map<String, dynamic>> _mockTeam = [
    {'id': '1', 'name': 'Sarah M.', 'color': Colors.pinkAccent, 'initial': 'S'},
    {'id': '2', 'name': 'Alex Chen', 'color': Colors.blueAccent, 'initial': 'A'},
    {'id': '3', 'name': 'Marcus J.', 'color': Colors.orangeAccent, 'initial': 'M'},
    {'id': 'unassigned', 'name': 'Unassigned', 'color': Colors.grey, 'initial': '?'}
  ];
  
  // Track the currently selected assignee ID
  String _selectedAssigneeId = '1'; 

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description);
    _selectedPriority = widget.task.priority;
    if (widget.task.dueDate != null) {
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(widget.task.dueDate!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  // --- BOTTOM SHEET FOR ASSIGNEE SELECTION ---
  void _showAssigneePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Assign To", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 16.h),
              ..._mockTeam.map((member) {
                final isSelected = _selectedAssigneeId == member['id'];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member['color'].withOpacity(0.2),
                    child: Text(member['initial'], style: TextStyle(color: member['color'], fontWeight: FontWeight.bold)),
                  ),
                  title: Text(member['name'], style: const TextStyle(color: Colors.white)),
                  trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  tileColor: isSelected ? Colors.blueAccent.withOpacity(0.1) : Colors.transparent,
                  onTap: () {
                    setState(() => _selectedAssigneeId = member['id'] as String);
                    Navigator.pop(context);
                  },
                );
              }),
              SizedBox(height: 16.h),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncQueueAsync = ref.watch(syncQueueProvider);
    final isPending = syncQueueAsync.maybeWhen(
      data: (queue) => queue.any((q) => q.entityId == widget.task.id),
      orElse: () => false,
    );

    final selectedAssignee = _mockTeam.firstWhere((m) => m['id'] == _selectedAssigneeId);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Edit Task",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      ref
                          .read(boardDetailProvider(widget.boardId))
                          .deleteTask(widget.task.id);
                      Navigator.pop(context);
                    },
                  ),
                  IconButton(
                    icon: Container(
                      padding: EdgeInsets.all(4.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Title Input
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextField(
              controller: _titleController,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Task Title...",
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),

          SizedBox(height: 24.h),

          // Two-column layout for Date and Assignee
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DUE DATE",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 16.w,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: const Color(0xFF3B82F6),
                              size: 18.sp,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              _selectedDate != null
                                  ? DateFormat(
                                      'MMM d, yyyy',
                                    ).format(_selectedDate!)
                                  : "Select Date",
                              style: TextStyle(
                                color: _selectedDate != null
                                    ? Colors.white
                                    : Colors.grey,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(width: 16.w),
              
              // --- NEW ASSIGNEE SECTION ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ASSIGNEE",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: _showAssigneePicker,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12.r,
                              backgroundColor: selectedAssignee['color'].withOpacity(0.2),
                              child: Text(
                                selectedAssignee['initial'], 
                                style: TextStyle(color: selectedAssignee['color'], fontSize: 10.sp, fontWeight: FontWeight.bold)
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                selectedAssignee['name'],
                                style: TextStyle(color: Colors.white, fontSize: 13.sp),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 16.sp),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),
          Text(
            "PRIORITY",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: ['High', 'Medium', 'Low'].map((p) {
              final isSelected = _selectedPriority == p;
              Color chipColor = p == 'High'
                  ? Colors.redAccent
                  : p == 'Medium'
                  ? Colors.orangeAccent
                  : Colors.blueAccent;
              return Padding(
                padding: EdgeInsets.only(right: 12.w),
                child: ChoiceChip(
                  label: Text(
                    p,
                    style: TextStyle(
                      color: isSelected ? Colors.white : chipColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: chipColor,
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(
                    color: isSelected ? chipColor : Colors.transparent,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedPriority = p);
                  },
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 24.h),
          Text(
            "DESCRIPTION",
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: TextField(
                controller: _descController,
                maxLines: null,
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "Add a detailed description...",
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),

          SizedBox(height: 16.h),

          if (isPending)
            Container(
              margin: EdgeInsets.only(bottom: 16.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem, color: Colors.orange),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      "This task has unsaved offline changes. They will sync automatically when connected.",
                      style: TextStyle(color: Colors.orange, fontSize: 12.sp),
                    ),
                  ),
                ],
              ),
            ),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              onPressed: () {
                ref
                    .read(boardDetailProvider(widget.boardId))
                    .updateTaskDetails(
                      widget.task.id,
                      _titleController.text.trim(),
                      _descController.text.trim(),
                      _selectedPriority,
                      _selectedDate?.millisecondsSinceEpoch,
                    );
                Navigator.pop(context);
              },
              child: Text(
                "Save Changes",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }
}