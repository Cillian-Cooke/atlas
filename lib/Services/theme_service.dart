import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ThemeService {
  static const String userId = "I8PwtNA3QTEt44rxH8jN";
  
  static Stream<bool> getDarkModeStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
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
