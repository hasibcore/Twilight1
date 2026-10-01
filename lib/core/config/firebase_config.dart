/// Firebase Configuration for Twilight Music
///
/// To connect your own Firebase project:
/// 1. Go to Firebase Console (https://console.firebase.google.com/)
/// 2. Create or select your project (e.g., "twilight-music")
/// 3. Go to Project Settings -> General -> "Web API Key" and "Project ID"
/// 4. Enable Authentication -> Sign-in method -> Email/Password
/// 5. Enable Firestore Database (or Realtime Database) in test/production mode
/// 6. Paste your apiKey and projectId below or in assets/config/app_config.json
class FirebaseConfig {
  /// Firebase Web / REST API Key
  static String apiKey = 'AIzaSyDemoTwilightKeyReplaceWithYours';

  /// Firebase Project ID
  static String projectId = 'twilight-music-prod';

  /// Firebase Auth Domain
  static String get authDomain => '$projectId.firebaseapp.com';

  /// Firebase Database URL
  static String get databaseURL => 'https://$projectId-default-rtdb.firebaseio.com';

  /// Firebase Storage Bucket
  static String get storageBucket => '$projectId.appspot.com';

  /// Check if the API key has been customized by the user
  static bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.contains('DemoTwilightKey');

  /// Initialize config from remote or app_config.json if available
  static void init({String? customApiKey, String? customProjectId}) {
    if (customApiKey != null && customApiKey.isNotEmpty) {
      apiKey = customApiKey;
    }
    if (customProjectId != null && customProjectId.isNotEmpty) {
      projectId = customProjectId;
    }
  }
}
