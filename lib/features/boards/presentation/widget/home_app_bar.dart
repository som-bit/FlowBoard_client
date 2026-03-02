import 'package:client/features/profile/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../sync/presentation/controllers/sync_controller.dart';
import '../../../sync/presentation/screens/sync_status_panel.dart' hide syncQueueProvider;


class HomeAppBar extends ConsumerWidget {
  const HomeAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingSyncAsyncValue = ref.watch(syncQueueProvider);

    // Calculate if we have pending items right now
    final hasPendingItems = pendingSyncAsyncValue.maybeWhen(
      data: (queue) => queue.isNotEmpty,
      orElse: () => false,
    );

    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded, color: const Color(0xFF3B82F6), size: 32.sp),
          SizedBox(width: 12.w),
          Text(
            'FlowBoard',
            style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          
          // CLOUD ICON
          pendingSyncAsyncValue.maybeWhen(
            data: (queue) {
              return IconButton(
                icon: Icon(
                  hasPendingItems ? Icons.cloud_upload_outlined : Icons.cloud_done,
                  color: hasPendingItems ? Colors.orangeAccent : Colors.greenAccent,
                  size: 28.sp,
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const SyncStatusPanel(),
                  );
                },
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          
          // PROFILE BUTTON
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3B82F6), width: 2),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 20),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}