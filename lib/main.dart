/*
make sure what you have changed has been saved then run

flutter clean
flutter run -d chrome

*/

import 'package:atlas/Pages/login_page.dart';
import 'package:atlas/Services/auth_provider.dart';
import 'package:atlas/Widgets/bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.userId;

        return StreamBuilder<DocumentSnapshot?>(
          stream: userId != null
              ? FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots()
              : Stream.value(null),
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
              statusBarIconBrightness:
                  darkMode ? Brightness.light : Brightness.dark,
              statusBarBrightness:
                  darkMode ? Brightness.dark : Brightness.light,
            ));
            return MaterialApp(
              title: 'Atlas',
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
              home: authProvider.isAuthenticated
                  ? const MyNavigatorBar(title: 'Navigation Bar')
                  : LoginScreen(onLoginSuccess: () {}),
            );
          },
        );
      },
    );
  }
}