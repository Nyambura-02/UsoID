import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uso_id/core/models/student.dart';
import 'package:uso_id/core/services/firestore_service.dart';

final faceRecognitionServiceProvider = Provider<FaceRecognitionService>(
  (ref) => FaceRecognitionService(ref.read(firestoreServiceProvider)),
);

class FaceRecognitionService {
  final FirestoreService _firestoreService;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  FaceRecognitionService(this._firestoreService);

  /// Extract face embedding from image bytes via Cloud Function
  /// Returns a 128-dimensional vector
  Future<List<double>> extractEmbedding(Uint8List imageBytes) async {
    try {
      final callable = _functions.httpsCallable(
        'extractFaceEmbedding',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      // Send image as base64
      final base64Image = _uint8ListToBase64(imageBytes);

      final result = await callable.call({
        'image': base64Image,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Failed to extract face embedding');
      }

      return List<double>.from(data['embedding']);
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Face extraction error: ${e.message}');
    }
  }

  /// Enroll a student's face
  Future<void> enrollFace({
    required String schoolId,
    required Uint8List imageBytes,
  }) async {
    final embedding = await extractEmbedding(imageBytes);
    await _firestoreService.enrollStudentFace(schoolId, embedding);
  }

  /// Match a face against registered students in a unit
  /// Returns the best match or null if no match found
  Future<MatchResult?> matchFace({
    required Uint8List imageBytes,
    required List<String> registeredStudentIds,
    double threshold = 0.6,
  }) async {
    // 1. Extract embedding from the captured frame
    final queryEmbedding = await extractEmbedding(imageBytes);

    // 2. Fetch enrolled students' embeddings
    double bestDistance = double.infinity;
    String? bestMatchId;

    for (final studentId in registeredStudentIds) {
      final student = await _firestoreService.getStudent(studentId);
      if (student == null || student.faceEmbedding == null) continue;

      final distance = _euclideanDistance(
        queryEmbedding,
        student.faceEmbedding!,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatchId = studentId;
      }
    }

    // 3. Check if best match meets threshold
    if (bestMatchId != null && bestDistance < threshold) {
      final student = await _firestoreService.getStudent(bestMatchId);
      if (student == null) return null;

      final confidence = _distanceToConfidence(bestDistance);
      return MatchResult(
        student: student,
        confidence: confidence,
        distance: bestDistance,
      );
    }

    return null;
  }

  /// Calculate Euclidean distance between two embedding vectors
  double _euclideanDistance(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw Exception(
          'Embedding dimension mismatch: ${a.length} vs ${b.length}');
    }

    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    return sqrt(sum);
  }

  /// Convert distance to a 0-1 confidence score
  /// Lower distance = higher confidence
  double _distanceToConfidence(double distance) {
    // Typical face_recognition distances: 0.0 (identical) to ~1.2 (different)
    // Threshold is usually 0.6
    return (1.0 - (distance / 1.2)).clamp(0.0, 1.0);
  }

  /// Convert Uint8List to base64 string
  String _uint8ListToBase64(Uint8List bytes) {
    return String.fromCharCodes(bytes);
  }
}

class MatchResult {
  final Student student;
  final double confidence;
  final double distance;

  const MatchResult({
    required this.student,
    required this.confidence,
    required this.distance,
  });

  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
  bool get isHighConfidence => confidence > 0.7;
}
