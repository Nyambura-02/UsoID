import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uso_id/core/services/firestore_service.dart';

final offlineSyncServiceProvider = Provider<OfflineSyncService>(
  (ref) => OfflineSyncService(ref.read(firestoreServiceProvider)),
);

/// Queues attendance scans when offline and syncs when connectivity returns
class OfflineSyncService {
  final FirestoreService _firestoreService;
  final Box _offlineBox = Hive.box('offline_scans');

  OfflineSyncService(this._firestoreService);

  /// Queue an attendance mark for offline sync
  Future<void> queueAttendanceMark({
    required String sessionId,
    required String schoolId,
    required double confidence,
  }) async {
    final key = '${sessionId}_$schoolId';
    await _offlineBox.put(key, jsonEncode({
      'session_id': sessionId,
      'school_id': schoolId,
      'confidence': confidence,
      'queued_at': DateTime.now().toIso8601String(),
    }));
  }

  /// Get count of pending offline scans
  int get pendingCount => _offlineBox.length;

  /// Sync all queued scans to Firestore
  Future<SyncResult> syncAll() async {
    int synced = 0;
    int failed = 0;
    final keys = _offlineBox.keys.toList();

    for (final key in keys) {
      try {
        final raw = _offlineBox.get(key) as String;
        final data = jsonDecode(raw) as Map<String, dynamic>;

        // Check if already marked
        final alreadyMarked = await _firestoreService.isStudentMarked(
          data['session_id'],
          data['school_id'],
        );

        if (!alreadyMarked) {
          await _firestoreService.markPresent(
            sessionId: data['session_id'],
            schoolId: data['school_id'],
            confidence: data['confidence'],
          );
        }

        await _offlineBox.delete(key);
        synced++;
      } catch (e) {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }

  /// Clear all queued scans (use with caution)
  Future<void> clearQueue() async {
    await _offlineBox.clear();
  }
}

class SyncResult {
  final int synced;
  final int failed;

  const SyncResult({required this.synced, required this.failed});

  bool get hasFailures => failed > 0;
  int get total => synced + failed;
}
