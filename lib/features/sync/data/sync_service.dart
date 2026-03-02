import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/network/api_client.dart';
import '../../../../database/database.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class SyncService {
  final AppDatabase _db;
  final ApiClient _apiClient;
  final String? Function() _getUserId;
  final Function(List<Map<String, dynamic>>) _onConflictsDetected;

  bool _isSyncing = false;
  Timer? _debounceTimer;

  SyncService(
    this._db,
    this._apiClient,
    this._getUserId,
    this._onConflictsDetected,
  );

  void startMonitoring() {
    debugPrint("🚀 SyncService: Background monitoring started.");

    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        debugPrint("🌐 SyncService: Network restored. Triggering sync...");
        processQueue(_getUserId() ?? '');
      }
    });

    _db.select(_db.syncQueue).watch().listen((queue) async {
      final needsSync = queue.any(
        (q) => q.status == 'PENDING' || q.status == 'FAILED',
      );

      if (needsSync) {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          return;
        }

        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 2), () {
          processQueue(_getUserId() ?? '');
        });
      }
    });
  }

  Future<void> hydrateLocalDatabase(String userId) async {
    debugPrint("📥 SyncService: Checking if local DB needs hydration...");

    final existingBoards = await (_db.select(_db.boards)).get();
    if (existingBoards.isNotEmpty) {
      debugPrint(
        "👍 SyncService: Local DB already has data. Skipping hydration.",
      );
      return;
    }

    try {
      debugPrint(
        "📥 SyncService: Local DB is empty. Fetching from cloud for user: $userId...",
      );

      final response = await _apiClient.dio.get(
        '/sync/pull',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        debugPrint(
          "📦 SyncService: Received ${data['boards']?.length ?? 0} boards, "
          "${data['columns']?.length ?? 0} columns, and ${data['tasks']?.length ?? 0} tasks. "
          "Activity Logs: ${data['activityLogs']?.length ?? 0}",
        );

        await _db.transaction(() async {
          for (var b in data['boards'] ?? []) {
            await _db
                .into(_db.boards)
                .insert(
                  BoardsCompanion.insert(
                    id: b['id'] ?? b['_id'],
                    title: b['title'],
                    color: drift.Value(b['color'] ?? '#3B82F6'),
                    isDeleted: drift.Value(b['isDeleted'] ?? false),
                    updatedAt: b['updatedAt'],
                    createdAt: b['createdAt'] ?? b['updatedAt'],
                  ),
                );
          }

          for (var c in data['columns'] ?? []) {
            await _db
                .into(_db.columns)
                .insert(
                  ColumnsCompanion.insert(
                    id: c['id'] ?? c['_id'],
                    boardId: c['boardId'],
                    title: c['title'],
                    position: c['position'] ?? 0,
                    isDeleted: drift.Value(c['isDeleted'] ?? false),
                    updatedAt: c['updatedAt'],
                    createdAt: c['createdAt'] ?? c['updatedAt'],
                  ),
                );
          }

          for (var t in data['tasks'] ?? []) {
            DateTime? dueDateObj;
            if (t['dueDate'] != null)
              dueDateObj = DateTime.tryParse(t['dueDate']);

            await _db
                .into(_db.tasks)
                .insert(
                  TasksCompanion.insert(
                    id: t['id'] ?? t['_id'],
                    columnId: t['columnId'],
                    title: t['title'],
                    description: drift.Value(t['description'] ?? ''),
                    status: t['status'] ?? 'To Do',
                    priority: t['priority'] ?? 'Medium',
                    position: t['position'] ?? 0,
                    dueDate: drift.Value(dueDateObj?.millisecondsSinceEpoch),
                    isDeleted: drift.Value(t['isDeleted'] ?? false),
                    updatedAt: t['updatedAt'],
                    createdAt: t['createdAt'] ?? t['updatedAt'],
                  ),
                );
          }

          for (var log in data['activityLogs'] ?? []) {
            await _db
                .into(_db.syncQueue)
                .insert(
                  SyncQueueCompanion.insert(
                    queueId: log['id'] ?? log['_id'],
                    entityId: log['entityId'],
                    operationType: log['operationType'],
                    payload: jsonEncode(log['payload']),
                    status: const drift.Value('SYNCED'),
                    createdAt: log['createdAt'],
                  ),
                );
          }
        });

        debugPrint("✅ SyncService: Local DB successfully hydrated!");
      }
    } catch (e) {
      debugPrint("❌ SyncService: Hydration failed: $e");
    }
  }

  Future<void> wipeLocalDataOnLogout() async {
    debugPrint("🧹 SyncService: Wiping local database for logout...");
    await _db.transaction(() async {
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.columns).go();
      await _db.delete(_db.boards).go();
      await _db.delete(_db.syncQueue).go();
    });
    debugPrint("✅ SyncService: Local database wiped clean.");
  }




  Future<void> forceSync() async {
    debugPrint("⚡ SyncService: Force Sync initiated by user!");
    await (_db.update(_db.syncQueue)..where((t) => t.status.equals('FAILED')))
        .write(const SyncQueueCompanion(retryCount: drift.Value(0)));
    await processQueue(_getUserId() ?? '');
  }




  Future<void> processQueue(String userId) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final pendingOps =
          await (_db.select(_db.syncQueue)
                ..where(
                  (t) => t.status.equals('PENDING') | t.status.equals('FAILED'),
                )
                ..where((t) => t.retryCount.isSmallerThanValue(5))
                ..orderBy([(t) => drift.OrderingTerm.asc(t.createdAt)]))
              .get();

      if (pendingOps.isEmpty) {
        _isSyncing = false;
        return;
      }

      final queueIds = pendingOps.map((op) => op.queueId).toList();
      await (_db.update(_db.syncQueue)..where((t) => t.queueId.isIn(queueIds)))
          .write(const SyncQueueCompanion(status: drift.Value('SYNCING')));

      final payload = pendingOps
          .map(
            (op) => {
              'queueId': op.queueId,
              'entityId': op.entityId,
              'operationType': op.operationType,
              'payload': jsonDecode(op.payload),
              'createdAt': op.createdAt,
            },
          )
          .toList();

      final response = await _apiClient.dio.post(
        '/sync',
        data: {'userId': userId, 'operations': payload},
      );

      // if (response.statusCode == 200 || response.statusCode == 201) {
      //   final data = response.data;
      //   final conflicts = data['conflicts'] as List<dynamic>? ?? [];

      //   await _db.transaction(() async {
      //     // --- STRICT LWW: OVERWRITE LOCAL DATA WITH SERVER DATA ---
      //     if (conflicts.isNotEmpty) {
      //       debugPrint(
      //         "⚠️ SyncService: Resolving ${conflicts.length} server conflicts...",
      //       );
      //       for (var conflict in conflicts) {
      //         final serverData = conflict['serverData'];
      //         final entityType = conflict['entityType'];

      // if (entityType == 'tasks') {
      //   DateTime? dueDateObj;
      //   if (serverData['dueDate'] != null)
      //     dueDateObj = DateTime.tryParse(serverData['dueDate']);

      //   // UPSERT local database with winning server data
      //   await _db
      //       .into(_db.tasks)
      //       .insertOnConflictUpdate(
      //         TasksCompanion.insert(
      // id: serverData['_id'],
      // columnId: serverData['columnId'],
      // title: serverData['title'],
      // description: drift.Value(
      //   serverData['description'] ?? '',
      // ),
      // status: serverData['status'] ?? 'To Do',
      // priority: serverData['priority'] ?? 'Medium',
      // position: serverData['position'] ?? 0,
      // dueDate: drift.Value(
      //   dueDateObj?.millisecondsSinceEpoch,
      // ),
      // isDeleted: drift.Value(
      //   serverData['isDeleted'] ?? false,
      // ),
      // updatedAt: serverData['updatedAt'],
      // createdAt:
      //               serverData['createdAt'] ?? serverData['updatedAt'],
      //         ),
      //       );
      // } else if (entityType == 'boards') {
      //   await _db
      //       .into(_db.boards)
      //       .insertOnConflictUpdate(
      //         BoardsCompanion.insert(
      //           id: serverData['_id'],
      //           title: serverData['title'],
      //           color: drift.Value(serverData['color'] ?? '#3B82F6'),
      //           isDeleted: drift.Value(
      //             serverData['isDeleted'] ?? false,
      //               ),
      //               updatedAt: serverData['updatedAt'],
      //               createdAt:
      //                   serverData['createdAt'] ?? serverData['updatedAt'],
      //             ),
      //           );
      //     }
      //     // You can add 'columns' logic here similarly
      //   }
      // }

      //   // Mark all queue items as SYNCED (Even conflicts are 'synced' because they were resolved)
      //   await (_db.update(_db.syncQueue)
      //         ..where((t) => t.queueId.isIn(queueIds)))
      //       .write(const SyncQueueCompanion(status: drift.Value('SYNCED')));
      // });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        final conflicts = data['conflicts'] as List<dynamic>? ?? [];

        await _db.transaction(() async {
          // --- MANUAL LWW: PASS CONFLICTS TO UI ---
          if (conflicts.isNotEmpty) {
            debugPrint(
              "⚠️ SyncService: ${conflicts.length} server conflicts detected. Sending to UI...",
            );

            // Cast the raw JSON to a list of Maps and send it to Riverpod
            final conflictList = conflicts
                .map((c) => c as Map<String, dynamic>)
                .toList();
            _onConflictsDetected(conflictList);

            // We do NOT mark these specific queue IDs as SYNCED yet,
            // because the user hasn't resolved them!
            final conflictQueueIds = conflicts
                .map((c) => c['queueId'] as String)
                .toList();
            final successfulQueueIds = queueIds
                .where((id) => !conflictQueueIds.contains(id))
                .toList();

            if (successfulQueueIds.isNotEmpty) {
              await (_db.update(
                _db.syncQueue,
              )..where((t) => t.queueId.isIn(successfulQueueIds))).write(
                const SyncQueueCompanion(status: drift.Value('SYNCED')),
              );
            }
          } else {
            // No conflicts, mark all as SYNCED
            await (_db.update(_db.syncQueue)
                  ..where((t) => t.queueId.isIn(queueIds)))
                .write(const SyncQueueCompanion(status: drift.Value('SYNCED')));
          }
        });

        // ... (Keep your globalMessengerKey Toast here) ...
        debugPrint(
          "✅ SyncService: Successfully synced ${queueIds.length} items.",
        );

        globalMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  conflicts.isNotEmpty
                      ? "Sync paused (Conflicts Detected)"
                      : "Changes synced to cloud! ✨",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            backgroundColor: conflicts.isNotEmpty
                ? Colors.orange.shade600
                : Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      final failedOps = await (_db.select(
        _db.syncQueue,
      )..where((t) => t.status.equals('SYNCING'))).get();
      for (var op in failedOps) {
        await (_db.update(
          _db.syncQueue,
        )..where((t) => t.queueId.equals(op.queueId))).write(
          SyncQueueCompanion(
            status: const drift.Value('FAILED'),
            retryCount: drift.Value(op.retryCount + 1),
          ),
        );
      }
    } finally {
      _isSyncing = false;
    }
  }
}
