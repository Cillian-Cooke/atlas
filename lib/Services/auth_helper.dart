import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'auth_provider.dart' as auth_provider;

/// Helper class to easily access authenticated user information
class AuthHelper {
  /// Get current user ID from context
  static String? getUserId(BuildContext context) {
    return context.read<auth_provider.AuthProvider>().userId;
  }

  /// Get current user object from context
  static User? getUser(BuildContext context) {
    return context.read<auth_provider.AuthProvider>().user;
  }

  /// Check if user is authenticated from context
  static bool isAuthenticated(BuildContext context) {
    return context.read<auth_provider.AuthProvider>().isAuthenticated;
  }

  /// Get current user ID without context (returns null if no user)
  static String? getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// Get current user object without context
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  /// Sign out current user
  static Future<void> signOut(BuildContext context) async {
    await context.read<auth_provider.AuthProvider>().signOut();
  }
}
