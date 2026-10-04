import 'package:flutter/foundation.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../core/services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository authRepository;
  final FirebaseService _firebaseService = FirebaseService();

  UserProfile? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  AuthProvider({required this.authRepository}) {
    _initUser();
  }

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && !_user!.isGuest;
  bool get isGuest => _user != null && _user!.isGuest;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> _initUser() async {
    _user = await authRepository.getCurrentUser();
    notifyListeners();
  }

  Future<void> checkAuthStatus() => _initUser();
  Future<void> refreshUser() => _initUser();

  Future<void> signInAsGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await authRepository.signInAsGuest();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _user = await authRepository.signInWithGoogle();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      _user = await authRepository.signInWithEmail(email, password);
      _successMessage = 'Signed in successfully!';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerWithEmail(
      String email, String password, String name) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      _user = await authRepository.registerWithEmail(email, password, name);
      _successMessage = 'Account created successfully!';
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final success = await _firebaseService.sendPasswordReset(email);
      if (success) {
        _successMessage = 'Password reset instructions sent to $email';
        return true;
      } else {
        _errorMessage =
            'Could not send password reset email. Please verify the email.';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to reset password: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    _user = await authRepository.getCurrentUser();
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
