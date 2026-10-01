import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:melody_tube/core/services/local_storage_service.dart';
import 'package:melody_tube/core/services/user_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  group('UserDatabaseService Table & Authentication Tests', () {
    test('Registers a new user into persistent table and retrieves it', () async {
      final user = await UserDatabaseService.registerUser(
        email: 'hasan@twilight.app',
        password: 'securePassword123',
        displayName: 'Hasan Dev',
      );

      expect(user['email'], equals('hasan@twilight.app'));
      expect(user['displayName'], equals('Hasan Dev'));
      expect(user['uid'], isNotEmpty);

      final found = UserDatabaseService.findUserByEmail('hasan@twilight.app');
      expect(found, isNotNull);
      expect(found!['email'], equals('hasan@twilight.app'));
    });

    test('Prevents duplicate registration for the same email', () async {
      await UserDatabaseService.registerUser(
        email: 'duplicate@twilight.app',
        password: 'password123',
        displayName: 'User 1',
      );

      expect(
        () => UserDatabaseService.registerUser(
          email: 'duplicate@twilight.app',
          password: 'password456',
          displayName: 'User 2',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Authenticates successfully when typed login info matches stored database info', () async {
      await UserDatabaseService.registerUser(
        email: 'login_test@twilight.app',
        password: 'mySecretPassword',
        displayName: 'Login Tester',
      );

      final authenticated = await UserDatabaseService.authenticateUser(
        email: 'login_test@twilight.app',
        password: 'mySecretPassword',
      );

      expect(authenticated['email'], equals('login_test@twilight.app'));
      expect(authenticated['displayName'], equals('Login Tester'));
    });

    test('Fails authentication when typed password does not match database record', () async {
      await UserDatabaseService.registerUser(
        email: 'wrong_pass@twilight.app',
        password: 'correctPassword',
        displayName: 'Wrong Pass User',
      );

      expect(
        () => UserDatabaseService.authenticateUser(
          email: 'wrong_pass@twilight.app',
          password: 'wrongPassword',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Updates user profile display name in database table', () async {
      final user = await UserDatabaseService.registerUser(
        email: 'profile_update@twilight.app',
        password: 'password123',
        displayName: 'Old Name',
      );

      await UserDatabaseService.updateProfile(
        uid: user['uid'] as String,
        displayName: 'New Awesome Name',
      );

      final updated = UserDatabaseService.findUserByUid(user['uid'] as String);
      expect(updated, isNotNull);
      expect(updated!['displayName'], equals('New Awesome Name'));
    });
  });
}
