import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Reactive stream to monitor connectivity changes globally
final connectivityProvider = StreamProvider.autoDispose<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

class OfflineWrapper extends ConsumerWidget {
  final Widget child;
  const OfflineWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);
    
    // Determine if the device is currently disconnected 
    final isOffline = connectivityAsync.maybeWhen(
      data: (results) => results.contains(ConnectivityResult.none) || results.isEmpty,
      orElse: () => false,
    );

    return Column(
      children: [
        // The P1-Required Amber Offline Banner 
        if (isOffline)
          Material(
            color: Colors.amber, // Spec-mandated amber/yellow [cite: 488]
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, size: 16.sp, color: Colors.black87),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        "You're offline. Changes will sync when reconnected.",
                        style: TextStyle(
                          color: Colors.black87, 
                          fontSize: 12.sp, 
                          fontWeight: FontWeight.bold
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // The actual app screens live here
        Expanded(child: child),
      ],
    );
  }
}