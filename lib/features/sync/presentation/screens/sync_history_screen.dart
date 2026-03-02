import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../controllers/sync_controller.dart';

class SyncHistoryScreen extends ConsumerWidget {
  const SyncHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(activityFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          children: [
            Text(
              "Sync History",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "DETAILED TABULAR LOG",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 10.sp,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: historyAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
        error: (e, st) => Center(
          child: Text(
            "Error: $e",
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
        data: (queue) {
          if (queue.isEmpty) {
            return const Center(
              child: Text(
                "No sync history found.",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: const Color(0xFF1E293B), // Table border colors
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFF1E293B),
                  ),
                  dataRowMinHeight: 60.h,
                  dataRowMaxHeight: 80.h, // Increased height for more details
                  columns: const [
                    DataColumn(
                      label: Text(
                        "Queued At",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Entity",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Action",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Detailed Payload & Timestamps",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        "Status",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  rows: queue.map((item) {
                    final date = DateTime.parse(item.createdAt).toLocal();
                    final formattedDate = DateFormat(
                      'MMM dd, HH:mm:ss',
                    ).format(date);

                    final payload =
                        jsonDecode(item.payload) as Map<String, dynamic>;

                    // --- SMART ENTITY DEDUCTION ---
                    String entity = "Item"; // Better fallback than Unknown
                    if (item.operationType == 'DELETE') {
                      entity = "Deleted Item";
                    } else if (payload.containsKey('color')) {
                      entity = "Board";
                    } else if (payload.containsKey('boardId')) {
                      entity = "Column";
                    } else if (payload.containsKey('columnId') ||
                        payload.containsKey('priority') ||
                        payload.containsKey('dueDate') ||
                        payload.containsKey('description') ||
                        payload.containsKey('status')) {
                      entity = "Task";
                    } else if (payload.containsKey('position')) {
                      entity = "Task/Col Move";
                    } else if (payload.containsKey('title')) {
                      entity = "Rename";
                    }

                    // --- DETAILED PAYLOAD EXTRACTOR ---
                    List<String> detailsList = [];
                    if (payload.containsKey('title'))
                      detailsList.add("Title: '${payload['title']}'");
                    if (payload.containsKey('priority'))
                      detailsList.add("Priority: ${payload['priority']}");
                    if (payload.containsKey('status'))
                      detailsList.add("Status: ${payload['status']}");
                    if (payload.containsKey('position'))
                      detailsList.add("Pos: ${payload['position']}");

                    // Extract exact UTC timestamps from the payload
                    if (payload.containsKey('updatedAt')) {
                      try {
                        final dt = DateTime.parse(
                          payload['updatedAt'],
                        ).toLocal();
                        detailsList.add(
                          "TS: ${DateFormat('HH:mm:ss.SSS').format(dt)}",
                        );
                      } catch (_) {}
                    }

                    String snippet = detailsList.join('\n');

                    // Ultimate Fallback: just list the keys that were modified
                    if (snippet.isEmpty) {
                      final keys = payload.keys
                          .where((k) => k != 'id' && k != '_id')
                          .toList();
                      snippet = keys.isNotEmpty
                          ? "Updated fields: ${keys.join(', ')}"
                          : "ID: ${item.entityId.substring(0, 8)}...";
                    }

                    // Determine Status Color
                    Color statusColor;
                    switch (item.status) {
                      case 'SYNCED':
                        statusColor = Colors.green;
                        break;
                      case 'PENDING':
                        statusColor = Colors.orangeAccent;
                        break;
                      case 'FAILED':
                        statusColor = Colors.redAccent;
                        break;
                      case 'SYNCING':
                        statusColor = Colors.blueAccent;
                        break;
                      default:
                        statusColor = Colors.grey;
                    }

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              entity,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            item.operationType,
                            style: TextStyle(
                              color: item.operationType == 'DELETE'
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            width: 220.w, // Give it plenty of room
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Text(
                              snippet,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 11.sp,
                                height: 1.4,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.status == 'SYNCED'
                                    ? Icons.check_circle
                                    : item.status == 'FAILED'
                                    ? Icons.error
                                    : Icons.sync,
                                color: statusColor,
                                size: 14.sp,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                item.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
