import 'package:client/features/boards/presentation/controllers/boards_controller.dart';
import 'package:client/features/sync/presentation/controllers/sync_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  throw UnimplementedError('Initialize this in main.dart with instances');
});

class AuthController extends AsyncNotifier<User?> {
  late final AuthRepository _repository;

  @override
  Future<User?> build() async {
    _repository = ref.watch(authRepositoryProvider);
    return _checkToken();
  }

  Future<User?> _checkToken() async {
    final token = await _repository.getToken();
    if (token != null) {
      return User(id: 'local', name: 'Valid Token', email: 'user@local.com');
    }
    return null;
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      return await _repository.register(name, email, password);
    });
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      // 1. Authenticate with the Node.js server
      final user = await _repository.login(email, password);

      debugPrint(
        "🔐 AuthController: Login successful for ${user.id}. Starting hydration...",
      );

      await ref.read(syncServiceProvider).hydrateLocalDatabase(user.id);

      return user;
    });
  }

  // --- UPDATED LOGOUT METHOD ---
  Future<void> logout() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      // 1. WIPE LOCAL DB: Ensure the next user doesn't see this user's data
      await ref.read(syncServiceProvider).wipeLocalDataOnLogout();

      // 2. FORCE REFRESH ALL PROVIDERS
      // This is the "Nuclear Option" to ensure no ghost data remains
      ref.invalidate(boardsStreamProvider);
      ref.invalidate(activityFeedProvider);
      ref.invalidate(syncQueueProvider);

      await _repository.logout();

      // 4. RESET STATE: Return null to kick the user back to the login screen
      return null;
    });
  }

  // Add this method inside your AuthController (StateNotifier or AsyncNotifier)
  Future<void> fetchUserDetails() async {
    try {
      // Use your existing apiClient which handles the JWT headers
      final response = await ref.read(apiClientProvider).dio.get('/auth/profile');

      if (response.statusCode == 200) {
        final userData = User.fromJson(response.data);
        // Update the state with the fresh data from the server
        state = AsyncData(userData);
        debugPrint("👤 AuthController: Profile data refreshed from server");
      }
    } catch (e) {
      debugPrint("❌ AuthController: Failed to fetch user details: $e");
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(() {
  return AuthController();
});
