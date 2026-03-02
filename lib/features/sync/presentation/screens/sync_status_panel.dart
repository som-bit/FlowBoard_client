import 'dart:convert';
import 'package:client/features/sync/presentation/controllers/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../database/database.dart' hide Column;
import '../../../../database/database_provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

final syncQueueProvider = StreamProvider.autoDispose<List<SyncQueueData>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.syncQueue)
        ..where((t) => t.status.equals('SYNCED').not())
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
      .watch();
});

class SyncStatusPanel extends ConsumerWidget {
  const SyncStatusPanel({super.key});

  // HELPER: Translates raw database payloads into human-readable text
  String _parseOperation(String type, Map<String, dynamic> payload) {
    if (type == 'DELETE') return "Deleted Item";

    // Deduce entity type based on payload shape (just like the Node.js backend!)
    if (payload.containsKey('color')) {
      return type == 'INSERT'
          ? "Created Board: ${payload['title']}"
          : "Updated Board";
    } else if (payload.containsKey('boardId')) {
      return type == 'INSERT'
          ? "Created Column: ${payload['title']}"
          : "Updated Column";
    } else if (payload.containsKey('columnId')) {
      if (type == 'INSERT') return "Created Task: ${payload['title']}";
      if (payload.containsKey('position') && !payload.containsKey('title'))
        return "Moved Task to new position";
      return "Updated Task Details";
    }
    return "$type Operation";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(syncQueueProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        border: Border.all(color: const Color(0xFF1E293B), width: 2),
      ),
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Sync Status",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          Expanded(
            child: queueAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text("Error: $err")),
              data: (queue) {
                if (queue.isEmpty) {
                  return const Center(
                    child: Text(
                      "All changes synced to cloud! ✨",
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final payload = jsonDecode(item.payload);
                    final isFailed = item.status == 'FAILED';

                    return Container(
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: isFailed
                              ? Colors.red.withOpacity(0.3)
                              : Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.operationType == 'DELETE'
                                ? Icons.delete_outline
                                : item.operationType == 'UPDATE'
                                ? Icons.edit
                                : Icons.add_circle_outline,
                            color: isFailed
                                ? Colors.redAccent
                                : Colors.orangeAccent,
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _parseOperation(item.operationType, payload),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "ID: ${item.entityId.substring(0, 8)}...",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.status,
                                style: TextStyle(
                                  color: isFailed
                                      ? Colors.redAccent
                                      : Colors.orangeAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isFailed)
                                Text(
                                  "Retries: ${item.retryCount}",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: EdgeInsets.symmetric(vertical: 16.h),
              ),
              icon: const Icon(Icons.sync, color: Colors.white),
              label: const Text(
                "Sync All Now",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                // --- THE FIX: Get the user ID and pass it to forceSync ---
                final userId = ref.read(authControllerProvider).value?.id;

                if (userId != null) {
                  // forceSync automatically calls processQueue internally, so we only need to call this!
                  ref.read(syncServiceProvider).forceSync();
                }

                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
