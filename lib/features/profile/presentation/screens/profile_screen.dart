import 'package:client/features/auth/presentation/controllers/auth_controller.dart';
import 'package:client/features/auth/presentation/screens/login_screen.dart';
import 'package:client/features/sync/presentation/controllers/sync_controller.dart';
import 'package:client/features/sync/presentation/screens/sync_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // THE RIGHT WAY: Trigger the API call to get real user details on load
    Future.microtask(() {
      ref.read(authControllerProvider.notifier).fetchUserDetails();
    });
  }

  // --- SAFE LOGOUT EXECUTION ---
  Future<void> _performLogout() async {
    debugPrint("👆 UI Interaction: Executing Logout Sequence...");
    // await ref.read(syncServiceProvider).wipeLocalDataOnLogout();
    await ref.read(authControllerProvider.notifier).logout();

    if (mounted) {
      // THE FIX: Use MaterialPageRoute instead of pushNamed
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ), // Ensure you import your LoginScreen
        (route) => false,
      );
    }
  }

  // --- LOGOUT HANDLER WITH WARNING ---
  void _handleLogout(bool hasPendingChanges) {
    if (hasPendingChanges) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
              ),
              SizedBox(width: 8.w),
              const Text(
                'Unsynced Changes',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'You have offline changes that haven\'t been saved to the cloud. Logging out will permanently delete these changes.\n\nAre you sure you want to log out?',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.2),
                foregroundColor: Colors.redAccent,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                _performLogout();
              },
              child: const Text(
                'Logout Anyway',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else {
      _performLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch pending sync items
    final pendingSyncAsyncValue = ref.watch(syncQueueProvider);
    final hasPendingItems = pendingSyncAsyncValue.maybeWhen(
      data: (queue) => queue.isNotEmpty,
      orElse: () => false,
    );

    // Watch the auth state for user data
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: authState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: const TextStyle(color: Colors.red)),
        ),
        data: (user) {
          // Dynamic data from AuthController
          final userName = user?.name ?? 'User';
          final userEmail = user?.email ?? 'FlowBoard Member';
          final userInitial = userName.isNotEmpty
              ? userName[0].toUpperCase()
              : 'U';

          return Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                SizedBox(height: 20.h),
                // Profile Avatar & Info
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50.r,
                        backgroundColor: const Color(
                          0xFF3B82F6,
                        ).withOpacity(0.2),
                        child: Text(
                          userInitial,
                          style: TextStyle(
                            color: const Color(0xFF3B82F6),
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        userName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        userEmail,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 48.h),

                // Navigation Options
                _buildMenuTile(
                  icon: Icons.history_edu,
                  title: "Detailed Sync History",
                  subtitle: "View tabular audit log of all operations",
                  iconColor: Colors.purpleAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SyncHistoryScreen(),
                    ),
                  ),
                ),

                const Spacer(),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      side: const BorderSide(color: Colors.redAccent),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: Text(
                      "Log Out",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => _handleLogout(hasPendingItems),
                  ),
                ),
                SizedBox(height: 24.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      tileColor: const Color(0xFF1E293B),
      leading: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12.sp),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }
}
