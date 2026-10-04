import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/firebase_config.dart';
import '../utils/logger.dart';

class FirebaseAuthResult {
  final bool isSuccess;
  final String uid;
  final String email;
  final String displayName;
  final String idToken;
  final String refreshToken;
  final String? errorMessage;

  const FirebaseAuthResult({
    required this.isSuccess,
    this.uid = '',
    this.email = '',
    this.displayName = '',
    this.idToken = '',
    this.refreshToken = '',
    this.errorMessage,
  });

  factory FirebaseAuthResult.success({
    required String uid,
    required String email,
    required String displayName,
    required String idToken,
    required String refreshToken,
  }) =>
      FirebaseAuthResult(
        isSuccess: true,
        uid: uid,
        email: email,
        displayName: displayName,
        idToken: idToken,
        refreshToken: refreshToken,
      );

  factory FirebaseAuthResult.failure(String errorMessage) => FirebaseAuthResult(
        isSuccess: false,
        errorMessage: errorMessage,
      );
}

class FirebaseService {
  final http.Client _client = http.Client();

  /// Sign Up with Email and Password using Firebase Auth REST API
  Future<FirebaseAuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return FirebaseAuthResult.failure('Please enter a valid email address.');
    }
    if (cleanPass.length < 6) {
      return FirebaseAuthResult.failure(
          'Password must be at least 6 characters.');
    }

    if (!FirebaseConfig.isConfigured) {
      // Local fallback mode when Firebase custom key is not yet set
      AppLogger.info(
          'Firebase key not configured. Using local offline auth account.');
      final localUid = 'firebase_user_${cleanEmail.hashCode.abs()}';
      final name = displayName != null && displayName.isNotEmpty
          ? displayName
          : cleanEmail.split('@').first;
      return FirebaseAuthResult.success(
        uid: localUid,
        email: cleanEmail,
        displayName: name,
        idToken: 'demo_token_$localUid',
        refreshToken: 'demo_refresh_$localUid',
      );
    }

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${FirebaseConfig.apiKey}',
    );

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': cleanPass,
          'returnSecureToken': true,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final idToken = data['idToken'] as String? ?? '';
        final uid = data['localId'] as String? ?? '';
        final tokenEmail = data['email'] as String? ?? cleanEmail;
        final refreshToken = data['refreshToken'] as String? ?? '';

        // If display name provided, update Firebase user profile
        String finalName = displayName ?? tokenEmail.split('@').first;
        if (displayName != null && displayName.isNotEmpty) {
          await _updateProfile(idToken: idToken, displayName: displayName);
        }

        // Save profile document in Cloud Firestore
        await saveUserProfile(
          uid: uid,
          idToken: idToken,
          name: finalName,
          email: tokenEmail,
        );

        return FirebaseAuthResult.success(
          uid: uid,
          email: tokenEmail,
          displayName: finalName,
          idToken: idToken,
          refreshToken: refreshToken,
        );
      } else {
        final error = data['error'] as Map<String, dynamic>?;
        final message = error?['message']?.toString() ?? 'Registration failed';
        return FirebaseAuthResult.failure(_mapFirebaseError(message));
      }
    } catch (e) {
      AppLogger.error('Firebase signUp error: $e');
      return FirebaseAuthResult.failure(
          'Connection error: Please check your internet connection.');
    }
  }

  /// Sign In with Email and Password using Firebase Auth REST API
  Future<FirebaseAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    final cleanPass = password.trim();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return FirebaseAuthResult.failure('Please enter a valid email address.');
    }
    if (cleanPass.isEmpty) {
      return FirebaseAuthResult.failure('Please enter your password.');
    }

    if (!FirebaseConfig.isConfigured) {
      AppLogger.info(
          'Firebase key not configured. Using local offline auth account.');
      final localUid = 'firebase_user_${cleanEmail.hashCode.abs()}';
      return FirebaseAuthResult.success(
        uid: localUid,
        email: cleanEmail,
        displayName: cleanEmail.split('@').first,
        idToken: 'demo_token_$localUid',
        refreshToken: 'demo_refresh_$localUid',
      );
    }

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${FirebaseConfig.apiKey}',
    );

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'password': cleanPass,
          'returnSecureToken': true,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final idToken = data['idToken'] as String? ?? '';
        final uid = data['localId'] as String? ?? '';
        final tokenEmail = data['email'] as String? ?? cleanEmail;
        final displayName = (data['displayName'] as String?)?.isNotEmpty == true
            ? data['displayName'] as String
            : tokenEmail.split('@').first;
        final refreshToken = data['refreshToken'] as String? ?? '';

        return FirebaseAuthResult.success(
          uid: uid,
          email: tokenEmail,
          displayName: displayName,
          idToken: idToken,
          refreshToken: refreshToken,
        );
      } else {
        final error = data['error'] as Map<String, dynamic>?;
        final message = error?['message']?.toString() ?? 'Login failed';
        return FirebaseAuthResult.failure(_mapFirebaseError(message));
      }
    } catch (e) {
      AppLogger.error('Firebase signIn error: $e');
      return FirebaseAuthResult.failure(
          'Connection error: Please check your internet connection.');
    }
  }

  /// Send Password Reset Email
  Future<bool> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) return false;

    if (!FirebaseConfig.isConfigured) {
      return true; // Local simulation
    }

    final url = Uri.parse(
      'https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${FirebaseConfig.apiKey}',
    );

    try {
      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requestType': 'PASSWORD_RESET',
          'email': cleanEmail,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Password reset error: $e');
      return false;
    }
  }

  /// Update Profile (Display Name / Photo URL)
  Future<void> _updateProfile({
    required String idToken,
    required String displayName,
  }) async {
    try {
      final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:update?key=${FirebaseConfig.apiKey}',
      );
      await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'displayName': displayName,
          'returnSecureToken': false,
        }),
      );
    } catch (e) {
      AppLogger.info('Failed to update display name on Firebase: $e');
    }
  }

  /// Save User Profile to Cloud Firestore Database
  Future<void> saveUserProfile({
    required String uid,
    required String idToken,
    required String name,
    required String email,
  }) async {
    if (!FirebaseConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents/users/$uid?key=${FirebaseConfig.apiKey}',
      );

      final payload = {
        'fields': {
          'uid': {'stringValue': uid},
          'name': {'stringValue': name},
          'email': {'stringValue': email},
          'updatedAt': {'stringValue': DateTime.now().toIso8601String()},
        }
      };

      await _client.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      AppLogger.info('Firestore save profile error: $e');
    }
  }

  /// Save / Sync user favorites or playlists to Firestore
  Future<void> syncUserDataToFirestore({
    required String uid,
    required String idToken,
    required Map<String, dynamic> data,
  }) async {
    if (!FirebaseConfig.isConfigured) return;

    try {
      final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/${FirebaseConfig.projectId}/databases/(default)/documents/userdata/$uid?key=${FirebaseConfig.apiKey}',
      );

      final payload = {
        'fields': {
          'data': {'stringValue': jsonEncode(data)},
          'lastSynced': {'stringValue': DateTime.now().toIso8601String()},
        }
      };

      await _client.patch(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );
    } catch (e) {
      AppLogger.info('Firestore sync user data error: $e');
    }
  }

  /// Translate Firebase error codes into friendly user messages
  String _mapFirebaseError(String code) {
    if (code.contains('EMAIL_EXISTS')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (code.contains('INVALID_EMAIL')) {
      return 'Invalid email address format.';
    }
    if (code.contains('WEAK_PASSWORD')) {
      return 'Password must be at least 6 characters.';
    }
    if (code.contains('EMAIL_NOT_FOUND') ||
        code.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Invalid email or password. Please check your credentials.';
    }
    if (code.contains('INVALID_PASSWORD')) {
      return 'Incorrect password. Please try again.';
    }
    if (code.contains('USER_DISABLED')) {
      return 'This user account has been disabled.';
    }
    if (code.contains('TOO_MANY_ATTEMPTS_TRY_LATER')) {
      return 'Too many failed login attempts. Please try again later.';
    }
    return 'Authentication error ($code). Please try again.';
  }
}
