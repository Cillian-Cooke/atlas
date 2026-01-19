import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:atlas/firebase_options.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Firestore connectivity: read user document', () async {
    // This test attempts to initialize Firebase and read the same document
    // your app reads. Run this locally; it will surface backend errors
    // (permission denied, unauthenticated, network issues) in the test output.

    // Use the same hard-coded id used in `HomeTab` for easier reproduction.
    const userId = 'j0z95zXEUee1jHqRaAmh';

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      fail('Firebase.initializeApp() failed: $e');
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      // Print to test logs so user sees the data when running tests.
      if (doc.exists) {
        // If exists, consider this a success but still log content.
        print('Document exists. Data: ${doc.data()}');
      } else {
        fail('Document does not exist for id $userId. doc.exists == false');
      }
    } on FirebaseException catch (e) {
      // Firebase-specific errors are most helpful.
      fail('Firestore read failed: ${e.code} - ${e.message}');
    } catch (e) {
      fail('Unexpected error during Firestore read: $e');
    }
  }, timeout: Timeout(Duration(seconds: 30)));
}
