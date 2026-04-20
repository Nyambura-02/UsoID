import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:uso_id/core/services/face_recognition_service.dart';
import 'package:uso_id/core/services/firestore_service.dart';
import 'package:uso_id/core/services/offline_sync_service.dart';
import 'package:uso_id/core/models/attendance_session.dart';
import 'package:uso_id/core/theme/app_theme.dart';

class ScanAttendanceScreen extends ConsumerStatefulWidget {
  final String courseCode;
  const ScanAttendanceScreen({super.key, required this.courseCode});

  @override
  ConsumerState<ScanAttendanceScreen> createState() =>
      _ScanAttendanceScreenState();
}

class _ScanAttendanceScreenState extends ConsumerState<ScanAttendanceScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _cameraReady = false;
  bool _isScanning = false;
  bool _sessionActive = false;
  String? _sessionId;
  String? _lastResult;
  ScanStatus _scanStatus = ScanStatus.idle;

  final List<_ScanEvent> _scanLog = [];
  StreamSubscription? _attendanceSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _camera?.stopImageStream();
    } else if (state == AppLifecycleState.resumed && _sessionActive) {
      _startCameraStream();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _camera = CameraController(
        frontCam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _camera!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _startSession() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    final sessionId = await firestoreService.createAttendanceSession(
      courseCode: widget.courseCode,
    );

    setState(() {
      _sessionId = sessionId;
      _sessionActive = true;
      _scanStatus = ScanStatus.scanning;
    });

    _startCameraStream();

    // Live attendance feed
    _attendanceSub = firestoreService
        .watchSessionAttendance(sessionId)
        .listen((records) {
      setState(() {});
    });
  }

  void _startCameraStream() {
    _camera?.startImageStream((image) async {
      if (_isScanning || !_sessionActive || _sessionId == null) return;
      _isScanning = true;

      try {
        final recognitionService = ref.read(faceRecognitionServiceProvider);
        final result = await recognitionService.processFrame(image);

        if (result != null && result.confidence >= 0.7) {
          await _markAttendance(result.schoolId, result.confidence);
        }
      } finally {
        _isScanning = false;
      }
    });
  }

  Future<void> _markAttendance(String schoolId, double confidence) async {
    final firestoreService = ref.read(firestoreServiceProvider);

    try {
      final alreadyMarked = await firestoreService.isStudentMarked(
          _sessionId!, schoolId);

      if (alreadyMarked) return;

      await firestoreService.markPresent(
        sessionId: _sessionId!,
        schoolId: schoolId,
        confidence: confidence,
      );

      if (mounted) {
        setState(() {
          _lastResult = schoolId;
          _scanLog.insert(
            0,
            _ScanEvent(
              schoolId: schoolId,
              confidence: confidence,
              time: DateTime.now(),
              success: true,
            ),
          );
          _scanStatus = ScanStatus.success;
        });

        // Reset status after a moment
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _sessionActive) {
            setState(() => _scanStatus = ScanStatus.scanning);
          }
        });
      }
    } catch (e) {
      // Queue for offline sync
      final offlineSync = ref.read(offlineSyncServiceProvider);
      await offlineSync.queueAttendanceMark(
        sessionId: _sessionId!,
        schoolId: schoolId,
        confidence: confidence,
      );
    }
  }

  Future<void> _endSession() async {
    _camera?.stopImageStream();
    _attendanceSub?.cancel();

    final firestoreService = ref.read(firestoreServiceProvider);
    if (_sessionId != null) {
      await firestoreService.closeSession(_sessionId!);
    }

    // Sync offline scans
    final offlineSync = ref.read(offlineSyncServiceProvider);
    if (offlineSync.pendingCount > 0) {
      await offlineSync.syncAll();
    }

    setState(() {
      _sessionActive = false;
      _scanStatus = ScanStatus.idle;
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Session Ended'),
          content: Text(
            'Marked ${_scanLog.length} student(s) present.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    _attendanceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${widget.courseCode} — Attendance'),
        actions: [
          if (_sessionActive)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppTheme.danger.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_cameraReady && _camera != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: CameraPreview(_camera!),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // Face overlay
                if (_sessionActive)
                  Center(
                    child: _FaceOverlay(status: _scanStatus),
                  ),

                // Scan status indicator
                if (_scanStatus == ScanStatus.success && _lastResult != null)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '✓ $_lastResult marked present',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom panel
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                children: [
                  // Attendance log
                  Expanded(
                    child: _scanLog.isEmpty
                        ? const Center(
                            child: Text(
                              'No scans yet',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _scanLog.length,
                            itemBuilder: (context, index) {
                              final event = _scanLog[index];
                              return _ScanLogTile(event: event);
                            },
                          ),
                  ),

                  // Action button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _sessionActive
                          ? ElevatedButton.icon(
                              onPressed: _endSession,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: Text(
                                  'End Session  (${_scanLog.length} marked)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.danger,
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed:
                                  _cameraReady ? _startSession : null,
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('Start Attendance Session'),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──

enum ScanStatus { idle, scanning, success, failure }

class _FaceOverlay extends StatefulWidget {
  final ScanStatus status;
  const _FaceOverlay({required this.status});

  @override
  State<_FaceOverlay> createState() => _FaceOverlayState();
}

class _FaceOverlayState extends State<_FaceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _borderColor {
    switch (widget.status) {
      case ScanStatus.scanning:
        return Colors.white54;
      case ScanStatus.success:
        return AppTheme.success;
      case ScanStatus.failure:
        return AppTheme.danger;
      case ScanStatus.idle:
        return Colors.white30;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 200,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor, width: 2.5),
          borderRadius: BorderRadius.circular(120),
        ),
      ),
    );
  }
}

class _ScanEvent {
  final String schoolId;
  final double confidence;
  final DateTime time;
  final bool success;

  const _ScanEvent({
    required this.schoolId,
    required this.confidence,
    required this.time,
    required this.success,
  });
}

class _ScanLogTile extends StatelessWidget {
  final _ScanEvent event;
  const _ScanLogTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            event.success ? Icons.check_circle : Icons.cancel,
            color:
                event.success ? AppTheme.success : AppTheme.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.schoolId,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            '${(event.confidence * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTime(event.time),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
