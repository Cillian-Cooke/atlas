import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atlas/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firestore connectivity (web) - read user document', (tester) async {
    const userId = 'j0z95zXEUee1jHqRaAmh';

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      fail('Firebase.initializeApp() failed: $e');
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (!doc.exists) {
        fail('Document does not exist for id $userId. This may mean the document is missing or rules deny access.');
      }

      // Log the data so it appears in test output for debugging.
      print('Document exists. Data: ${doc.data()}');
    } on FirebaseException catch (e) {
      fail('Firestore read failed: ${e.code} - ${e.message}');
    } catch (e) {
      fail('Unexpected error during Firestore read: $e');
    }
  }, timeout: Timeout(Duration(seconds: 30)));
}
