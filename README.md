# FlowBoard 🌊 - Mobile Client (Flutter)

This is the mobile frontend for FlowBoard, an offline-first Kanban task management application. It is built to function 100% independently of network availability, relying on a robust local SQLite database as the absolute source of truth.


## 🏗️ Client Architecture

This app rejects the "network-first" approach. Every read and write operation interacts strictly with the local database to ensure zero latency and zero data loss.

### 1. Local Database (Drift)
We use **Drift (SQLite)** instead of NoSQL alternatives (like Hive) to maintain strict relational data integrity.
* **Foreign Keys:** Enforced at the SQLite level (`PRAGMA foreign_keys = ON`) cascading from Boards → Columns → Tasks.
* **Optimistic UI:** User mutations are instantly written to Drift. The UI, observing Riverpod streams, reacts immediately without waiting for network callbacks.

### 2. The Sync Engine (Transactional Outbox)
* **SyncQueue Table:** Every local mutation generates a `SyncQueueEntry` in the same SQL transaction, marked as `PENDING`.
* **Background Worker:** A background `SyncService` listens to `connectivity_plus`. When the device comes online, it batches `PENDING` queue items and transmits them to the Node.js API.
* **Resilience:** Failed syncs auto-increment a retry counter. After 5 failures, they are marked `FAILED` for manual user retry via the Sync Status Panel.

### 3. State Management (Riverpod)
The app uses **Riverpod 3.0** for reactive dependency injection and state management.
* UI components simply watch `StreamProviders` connected to Drift.
* `AsyncNotifier` is used for authentication flows to gracefully handle loading and error states.

## ✨ Key Features
- **Drag-and-Drop Kanban:** Powered by `appflowy_board` for fluid task movement.
- **Manual Conflict Resolution:** If the server rejects a sync due to a timestamp conflict, the app intercepts the server's payload and presents a side-by-side "Keep Mine vs. Use Cloud" UI.
- **Tabular Audit Log:** Parses raw JSON payloads from the SyncQueue to display precise UTC timestamps and mutation fields.

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.19+)
* Dart SDK

### Installation

1. Install dependencies:
   ```bash
   flutter pub 
2. Generate Drift Database files
   ```bash
    flutter pub run build_runner build --delete-conflicting-outputs

3. Open lib/core/network/api_client.dart and ensure the baseUrl matches your local Node.js server (e.g., http://10.0.2.2:3000/api for Android Emulator, or 127.0.0.1 for iOS).



4. ```bash
   flutter run