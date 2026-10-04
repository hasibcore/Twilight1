import '../entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile> signInAsGuest();
  Future<UserProfile> signInWithGoogle();
  Future<UserProfile> signInWithEmail(String email, String password);
  Future<UserProfile> registerWithEmail(
      String email, String password, String name);
  Future<void> signOut();
  Future<UserProfile?> getCurrentUser();
}
