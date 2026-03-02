import 'package:client/features/sync/presentation/screens/sync_status_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../database/database.dart' hide Column; 
import '../controllers/boards_controller.dart';

class BoardCard extends StatelessWidget {
  final Board board;
  final WidgetRef ref;

  const BoardCard({super.key, required this.board, required this.ref});

  @override
  Widget build(BuildContext context) {
    Color boardColor = const Color(0xFF3B82F6);
    try {
      boardColor = Color(int.parse(board.color.replaceFirst('#', '0xFF')));
    } catch (_) {}

    // --- DYNAMIC SYNC STATUS LOGIC ---
    final syncQueueAsync = ref.watch(syncQueueProvider);
    String statusText = "Synced to Cloud";
    Color statusColor = Colors.green;
    IconData statusIcon = Icons.cloud_done_outlined;

    if (syncQueueAsync is AsyncData) {
      final queue = syncQueueAsync.value!;
      // Check if this specific board has pending operations in the queue
      final boardOps = queue.where((q) => q.entityId == board.id).toList();
      
      if (boardOps.isNotEmpty) {
        final status = boardOps.first.status;
        if (status == 'FAILED') {
          statusText = "Sync Failed";
          statusColor = Colors.redAccent;
          statusIcon = Icons.error_outline;
        } else if (status == 'SYNCING') {
          statusText = "Syncing...";
          statusColor = Colors.blueAccent;
          statusIcon = Icons.cloud_upload_outlined;
        } else {
          statusText = "Offline - Pending Sync";
          statusColor = Colors.orange;
          statusIcon = Icons.cloud_off_outlined;
        }
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12.r),
        border: Border(left: BorderSide(color: boardColor, width: 6.w)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        title: Text(board.title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: Colors.white)),
        
        // UPGRADED DYNAMIC SUBTITLE
        subtitle: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 14.sp),
            SizedBox(width: 4.w),
            Text(statusText, style: TextStyle(fontSize: 12.sp, color: statusColor)),
          ],
        ),
        
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          color: const Color(0xFF1E293B),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditBoardDialog(context, ref, board);
            } else if (value == 'delete') {
              ref.read(boardsControllerProvider).deleteBoard(board.id);
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Board', style: TextStyle(color: Colors.white))),
            const PopupMenuItem(value: 'delete', child: Text('Delete Board', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
        onTap: () {
           context.push('/board/${board.id}');
        },
      ),
    );
  }

  void _showEditBoardDialog(BuildContext context, WidgetRef ref, Board board) {
    final titleController = TextEditingController(text: board.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Edit Board', style: TextStyle(fontSize: 20.sp, color: Colors.white)),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Board Title',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                ref.read(boardsControllerProvider).updateBoard(
                  board.id,
                  titleController.text.trim(), 
                  board.color,
                );
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}