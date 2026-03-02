import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import '../../../../database/database.dart' hide Column; 

class ActivityFeedItem extends StatelessWidget {
  final SyncQueueData item;
  final Map<String, dynamic> payload;

  const ActivityFeedItem({super.key, required this.item, required this.payload});

  String _parseActivityTitle() {
    if (item.operationType == 'DELETE') return "Deleted an item";
    if (payload.containsKey('color')) {
      return item.operationType == 'INSERT' ? "Created board '${payload['title']}'" : "Updated board details";
    }
    if (payload.containsKey('boardId')) {
      return item.operationType == 'INSERT' ? "Added column '${payload['title']}'" : "Renamed a column";
    }
    if (payload.containsKey('columnId')) {
      if (item.operationType == 'INSERT') return "Created task '${payload['title']}'";
      if (payload.containsKey('position') && !payload.containsKey('title')) return "Moved a task to a new stage";
      final title = payload['title'] != null ? "'${payload['title']}'" : "details";
      return "Updated task $title";
    }
    return "Performed an action";
  }

  Widget _buildSyncBadge() {
    Color color;
    IconData icon;
    switch (item.status) {
      case 'SYNCED': color = Colors.greenAccent; icon = Icons.cloud_done_outlined; break;
      case 'FAILED': color = Colors.redAccent; icon = Icons.error_outline; break;
      case 'SYNCING': color = Colors.blueAccent; icon = Icons.sync; break;
      default: color = Colors.orangeAccent; icon = Icons.cloud_upload_outlined; break;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12.sp),
        SizedBox(width: 4.w),
        Text(item.status, style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPriorityBadge() {
    final priority = payload['priority'] as String;
    Color color = priority.toLowerCase() == 'high' ? Colors.redAccent 
        : priority.toLowerCase() == 'medium' ? Colors.orangeAccent 
        : Colors.blueAccent;
            
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(4.r)),
      child: Text(priority.toUpperCase(), style: TextStyle(color: color, fontSize: 9.sp, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDueDateBadge() {
    final dueDate = payload['dueDate'];
    String dateStr = "Unknown";
    try {
      if (dueDate is int) dateStr = DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(dueDate));
      else if (dueDate is String) dateStr = DateFormat('MMM d').format(DateTime.parse(dueDate));
    } catch (_) {}

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today, color: Colors.grey.shade400, size: 10.sp),
        SizedBox(width: 4.w),
        Text(dateStr, style: TextStyle(color: Colors.grey.shade400, fontSize: 10.sp, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeAgo = timeago.format(DateTime.parse(item.createdAt));

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 4.h),
            width: 8.w, height: 8.h,
            decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You ${_parseActivityTitle().toLowerCase()}", style: TextStyle(color: Colors.white, fontSize: 14.sp)),
                SizedBox(height: 6.h),
                Wrap(
                  spacing: 12.w,
                  runSpacing: 8.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(timeAgo, style: TextStyle(color: Colors.grey.shade500, fontSize: 11.sp)),
                    _buildSyncBadge(),
                    if (payload.containsKey('priority') && payload['priority'] != null) _buildPriorityBadge(),
                    if (payload.containsKey('dueDate') && payload['dueDate'] != null) _buildDueDateBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}