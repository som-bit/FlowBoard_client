import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../sync/presentation/controllers/sync_controller.dart';

class BoardActivityScreen extends ConsumerStatefulWidget {
  final String boardId;
  const BoardActivityScreen({super.key, required this.boardId});

  @override
  ConsumerState<BoardActivityScreen> createState() =>
      _BoardActivityScreenState();
}

class _BoardActivityScreenState extends ConsumerState<BoardActivityScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Tasks', 'Moves', 'Edits'];

  // --- UPGRADED SMART PARSER ---
  Map<String, dynamic> _parseActivity(
    String type,
    Map<String, dynamic> payload,
  ) {
    String title = "Performed an action";
    String category = "Edits"; // Default safety net

    if (type == 'DELETE') {
      return {"title": "Deleted an item", "category": "Edits"};
    }

    // 1. BOARD OPERATIONS
    if (payload.containsKey('color')) {
      title = type == 'INSERT'
          ? "Created board '${payload['title']}'"
          : "Updated board settings";
      category = "Edits";
    }
    // 2. COLUMN OPERATIONS
    else if (payload.containsKey('boardId')) {
      title = type == 'INSERT'
          ? "Added column '${payload['title']}'"
          : "Renamed column to '${payload['title']}'";
      category = "Edits";
    }
    // 3. TASK OPERATIONS
    else {
      String taskName = payload['title'] != null
          ? "'${payload['title']}'"
          : "a task";

      if (type == 'INSERT') {
        title = "Created task $taskName";
        category = "Tasks";
      }
      // If it contains position/columnId but NO priority, it's a drag-and-drop move
      else if (payload.containsKey('columnId') &&
          payload.containsKey('position') &&
          !payload.containsKey('priority')) {
        title = "Moved $taskName to a new stage";
        category = "Moves";
      }
      // If it contains priority/dueDate/description, it's an Edit Task action!
      else if (payload.containsKey('priority') ||
          payload.containsKey('dueDate') ||
          payload.containsKey('description')) {
        List<String> updates = [];
        if (payload.containsKey('priority'))
          updates.add("priority to ${payload['priority']}");
        if (payload.containsKey('dueDate') && payload['dueDate'] != null)
          updates.add("due date");
        if (payload.containsKey('description') &&
            payload['description'].toString().isNotEmpty)
          updates.add("description");

        if (updates.isNotEmpty) {
          title = "Updated $taskName ${updates.join(' & ')}";
        } else {
          title = "Edited details for $taskName";
        }
        category = "Edits";
      }
      // Fallback for simple renames
      else if (payload.containsKey('title')) {
        title = "Renamed task to $taskName";
        category = "Edits";
      }
      // Fallback for simple moves
      else if (payload.containsKey('columnId')) {
        title = "Moved $taskName";
        category = "Moves";
      }
    }

    return {"title": title, "category": category};
  }

  @override
  Widget build(BuildContext context) {
    final activityFeedAsyncValue = ref.watch(activityFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Board Activity",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "AUDIT LOG",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: ChoiceChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: const Color(0xFF3B82F6),
                    backgroundColor: const Color(0xFF1E293B),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFilter = filter);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: activityFeedAsyncValue.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              ),
              error: (e, st) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              data: (queue) {
                final filteredQueue = queue.where((item) {
                  if (_selectedFilter == 'All') return true;
                  final payload = jsonDecode(item.payload);
                  final parsed = _parseActivity(item.operationType, payload);
                  return parsed['category'] == _selectedFilter;
                }).toList();

                if (filteredQueue.isEmpty) {
                  return Center(
                    child: Text(
                      "No activity found for this filter.",
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: filteredQueue.length,
                  itemBuilder: (context, index) {
                    final item = filteredQueue[index];
                    final payload = jsonDecode(item.payload);
                    final parsedInfo = _parseActivity(
                      item.operationType,
                      payload,
                    );
                    final timeAgo = timeago.format(
                      DateTime.parse(item.createdAt),
                    );

                    final isOfflineAction =
                        item.status == 'PENDING' ||
                        item.status == 'FAILED' ||
                        item.status == 'SYNCING';

                    return Padding(
                      padding: EdgeInsets.only(bottom: 24.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: Colors
                                .primaries[index % Colors.primaries.length],
                            child: const Text(
                              "U",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "You ${parsedInfo['title'].toString().toLowerCase()}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Row(
                                  children: [
                                    Text(
                                      timeAgo,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOfflineAction
                                            ? Colors.orange.withOpacity(0.2)
                                            : Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(
                                          4.r,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isOfflineAction
                                                ? Icons.wifi_off
                                                : Icons.wifi,
                                            color: isOfflineAction
                                                ? Colors.orange
                                                : Colors.green,
                                            size: 10.sp,
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            isOfflineAction
                                                ? "OFFLINE"
                                                : "ONLINE",
                                            style: TextStyle(
                                              color: isOfflineAction
                                                  ? Colors.orange
                                                  : Colors.green,
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
