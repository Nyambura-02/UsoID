import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uso_id/core/models/app_user.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;

  final authService = ref.read(authServiceProvider);
  return authService.getCurrentUser();
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw Exception('Sign in failed: no user returned');
      }

      final user = await getCurrentUser();
      if (user == null) {
        throw Exception('User profile not found');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  /// Get current user's profile from Firestore
  Future<AppUser?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    // Get custom claims to determine role
    final idTokenResult = await firebaseUser.getIdTokenResult();
    final role = idTokenResult.claims?['role'] as String?;

    if (role == null) {
      throw Exception('User role not set. Contact administrator.');
    }

    // Fetch profile based on role
    String collection;
    switch (role) {
      case 'admin':
      case 'lecturer':
        collection = '${role}s'; // admins or lecturers
        final doc = await _firestore.collection(collection).doc(firebaseUser.uid).get();
        if (!doc.exists) {
          throw Exception('User profile not found in $collection');
        }
        return AppUser.fromFirestore(doc);

      case 'student':
        // Students use school_id as document ID
        final query = await _firestore
            .collection('students')
            .where('email', isEqualTo: firebaseUser.email)
            .limit(1)
            .get();
        if (query.docs.isEmpty) {
          throw Exception('Student profile not found');
        }
        final doc = query.docs.first;
        final data = doc.data();
        return AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          fullName: data['full_name'] ?? '',
          role: UserRole.student,
          department: data['department'],
          schoolId: doc.id,
          createdAt: (data['created_at'] as Timestamp).toDate(),
        );

      default:
        throw Exception('Unknown role: $role');
    }
  }

  /// Get user role from custom claims
  Future<UserRole?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final idTokenResult = await user.getIdTokenResult();
    final role = idTokenResult.claims?['role'] as String?;

    if (role == null) return null;

    return UserRole.values.firstWhere(
      (r) => r.name == role,
      orElse: () => UserRole.student,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Map Firebase auth exceptions to user-friendly messages
  Exception _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email.');
      case 'wrong-password':
        return Exception('Incorrect password. Please try again.');
      case 'user-disabled':
        return Exception('This account has been disabled. Contact admin.');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later.');
      case 'network-request-failed':
        return Exception('Network error. Check your internet connection.');
      default:
        return Exception('Authentication error: ${e.message}');
    }
  }
}
