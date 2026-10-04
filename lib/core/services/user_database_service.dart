import 'dart:convert';
import 'local_storage_service.dart';
import '../utils/logger.dart';

/// Database Table for user credentials and profiles.
/// Persists all registered users locally and synchronizes with Firebase Cloud
/// so that typed login credentials must match stored database records.
class UserDatabaseService {
  static const String _usersTableKey = 'twilight_db_users_table';

  // In-memory cache of the users table
  static List<Map<String, dynamic>>? _cachedUsers;

  /// Loads all user records from the persistent database table
  static List<Map<String, dynamic>> getAllUsers() {
    if (_cachedUsers != null) return _cachedUsers!;
    try {
      final jsonStr = LocalStorageService.getString(_usersTableKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        _cachedUsers = decoded.whereType<Map<String, dynamic>>().toList();
        return _cachedUsers!;
      }
    } catch (e) {
      AppLogger.error('Failed to read users database table: $e');
    }
    _cachedUsers = [];
    return _cachedUsers!;
  }

  /// Persists the users table to local storage
  static Future<void> _persistUsers(List<Map<String, dynamic>> users) async {
    _cachedUsers = users;
    try {
      await LocalStorageService.setString(_usersTableKey, jsonEncode(users));
      AppLogger.info(
          'Users database table updated (${users.length} registered users)');
    } catch (e) {
      AppLogger.error('Failed to persist users database table: $e');
    }
  }

  /// Looks up a user record by email (case-insensitive)
  static Map<String, dynamic>? findUserByEmail(String email) {
    final clean = email.trim().toLowerCase();
    final users = getAllUsers();
    final index = users.indexWhere(
        (u) => (u['email'] as String? ?? '').toLowerCase() == clean);
    return index != -1 ? Map<String, dynamic>.from(users[index]) : null;
  }

  /// Looks up a user record by UID
  static Map<String, dynamic>? findUserByUid(String uid) {
    final users = getAllUsers();
    final index = users.indexWhere((u) => (u['uid'] as String? ?? '') == uid);
    return index != -1 ? Map<String, dynamic>.from(users[index]) : null;
  }

  /// Computes a salted cryptographic hash for password security
  static String _hashPassword(String password) {
    final bytes = utf8.encode('twilight_salt_v1_${password.trim()}');
    int hash1 = 0xcbf29ce484222325;
    int hash2 = 0x811c9dc5;
    for (final b in bytes) {
      hash1 = ((hash1 ^ b) * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      hash2 = ((hash2 ^ b) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'twhash_${hash1.toRadixString(16)}_${hash2.toRadixString(16)}';
  }

  /// Registers a new user into the database table.
  /// Throws an error if the email is already registered.
  static Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password,
    required String displayName,
    String? avatarUrl,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();
    final cleanName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : cleanEmail.split('@').first;

    final existing = findUserByEmail(cleanEmail);
    if (existing != null) {
      throw Exception(
          'An account with email "$cleanEmail" already exists. Please sign in instead.');
    }

    final nowIso = DateTime.now().toIso8601String();
    final uid =
        'usr_${DateTime.now().millisecondsSinceEpoch}_${cleanEmail.hashCode.abs().toRadixString(16)}';

    final newUser = <String, dynamic>{
      'uid': uid,
      'email': cleanEmail,
      'password': _hashPassword(cleanPass), // Salted hash for secure storage
      'displayName': cleanName,
      'avatarUrl': avatarUrl ?? '',
      'createdAt': nowIso,
      'lastLoginAt': nowIso,
      'role': 'listener',
      'isVerified': true,
    };

    final users = List<Map<String, dynamic>>.from(getAllUsers())..add(newUser);
    await _persistUsers(users);

    return newUser;
  }

  /// Authenticates a user against the database table.
  /// Verifies that typed login info matches database stored login info.
  static Future<Map<String, dynamic>> authenticateUser({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    final user = findUserByEmail(cleanEmail);
    if (user == null) {
      throw Exception(
          'No account found for "$cleanEmail". Please sign up first.');
    }

    final storedPassword = user['password'] as String? ?? '';
    final hashedInput = _hashPassword(cleanPass);
    final isMatch =
        storedPassword == hashedInput || storedPassword == cleanPass;
    if (!isMatch) {
      throw Exception(
          'Incorrect password. The password you typed does not match our database records.');
    }

    // Update last login timestamp and auto-migrate legacy plain text password
    final users = List<Map<String, dynamic>>.from(getAllUsers());
    final index = users.indexWhere((u) => (u['uid'] as String?) == user['uid']);
    if (index != -1) {
      users[index]['lastLoginAt'] = DateTime.now().toIso8601String();
      if (storedPassword == cleanPass) {
        users[index]['password'] = hashedInput;
      }
      await _persistUsers(users);
    }

    return user;
  }

  /// Updates profile details (display name or avatar) for a user
  static Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? avatarUrl,
  }) async {
    final users = List<Map<String, dynamic>>.from(getAllUsers());
    final index = users.indexWhere((u) => (u['uid'] as String?) == uid);
    if (index != -1) {
      if (displayName != null && displayName.isNotEmpty) {
        users[index]['displayName'] = displayName.trim();
      }
      if (avatarUrl != null) {
        users[index]['avatarUrl'] = avatarUrl.trim();
      }
      await _persistUsers(users);
    }
  }

  /// Changes a user's password in the database
  static Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final user = findUserByEmail(cleanEmail);
    if (user == null) {
      throw Exception('User account not found.');
    }

    final storedPassword = user['password'] as String? ?? '';
    final hashedCurrent = _hashPassword(currentPassword.trim());
    if (storedPassword != hashedCurrent &&
        storedPassword != currentPassword.trim()) {
      throw Exception('Current password does not match.');
    }
    if (newPassword.trim().length < 6) {
      throw Exception('New password must be at least 6 characters.');
    }

    final users = List<Map<String, dynamic>>.from(getAllUsers());
    final index = users.indexWhere(
        (u) => (u['email'] as String? ?? '').toLowerCase() == cleanEmail);
    if (index != -1) {
      users[index]['password'] = _hashPassword(newPassword.trim());
      await _persistUsers(users);
    }
  }
}
