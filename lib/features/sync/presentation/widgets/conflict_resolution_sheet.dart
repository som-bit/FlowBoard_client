  import 'package:client/database/database.dart' hide Column;
  import 'package:client/database/database_provider.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import 'package:flutter_screenutil/flutter_screenutil.dart';
  import 'package:drift/drift.dart' as drift;
  import 'dart:convert';

  import '../controllers/sync_controller.dart';
  import '../../../auth/presentation/controllers/auth_controller.dart';

  class ConflictResolutionSheet extends ConsumerStatefulWidget {
    final SyncConflict conflict;
    const ConflictResolutionSheet({super.key, required this.conflict});

    @override
    ConsumerState<ConflictResolutionSheet> createState() => _ConflictResolutionSheetState();
  }

  class _ConflictResolutionSheetState extends ConsumerState<ConflictResolutionSheet> {
    Task? localTask;
    bool isLoading = true;

    @override
    void initState() {
      super.initState();
      _fetchLocalData();
    }

    Future<void> _fetchLocalData() async {
      final db = ref.read(databaseProvider);
      final entityId = widget.conflict.serverData['_id'];
      
      // We are focusing on Tasks for the UI comparison as per the spec
      if (widget.conflict.entityType == 'tasks') {
        final task = await (db.select(db.tasks)..where((t) => t.id.equals(entityId))).getSingleOrNull();
        if (mounted) setState(() { localTask = task; isLoading = false; });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    }

    // --- RESOLUTION LOGIC 1: USE CLOUD ---
    Future<void> _handleUseCloud() async {
      final db = ref.read(databaseProvider);
      final serverData = widget.conflict.serverData;

      await db.transaction(() async {
        if (widget.conflict.entityType == 'tasks') {
          DateTime? dueDateObj;
          if (serverData['dueDate'] != null) dueDateObj = DateTime.tryParse(serverData['dueDate']);

          // 1. Overwrite local SQLite with Server Data
          await db.into(db.tasks).insertOnConflictUpdate(TasksCompanion.insert(
            id: serverData['_id'],
            columnId: serverData['columnId'],
            title: serverData['title'],
            description: drift.Value(serverData['description'] ?? ''),
            status: serverData['status'] ?? 'To Do',
            priority: serverData['priority'] ?? 'Medium',
            position: serverData['position'] ?? 0,
            dueDate: drift.Value(dueDateObj?.millisecondsSinceEpoch),
            isDeleted: drift.Value(serverData['isDeleted'] ?? false),
            updatedAt: serverData['updatedAt'],
            createdAt: serverData['createdAt'] ?? serverData['updatedAt'],
          ));
        }
        
        // 2. Mark queue as SYNCED
        await (db.update(db.syncQueue)..where((t) => t.queueId.equals(widget.conflict.queueId)))
            .write(const SyncQueueCompanion(status: drift.Value('SYNCED')));
      });

      _dismiss();
    }

    // --- RESOLUTION LOGIC 2: KEEP MINE ---
    // Future<void> _handleKeepMine() async {
    //   final db = ref.read(databaseProvider);
    //   final nowIso = DateTime.now().toUtc().toIso8601String(); // Create a NEW timestamp!

    //   await db.transaction(() async {
    //     if (widget.conflict.entityType == 'tasks' && localTask != null) {
    //       // 1. Update the local task's timestamp to be newer than the server
    //       await (db.update(db.tasks)..where((t) => t.id.equals(localTask!.id)))
    //           .write(TasksCompanion(updatedAt: drift.Value(nowIso)));
              
    //       // 2. Fetch the existing queue item to update its payload
    //       final queueItem = await (db.select(db.syncQueue)..where((t) => t.queueId.equals(widget.conflict.queueId))).getSingle();
    //       final payload = jsonDecode(queueItem.payload) as Map<String, dynamic>;
    //       payload['updatedAt'] = nowIso; // Inject the winning timestamp

    //       // 3. Reset the queue item so it gets picked up again
    //       await (db.update(db.syncQueue)..where((t) => t.queueId.equals(widget.conflict.queueId))).write(
    //         SyncQueueCompanion(
    //           status: const drift.Value('PENDING'),
    //           retryCount: const drift.Value(0),
    //           payload: drift.Value(jsonEncode(payload)),
    //         )
    //       );

          
    //     }
    //   });

    //   _dismiss();
      
    //   // 4. Force a sync immediately so our new timestamp beats the server!
    //   final userId = ref.read(authControllerProvider).value?.id;
    //   if (userId != null) ref.read(syncServiceProvider).forceSync();
    // }



// --- RESOLUTION LOGIC 2: KEEP MINE ---
  Future<void> _handleKeepMine() async {
    final db = ref.read(databaseProvider);
    
    // THE FIX: Use the REAL current time, bringing the document back to the present.
    final realNowIso = DateTime.now().toUtc().toIso8601String();

        final userId = ref.read(authControllerProvider).value?.id;
        final syncService = ref.read(syncServiceProvider);


    await db.transaction(() async {
      if (widget.conflict.entityType == 'tasks' && localTask != null) {
        
        // 1. Update local database
        await (db.update(db.tasks)..where((t) => t.id.equals(localTask!.id)))
            .write(TasksCompanion(updatedAt: drift.Value(realNowIso)));
            
        // 2. Fetch queue item
        final queueItem = await (db.select(db.syncQueue)..where((t) => t.queueId.equals(widget.conflict.queueId))).getSingle();
        final payload = jsonDecode(queueItem.payload) as Map<String, dynamic>;
        
        // 3. Inject the real time AND the secret override flag
        payload['updatedAt'] = realNowIso; 
        payload['forceOverride'] = true; // Tell Node.js to ignore the LWW math!

        // 4. Reset queue
        await (db.update(db.syncQueue)..where((t) => t.queueId.equals(widget.conflict.queueId))).write(
          SyncQueueCompanion(
            status: const drift.Value('PENDING'),
            retryCount: const drift.Value(0),
            payload: drift.Value(jsonEncode(payload)),
          )
        );
      }
    });

    _dismiss();
    await Future.delayed(const Duration(milliseconds: 500));

    // 4. Safely trigger the sync using the pre-loaded service!
    if (userId != null) {
       syncService.forceSync();
    }

  }



    void _dismiss() {
      ref.read(conflictProvider.notifier).removeConflict(widget.conflict.queueId);
      Navigator.pop(context);
    }

    @override
    Widget build(BuildContext context) {
      if (isLoading) {
        return Container(
          height: 300.h, color: const Color(0xFF0F172A),
          child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
        );
      }

      final serverData = widget.conflict.serverData;

      return Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sync Conflict", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                    Text("MISMATCH DETECTED", style: TextStyle(color: Colors.orange, fontSize: 10.sp, letterSpacing: 1.2)),
                  ],
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: _dismiss),
              ],
            ),
            SizedBox(height: 16.h),
            Text(
              "A newer version of this task was found on the server. Please choose which version to preserve.",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13.sp),
            ),
            SizedBox(height: 24.h),

            // LOCAL VERSION CARD
            _buildVersionCard(
              title: "Your Version", 
              tagColor: Colors.blueAccent, 
              taskTitle: localTask?.title ?? 'Unknown', 
              priority: localTask?.priority ?? 'Unknown',
              isServer: false,
            ),
            
            SizedBox(height: 8.h),
            Center(child: Icon(Icons.swap_vert, color: Colors.grey.shade600)),
            SizedBox(height: 8.h),

            // SERVER VERSION CARD
            _buildVersionCard(
              title: "Server Version", 
              tagColor: Colors.purpleAccent, 
              taskTitle: serverData['title'] ?? 'Unknown', 
              priority: serverData['priority'] ?? 'Unknown',
              isServer: true,
            ),
            SizedBox(height: 24.h),
          ],
        ),
      );
    }

    Widget _buildVersionCard({required String title, required Color tagColor, required String taskTitle, required String priority, required bool isServer}) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: tagColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 12.r, backgroundColor: tagColor.withOpacity(0.2), child: Icon(isServer ? Icons.cloud : Icons.person, size: 14, color: tagColor)),
                    SizedBox(width: 8.w),
                    Text(title, style: TextStyle(color: tagColor, fontWeight: FontWeight.bold, fontSize: 14.sp)),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(8.r)),
                  child: Text(isServer ? "CLOUD" : "MINE", style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            SizedBox(height: 16.h),
            Text("TASK TITLE", style: TextStyle(color: Colors.grey.shade500, fontSize: 10.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 4.h),
            Text(taskTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            SizedBox(height: 12.h),
            Text("PRIORITY", style: TextStyle(color: Colors.grey.shade500, fontSize: 10.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 4.h),
            Text(priority, style: TextStyle(color: Colors.white, fontSize: 14.sp)),
            SizedBox(height: 16.h),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isServer ? Colors.transparent : Colors.blueAccent, side: isServer ? const BorderSide(color: Colors.grey) : BorderSide.none),
                onPressed: isServer ? _handleUseCloud : _handleKeepMine,
                child: Text(isServer ? "Use Cloud" : "Keep Mine", style: TextStyle(color: Colors.white, fontWeight: isServer ? FontWeight.normal : FontWeight.bold)),
              ),
            )
          ],
        ),
      );
    }
  }