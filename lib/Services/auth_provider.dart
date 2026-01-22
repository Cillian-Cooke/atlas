import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize authentication stream
  void _initializeAuth() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        _user = user;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Sign in was cancelled';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
      _user = null;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    required String username,
    String? bio,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.updateUserProfile(
        username: username,
        bio: bio,
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Check if user has completed profile
  Future<bool> hasCompletedProfile() async {
    return await _authService.hasCompletedProfile();
  }

  /// Check username availability
  Future<bool> isUsernameAvailable(String username) async {
    return await _authService.isUsernameAvailable(username);
  }
}
