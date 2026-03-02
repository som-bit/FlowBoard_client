import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database.dart'; // Ensure this points to your database.dart file

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});