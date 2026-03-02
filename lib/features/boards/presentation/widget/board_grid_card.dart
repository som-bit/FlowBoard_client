// import 'package:client/features/sync/presentation/screens/sync_status_panel.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:go_router/go_router.dart';
// import 'package:timeago/timeago.dart' as timeago;
// import '../../../../database/database.dart' hide Column;

// class BoardGridCard extends ConsumerWidget {
//   final Board board;
//   const BoardGridCard({super.key, required this.board});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     // Check sync status for this specific board
//     final syncQueueAsync = ref.watch(syncQueueProvider);
//     String badgeText = "SYNCED";
//     Color badgeColor = Colors.blueAccent.withOpacity(0.2);
//     Color badgeTextColor = Colors.blueAccent;

//     if (syncQueueAsync is AsyncData) {
//       final queue = syncQueueAsync.value!;
//       final boardOps = queue.where((q) => q.entityId == board.id).toList();
      
//       if (boardOps.isNotEmpty) {
//         final status = boardOps.first.status;
//         if (status == 'FAILED') {
//           badgeText = "FAILED";
//           badgeColor = Colors.redAccent.withOpacity(0.2);
//           badgeTextColor = Colors.redAccent;
//         } else if (status == 'SYNCING') {
//           badgeText = "SYNCING";
//           badgeColor = Colors.orangeAccent.withOpacity(0.2);
//           badgeTextColor = Colors.orangeAccent;
//         } else {
//           badgeText = "PENDING";
//           badgeColor = Colors.orange.withOpacity(0.2);
//           badgeTextColor = Colors.orange;
//         }
//       }
//     }

//     final timeAgo = timeago.format(DateTime.parse(board.updatedAt));

//     return InkWell(
//       onTap: () => context.push('/board/${board.id}'),
//       borderRadius: BorderRadius.circular(16.r),
//       child: Container(
//         padding: EdgeInsets.all(16.w),
//         decoration: BoxDecoration(
//           color: const Color(0xFF1E293B),
//           borderRadius: BorderRadius.circular(16.r),
//           border: Border.all(color: Colors.white.withOpacity(0.05)),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Expanded(
//                   child: Text(
//                     board.title,
//                     style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
//                     maxLines: 2, overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//                 Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
//                   decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12.r)),
//                   child: Text(badgeText, style: TextStyle(color: badgeTextColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
//                 )
//               ],
//             ),
//             const Spacer(),
//             Row(
//               children: [
//                 Icon(Icons.check_circle_outline, color: Colors.grey, size: 14.sp),
//                 SizedBox(width: 6.w),
//                 Text("Tasks inside", style: TextStyle(color: Colors.grey, fontSize: 12.sp)), // Hook up a task count query here later!
//               ],
//             ),
//             SizedBox(height: 8.h),
//             Row(
//               children: [
//                 Icon(Icons.access_time, color: Colors.grey, size: 14.sp),
//                 SizedBox(width: 6.w),
//                 Text(timeAgo, style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../database/database.dart' hide Column;
import '../../../sync/presentation/controllers/sync_controller.dart';
import '../controllers/boards_controller.dart';

class BoardGridCard extends ConsumerWidget {
  final Board board;
  const BoardGridCard({super.key, required this.board});

  void _showEditBoardDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController(text: board.title);
    String selectedColor = board.color;
    final List<String> colors = ['#3B82F6', '#EF4444', '#10B981', '#F59E0B', '#8B5CF6', '#EC4899'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: const Text('Edit Board', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Board Title',
                    filled: true, fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 16.h),
                const Text('COLOR', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: colors.map((colorHex) {
                    final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColor = colorHex),
                      child: Container(
                        width: 32.w, height: 32.h,
                        decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: Colors.white, width: 2.w) : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(boardsControllerProvider).deleteBoard(board.id);
                  Navigator.pop(context);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
                onPressed: () {
                  if (titleController.text.isNotEmpty) {
                    ref.read(boardsControllerProvider).updateBoard(board.id, titleController.text.trim(), selectedColor);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncQueueAsync = ref.watch(syncQueueProvider);
    String badgeText = "SYNCED";
    Color badgeColor = Colors.blueAccent.withOpacity(0.2);
    Color badgeTextColor = Colors.blueAccent;

    if (syncQueueAsync is AsyncData) {
      final queue = syncQueueAsync.value!;
      final boardOps = queue.where((q) => q.entityId == board.id).toList();
      
      if (boardOps.isNotEmpty) {
        final status = boardOps.first.status;
        if (status == 'FAILED') { badgeText = "FAILED"; badgeColor = Colors.redAccent.withOpacity(0.2); badgeTextColor = Colors.redAccent; } 
        else if (status == 'SYNCING') { badgeText = "SYNCING"; badgeColor = Colors.orangeAccent.withOpacity(0.2); badgeTextColor = Colors.orangeAccent; } 
        else { badgeText = "PENDING"; badgeColor = Colors.orange.withOpacity(0.2); badgeTextColor = Colors.orange; }
      }
    }

    final timeAgo = timeago.format(DateTime.parse(board.updatedAt));
    Color parsedBoardColor = const Color(0xFF3B82F6);
    try { parsedBoardColor = Color(int.parse(board.color.replaceFirst('#', '0xFF'))); } catch (_) {}

    return InkWell(
      onTap: () => context.push('/board/${board.id}'),
      onLongPress: () => _showEditBoardDialog(context, ref), // Long press to edit!
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16.r),
          // Use the parsed color for a subtle top border!
          border: Border(top: BorderSide(color: parsedBoardColor, width: 4.h)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(board.title, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                // 3-Dot Menu for editing
                GestureDetector(
                  onTap: () => _showEditBoardDialog(context, ref),
                  child: Icon(Icons.more_vert, color: Colors.grey, size: 18.sp),
                )
              ],
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(12.r)),
              child: Text(badgeText, style: TextStyle(color: badgeTextColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey, size: 14.sp),
                SizedBox(width: 6.w),
                Text(timeAgo, style: TextStyle(color: Colors.grey, fontSize: 12.sp)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}