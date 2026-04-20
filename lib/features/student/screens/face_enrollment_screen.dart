import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:uso_id/core/services/auth_service.dart';
import 'package:uso_id/core/services/face_recognition_service.dart';
import 'package:uso_id/core/theme/app_theme.dart';

enum _EnrollStep { instructions, capturing, processing, done, error }

class FaceEnrollmentScreen extends ConsumerStatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  ConsumerState<FaceEnrollmentScreen> createState() =>
      _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends ConsumerState<FaceEnrollmentScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _cameraReady = false;
  _EnrollStep _step = _EnrollStep.instructions;

  // Capture multiple angles
  final List<XFile> _captures = [];
  final int _requiredCaptures = 5;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
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
      );
      await _camera!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      setState(() {
        _step = _EnrollStep.error;
        _errorMessage = 'Camera initialisation failed: $e';
      });
    }
  }

  Future<void> _captureImage() async {
    if (!_cameraReady || _camera == null) return;
    setState(() => _step = _EnrollStep.capturing);

    try {
      final file = await _camera!.takePicture();
      _captures.add(file);

      if (_captures.length >= _requiredCaptures) {
        await _processAndSave();
      } else {
        setState(() => _step = _EnrollStep.capturing);
      }
    } catch (e) {
      setState(() {
        _step = _EnrollStep.error;
        _errorMessage = 'Capture failed: $e';
      });
    }
  }

  Future<void> _processAndSave() async {
    setState(() => _step = _EnrollStep.processing);

    try {
      final recognitionService = ref.read(faceRecognitionServiceProvider);
      final currentUser = await ref.read(currentUserProvider.future);

      if (currentUser == null) throw Exception('Not authenticated');

      final imagePaths = _captures.map((f) => f.path).toList();

      await recognitionService.enrollFace(
        schoolId: currentUser.schoolId ?? currentUser.uid,
        imagePaths: imagePaths,
      );

      setState(() => _step = _EnrollStep.done);
    } catch (e) {
      setState(() {
        _step = _EnrollStep.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _restart() {
    setState(() {
      _captures.clear();
      _step = _EnrollStep.instructions;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Face Enrollment'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: switch (_step) {
        _EnrollStep.instructions => _buildInstructions(context),
        _EnrollStep.capturing => _buildCapture(context),
        _EnrollStep.processing => _buildProcessing(context),
        _EnrollStep.done => _buildDone(context),
        _EnrollStep.error => _buildError(context),
      },
    );
  }

  Widget _buildInstructions(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Icon(Icons.face, color: AppTheme.primaryBlue, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Enroll Your Face',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'ll capture 5 photos from slightly different angles to build your face profile.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _InstructionTile(
            step: '1',
            title: 'Good lighting',
            subtitle: 'Make sure your face is well-lit, avoid backlighting.',
            icon: Icons.wb_sunny_outlined,
          ),
          _InstructionTile(
            step: '2',
            title: 'Clear view',
            subtitle:
                'Remove sunglasses and make sure your full face is visible.',
            icon: Icons.remove_red_eye_outlined,
          ),
          _InstructionTile(
            step: '3',
            title: 'Slight angle changes',
            subtitle:
                'We\'ll prompt you to slightly look left, right, up, and down.',
            icon: Icons.rotate_90_degrees_ccw_outlined,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _cameraReady ? _captureImage : null,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Start Enrollment'),
            style:
                ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ],
      ),
    );
  }

  Widget _buildCapture(BuildContext context) {
    final progress = _captures.length / _requiredCaptures;
    final prompts = [
      'Look straight at the camera',
      'Slightly turn left',
      'Slightly turn right',
      'Tilt slightly upward',
      'Tilt slightly downward',
    ];
    final prompt = _captures.length < prompts.length
        ? prompts[_captures.length]
        : 'Hold still';

    return Column(
      children: [
        if (_cameraReady && _camera != null)
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(0),
                  child: CameraPreview(_camera!),
                ),
                // Oval guide
                Center(
                  child: Container(
                    width: 180,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(110),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),

        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Photo ${_captures.length + 1} of $_requiredCaptures',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text('${(_captures.length / _requiredCaptures * 100).toInt()}%'),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.12),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(6),
                minHeight: 7,
              ),
              const SizedBox(height: 16),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _captureImage,
                icon: const Icon(Icons.camera),
                label: const Text('Capture'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Processing your face data…',
              style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text('This may take a moment.',
              style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Enrollment Complete!',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your face has been enrolled successfully. You\'ll now be recognised automatically during attendance sessions.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_rounded,
                  color: AppTheme.danger, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'Enrollment Failed',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionTile extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final IconData icon;

  const _InstructionTile({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(icon, color: AppTheme.primaryBlue, size: 20),
        ],
      ),
    );
  }
}
