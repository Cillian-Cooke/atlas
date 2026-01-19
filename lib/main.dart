/*
make sure what you have changed has been saved then run

flutter clean
flutter run -d chrome

*/

import 'package:atlas/Widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // TODO: Replace with actual user ID logic
  static const String userId = "I8PwtNA3QTEt44rxH8jN";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        bool darkMode = false;
        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['darkMode'] is bool) {
            darkMode = data['darkMode'];
          }
        }
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: darkMode ? Colors.black : Colors.white,
          statusBarIconBrightness: darkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: darkMode ? Brightness.dark : Brightness.light,
        ));
        return MaterialApp(
          title: 'Flutter Demo',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 255, 255, 255),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 255, 255, 255),
              brightness: Brightness.dark,
            ),
          ),
          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const MyNavigatorBar(title: 'Navigation Bar'),
        );
      },
    );
  }
}