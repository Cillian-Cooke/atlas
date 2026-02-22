import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Mark a post as seen by the current user
  /// Stores in subcollection: users/{userId}/seenPosts/{postId}
  /// This operation is idempotent - calling multiple times has the same effect as calling once
  /// If unseenPostsOnly filter is enabled, this post will NEVER appear again
  /// Uses server timestamp to track when the post was viewed
  Future<void> markPostAsSeen(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('seenPosts')
          .doc(postId)
          .set({
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge to avoid overwriting other fields
    } catch (e) {
      print('Error marking post as seen: $e');
    }
  }

  /// Get all seen post IDs for the current user (cached for session)
  /// Returns a snapshot of currently seen post IDs
  /// Used for strict filtering - if a postId is in this list, it WILL NOT appear when unseenPostsOnly is enabled
  Future<List<String>> getSeenPostIds() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('seenPosts')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('Error getting seen post IDs: $e');
      return [];
    }
  }

  /// Get stream of seen post IDs for real-time updates
  /// Reactive stream that updates immediately when new posts are marked as seen
  /// This enables responsive UI updates when unseenPostsOnly filter is enabled
  Stream<List<String>> getSeenPostIdsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('seenPosts')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());
  }

  /// Get the unseenPostsOnly toggle status for current user
  Future<bool> getUnseenPostsOnlyFlag() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['unseenPostsOnly'] ?? false;
    } catch (e) {
      print('Error getting unseenPostsOnly flag: $e');
      return false;
    }
  }

  /// Stream of unseenPostsOnly toggle status
  Stream<bool> getUnseenPostsOnlyStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data()?['unseenPostsOnly'] ?? false);
  }

  /// Toggle the unseenPostsOnly flag
  Future<void> setUnseenPostsOnly(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'unseenPostsOnly': value,
      });
    } catch (e) {
      print('Error toggling unseenPostsOnly: $e');
    }
  }

  /// Clear all seen posts for current user (optional cleanup)
  Future<void> clearAllSeenPosts() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final seenPostsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('seenPosts');

      final docs = await seenPostsRef.get();
      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing seen posts: $e');
    }
  }

  /// Clear seen posts older than specified days (for cleanup)
  Future<void> clearOldSeenPosts(int daysOld) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final cutoffDate =
          Timestamp.fromDate(DateTime.now().subtract(Duration(days: daysOld)));

      final seenPostsRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('seenPosts');

      final docs = await seenPostsRef.where('viewedAt', isLessThan: cutoffDate).get();

      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Error clearing old seen posts: $e');
    }
  }

  /// Get the roguePostsEnabled toggle status for current user
  Future<bool> getRoguePostsEnabledFlag() async {
    final user = _auth.currentUser;
    if (user == null) return true;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['roguePostsEnabled'] ?? true;
    } catch (e) {
      print('Error getting roguePostsEnabled flag: $e');
      return true;
    }
  }

  /// Stream of roguePostsEnabled toggle status
  Stream<bool> getRoguePostsEnabledStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(true);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data()?['roguePostsEnabled'] ?? true);
  }

  /// Toggle the roguePostsEnabled flag
  Future<void> setRoguePostsEnabled(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'roguePostsEnabled': value,
      });
    } catch (e) {
      print('Error toggling roguePostsEnabled: $e');
    }
  }
}
