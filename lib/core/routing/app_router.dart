import 'package:client/features/boards/presentation/screens/board_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/boards/presentation/screens/boards_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',

    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);

      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final isLoadingRoute = state.matchedLocation == '/loading';

      if (authState.isLoading) {
        return isAuthRoute ? null : '/loading';
      }

      final isAuthenticated = authState.value != null;

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/login';
      }

      if (isAuthRoute || isLoadingRoute) {
        return '/';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/', builder: (context, state) => const BoardsHomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/board/:id',
        builder: (context, state) {
          final boardId = state.pathParameters['id']!;
          return BoardDetailScreen(boardId: boardId);
        },
      ),
    ],
  );

  ref.listen(authControllerProvider, (previous, next) {
    router.refresh();
  });

  return router;
});
