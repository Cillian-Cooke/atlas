import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ThemeService {
  static Stream<bool> getDarkModeStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(false);
    }
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data() as Map<String, dynamic>;
            return data['darkMode'] as bool? ?? false;
          }
          return false;
        });
  }

  static bool getDarkModeFromTheme(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
