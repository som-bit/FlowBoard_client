import 'package:appflowy_board/appflowy_board.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../database/database.dart' hide Column;

class TaskItem extends AppFlowyGroupItem {
  final Task task;
  TaskItem(this.task);
  @override
  String get id => task.id;
}

class KanbanCard extends StatelessWidget {
  final Task task;
  const KanbanCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    Color priorityColor = task.priority.toLowerCase() == 'high'
        ? Colors.redAccent
        : task.priority.toLowerCase() == 'medium'
        ? Colors.orangeAccent
        : Colors.blueAccent;

    return Container(
      width: 280.w,
      margin: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8.r),
        border: Border(
          left: BorderSide(color: priorityColor, width: 4.w),
        ), // Priority Stripe
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            if (task.description.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontSize: 12.sp,
                ),
              ),
            ],
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPriorityChip(task.priority, priorityColor),
                if (task.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12.sp,
                        color: Colors.grey.shade500,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        "Due Date",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }




  // Widget _buildPriorityChip(String priority, Color color) {
  //   return Container(
  //     padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
  //     decoration: BoxDecoration(
  //       color: color.withOpacity(0.15),
  //       borderRadius: BorderRadius.circular(6.r),
  //     ),
  //     child: Text(
  //       priority.toUpperCase(),
  //       style: TextStyle(
  //         color: color,
  //         fontSize: 10.sp,
  //         fontWeight: FontWeight.bold,
  //         letterSpacing: 0.5,
  //       ),
  //     ),
  //   );
  // }


Widget _buildPriorityChip(String priority, Color color) {
    return Flexible( // <--- Wrap in Flexible to prevent overflow
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          priority.toUpperCase(),
          maxLines: 1, // <--- Keep it to one line
          overflow: TextOverflow.ellipsis, // <--- Add ellipsis if it's too long
          style: TextStyle(
            color: color,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }


}
