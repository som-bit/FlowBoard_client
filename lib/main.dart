import 'package:client/core/widgets/offline_wrapper.dart';
import 'package:client/features/sync/data/sync_service.dart';
import 'package:client/features/sync/presentation/controllers/sync_controller.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = const FlutterSecureStorage();
  final apiClient = ApiClient();
  final authRepository = AuthRepository(apiClient, secureStorage);

  runApp(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(authRepository)],
      child: const FlowBoardApp(),
    ),
  );
}

class FlowBoardApp extends ConsumerWidget {
  const FlowBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    // THE FIX: Use watch() so the background service stays alive permanently!
    ref.watch(syncServiceProvider);

    

    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'FlowBoard',
          debugShowCheckedModeBanner: false,
          
          // ATTACH THE GLOBAL TOASTER KEY HERE
          scaffoldMessengerKey: globalMessengerKey, 
          
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF3B82F6),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF3B82F6),
              surface: Color(0xFF1E293B),
            ),
          ),
          routerConfig: router,
          builder: (context, widget) {
            return OfflineWrapper(
              child: widget!,
            );
          },
        );
      },
    );
  }
}