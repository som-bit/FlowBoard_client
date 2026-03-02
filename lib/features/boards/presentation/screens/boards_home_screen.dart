import 'dart:convert';
import 'package:client/features/boards/presentation/widget/home_app_bar.dart';
import 'package:client/features/sync/presentation/widgets/conflict_resolution_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../sync/presentation/controllers/sync_controller.dart'
    hide syncQueueProvider;
import '../controllers/boards_controller.dart';
import '../widget/board_grid_card.dart';
import '../widget/create_board_dialog.dart';
import '../widget/activity_feed_item.dart';

class BoardsHomeScreen extends ConsumerWidget {
  const BoardsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<List<SyncConflict>>(conflictProvider, (previous, next) {
      if (next.isNotEmpty &&
          (previous == null || previous.length < next.length)) {
        // A new conflict arrived! Show the bottom sheet for the first one in the queue
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          isDismissible: false, // Force them to resolve it!
          backgroundColor: Colors.transparent,
          builder: (context) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ConflictResolutionSheet(conflict: next.first),
          ),
        );
      }
    });
    final boardsAsyncValue = ref.watch(boardsStreamProvider);
    final activityFeedAsyncValue = ref.watch(activityFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- TOP HEADER ---
            const SliverToBoxAdapter(child: HomeAppBar()),

            // --- BOARDS SECTION HEADER ---
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Boards',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF3B82F6,
                        ).withOpacity(0.2),
                        foregroundColor: const Color(0xFF3B82F6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const CreateBoardDialog(),
                        );
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        "New Board",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- BOARDS GRID ---
            boardsAsyncValue.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) =>
                  SliverToBoxAdapter(child: Center(child: Text('Error: $e'))),
              data: (boards) {
                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16.h,
                      crossAxisSpacing: 16.w,
                      childAspectRatio: 0.85,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => BoardGridCard(board: boards[index]),
                      childCount: boards.length,
                    ),
                  ),
                );
              },
            ),

            // --- RECENT ACTIVITY HEADER ---
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.w,
                  right: 20.w,
                  top: 32.h,
                  bottom: 16.h,
                ),
                child: Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),

            // --- RECENT ACTIVITY LIST ---
            activityFeedAsyncValue.when(
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (e, st) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (queue) {
                if (queue.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        "No recent offline activity.",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                final recentItems = queue.take(20).toList();

                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = recentItems[index];
                    final payload = jsonDecode(item.payload);
                    return ActivityFeedItem(item: item, payload: payload);
                  }, childCount: recentItems.length),
                );
              },
            ),

            SliverToBoxAdapter(child: SizedBox(height: 40.h)),
          ],
        ),
      ),
      // bottomNavigationBar: const HomeBottomNav(),
    );
  }
}
