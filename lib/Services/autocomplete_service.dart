import 'package:cloud_firestore/cloud_firestore.dart';

class AutocompleteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Search for users by username (for @mentions)
  Future<List<String>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      // Query users where username starts with or contains the query
      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: query + 'z')
          .get();

      final usernames = querySnapshot.docs
          .map((doc) => doc.data()['username'] as String? ?? '')
          .where((username) => username.isNotEmpty)
          .toList();

      return usernames;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Get tags from posts (for #hashtags)
  Future<List<String>> searchTags(String query) async {
    if (query.isEmpty) return [];

    try {
      // Query all posts and extract tags that match the query
      final querySnapshot = await _firestore
          .collection('posts')
          .get();

      final tagsSet = <String>{};
      
      for (var doc in querySnapshot.docs) {
        final tags = doc.data()['tags'] as List? ?? [];
        for (var tag in tags) {
          final tagStr = tag.toString().toLowerCase();
          if (tagStr.contains(query.toLowerCase())) {
            tagsSet.add(tag.toString());
          }
        }
      }

      return tagsSet.toList();
    } catch (e) {
      print('Error searching tags: $e');
      return [];
    }
  }

  /// Get all usernames (for showing suggestions)
  Future<List<String>> getAllUsernames() async {
    try {
      final querySnapshot = await _firestore.collection('users').get();
      return querySnapshot.docs
          .map((doc) => doc.data()['username'] as String? ?? '')
          .where((username) => username.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error getting all usernames: $e');
      return [];
    }
  }

  /// Get all tags from posts
  Future<List<String>> getAllTags() async {
    try {
      final querySnapshot = await _firestore.collection('posts').get();
      final tagsSet = <String>{};

      for (var doc in querySnapshot.docs) {
        final tags = doc.data()['tags'] as List? ?? [];
        for (var tag in tags) {
          tagsSet.add(tag.toString());
        }
      }

      return tagsSet.toList();
    } catch (e) {
      print('Error getting all tags: $e');
      return [];
    }
  }
}
