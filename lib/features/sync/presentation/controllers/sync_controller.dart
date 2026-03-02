import 'package:client/core/network/api_client.dart';
import 'package:client/database/database.dart';
import 'package:client/database/database_provider.dart';
import 'package:client/features/auth/presentation/controllers/auth_controller.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../data/sync_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  debugPrint("🟢 Provider Init: apiClientProvider initialized");
  return ApiClient();
});

// Sync Service Provider
final syncServiceProvider = Provider<SyncService>((ref) {
  debugPrint("🟢 Provider Init: syncServiceProvider initialized");
  final db = ref.watch(databaseProvider);
  final apiClient = ref.watch(apiClientProvider);

  // 👈 THE FIX: Pass a getter function so the service always knows the current user
  final service = SyncService(
    db,
    apiClient,
    () => ref.read(authControllerProvider).value?.id,
    // --- NEW: Callback to push conflicts into the state ---
    (rawConflicts) {
      final parsedConflicts = rawConflicts
          .map(
            (c) => SyncConflict(
              queueId: c['queueId'],
              entityType: c['entityType'],
              serverData: c['serverData'],
            ),
          )
          .toList();

      ref.read(conflictProvider.notifier).addConflicts(parsedConflicts);
    },
  );

  service.startMonitoring();

  return service;
});

// The filtered provider for the Cloud Icon (Pending only)
final syncQueueProvider = StreamProvider.autoDispose<List<SyncQueueData>>((
  ref,
) {
  debugPrint(
    "🟢 Provider Init: syncQueueProvider (Pending Only) stream started",
  );

  ref.onDispose(() {
    debugPrint("🔴 Provider Dispose: syncQueueProvider stream closed");
  });

  final db = ref.watch(databaseProvider);
  return (db.select(db.syncQueue)
        ..where((t) => t.status.equals('SYNCED').not())
        ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
      .watch()
      .map((data) {
        debugPrint(
          "📊 Stream Update: syncQueueProvider fetched ${data.length} pending/failed items.",
        );
        return data;
      });
});

// Fetch the complete history for the Activity Feed, including SYNCED items
final activityFeedProvider = StreamProvider.autoDispose<List<SyncQueueData>>((
  ref,
) {
  debugPrint(
    "🟢 Provider Init: activityFeedProvider (Complete History) stream started",
  );

  ref.onDispose(() {
    debugPrint("🔴 Provider Dispose: activityFeedProvider stream closed");
  });

  final db = ref.watch(databaseProvider);
  return (db.select(
    db.syncQueue,
  )..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)])).watch().map((
    data,
  ) {
    debugPrint(
      "📊 Stream Update: activityFeedProvider fetched ${data.length} total history items.",
    );
    return data;
  });
});

// --- CONFLICT RESOLUTION STATE ---

class SyncConflict {
  final String queueId;
  final String entityType;
  final Map<String, dynamic> serverData;

  SyncConflict({
    required this.queueId,
    required this.entityType,
    required this.serverData,
  });
}

class ConflictNotifier extends StateNotifier<List<SyncConflict>> {
  ConflictNotifier() : super([]);

  void addConflicts(List<SyncConflict> conflicts) {
    state = [...state, ...conflicts];
  }

  void removeConflict(String queueId) {
    state = state.where((c) => c.queueId != queueId).toList();
  }
}

final conflictProvider =
    StateNotifierProvider<ConflictNotifier, List<SyncConflict>>((ref) {
      return ConflictNotifier();
    });
