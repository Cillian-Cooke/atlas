import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user from Firebase Auth
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in with Google and create/update user document in Firestore
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleSignInAccount =
          await _googleSignIn.signIn();

      if (googleSignInAccount == null) {
        // User cancelled the sign-in
        return null;
      }

      // Get authentication details
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      // Sign in to Firebase with Google credentials
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        // Create or update user document in Firestore
        await _createOrUpdateUserDocument(user);
      }

      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  /// Create user document if it doesn't exist
  Future<void> _createOrUpdateUserDocument(User user) async {
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // Create new user document with basic info from Google
        await userDoc.set({
          'uid': user.uid,
          'email': user.email,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'darkMode': false,
          // Username will be set during registration flow
          'username': null,
          'bio': null,
          'followers': [],
          'following': [],
          'groups': [],
          // Seen posts feature
          'unseenPostsOnly': false,
          // Rogue posts feature
          'roguePostsEnabled': true,
        });
        print('✅ NEW ACCOUNT CREATED in Firestore for user: ${user.uid}');
      } else {
        // Update existing user
        await userDoc.update({
          'updatedAt': FieldValue.serverTimestamp(),
          'photoURL': user.photoURL,
        });
        print('✅ EXISTING ACCOUNT UPDATED for user: ${user.uid}');
      }
    } catch (e) {
      print('❌ ERROR creating/updating user document: $e');
      rethrow;
    }
  }

  /// Update user profile with username and other details
  Future<bool> updateUserProfile({
    required String username,
    String? bio,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        print('❌ PROFILE UPDATE FAILED: No authenticated user');
        return false;
      }

      await _firestore.collection('users').doc(user.uid).update({
        'username': username,
        'bio': bio ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ PROFILE COMPLETED for user: ${user.uid} with username: $username');
      return true;
    } catch (e) {
      print('❌ ERROR updating user profile: $e');
      return false;
    }
  }

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Stream of user data from Firestore
  Stream<DocumentSnapshot> getUserDataStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Check if username is available
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      print('Error checking username availability: $e');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Check if user has completed profile setup
  Future<bool> hasCompletedProfile() async {
    try {
      final user = currentUser;
      if (user == null) {
        print('❌ PROFILE CHECK: No authenticated user');
        return false;
      }

      final userData = await getUserData(user.uid);
      if (userData == null) {
        print('❌ PROFILE CHECK: No user data found for ${user.uid}');
        return false;
      }

      final username = userData['username'];
      final isComplete = username != null && username.toString().isNotEmpty;
      
      if (isComplete) {
        print('✅ PROFILE COMPLETE: User ${user.uid} has username: $username');
      } else {
        print('⚠️  PROFILE INCOMPLETE: User ${user.uid} needs to complete registration');
      }
      
      return isComplete;
    } catch (e) {
      print('❌ ERROR checking profile completion: $e');
      return false;
    }
  }
}
