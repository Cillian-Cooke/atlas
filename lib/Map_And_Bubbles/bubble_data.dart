import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Bubble model
class Bubble {
  Offset position; // position in map space (mutable for simulation)
  Offset velocity; // current velocity
  final double size; // diameter
  final Color color;
  final String tag; // optional label/tag for targeting
  final String postId; // Firestore document ID
  double driftPhase; // individual drift phase for passive movement

  Bubble({
    required this.position,
    required this.size,
    required this.color,
    this.tag = '',
    this.postId = '',
    Offset? velocity,
    this.driftPhase = 0.0,
  }) : velocity = velocity ?? Offset.zero;

  double get radius => size / 2;
}

/// Fetches bubbles from Firestore based on label filters
class FirestoreBubbleGenerator {
  final double mapWidth;
  final double mapHeight;
  final double minSize;
  final double maxSize;
  final List<String> labelTags; // Tags from label list
  final List<String> labelUsernames; // Usernames from label list
  final List<String> labelUserIDs; // UserIDs from label list

  FirestoreBubbleGenerator({
    required this.mapWidth,
    required this.mapHeight,
    required this.labelTags,
    this.labelUsernames = const [],
    this.labelUserIDs = const [],
    this.minSize = 15,
    this.maxSize = 150,
  });

  /// Fetch bubbles from Firestore 'posts' collection
  Future<List<Bubble>> fetchBubbles() async {
    final List<Bubble> bubbles = [];
    final List<int> likesCounts = [];
    final random = Random();

    try {
      // Query Firestore posts collection
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();

      // First pass: collect matching posts and their likes counts
      final List<Map<String, dynamic>> matchingPosts = [];
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final postId = doc.id;

        // Extract tags array from post
        final List<dynamic>? tagsData = data['tags'];
        final List<String> postTags = tagsData?.map((e) => e.toString()).toList() ?? [];

        // Extract username and userID from post
        final String? postUsername = data['username'];
        final String? postUserID = data['userID'];

        // Check if post matches any filter criteria
        bool matchesTag = postTags.any((tag) => labelTags.contains(tag));
        bool matchesUsername = postUsername != null && labelUsernames.contains(postUsername);
        bool matchesUserID = postUserID != null && labelUserIDs.contains(postUserID);

        if (matchesTag || matchesUsername || matchesUserID) {
          // Determine primary tag for attraction (priority: userID > username > tags)
          String primaryTag = '';
          int tagIndex = 0;
          
          if (matchesUserID && postUserID.isNotEmpty) {
            // Highest priority: userID
            primaryTag = postUserID;
            tagIndex = labelUserIDs.indexOf(postUserID);
          } else if (matchesUsername && postUsername.isNotEmpty) {
            // Second priority: username
            primaryTag = postUsername;
            tagIndex = labelUsernames.indexOf(postUsername);
          } else if (matchesTag) {
            // Lowest priority: tags
            primaryTag = postTags.firstWhere(
              (tag) => labelTags.contains(tag),
              orElse: () => postTags.isNotEmpty ? postTags.first : '',
            );
            tagIndex = labelTags.indexOf(primaryTag);
          }

          // Extract likes count (default to 0 if not present)
          final int likes = (data['likesCount'] as num?)?.toInt() ?? 0;
          likesCounts.add(likes);

          // Get color based on tag index
          final color = _colorForTagIndex(tagIndex >= 0 ? tagIndex : 0);

          matchingPosts.add({
            'postId': postId,
            'position': Offset(
              random.nextDouble() * mapWidth,
              random.nextDouble() * mapHeight,
            ),
            'color': color,
            'tag': primaryTag,
            'likes': likes,
            'driftPhase': random.nextDouble() * 2 * pi,
          });
        }
      }

      // Calculate relative sizes based on likes counts
      if (likesCounts.isNotEmpty) {
        final minLikes = likesCounts.reduce((a, b) => a < b ? a : b).toDouble();
        final maxLikes = likesCounts.reduce((a, b) => a > b ? a : b).toDouble();

        // Second pass: create bubbles with size based on relative likes
        for (final postData in matchingPosts) {
          final likes = postData['likes'].toDouble();
          final size = _calculateSizeFromLikes(likes, minLikes, maxLikes);

          bubbles.add(
            Bubble(
              position: postData['position'],
              size: size,
              color: postData['color'],
              tag: postData['tag'],
              postId: postData['postId'],
              driftPhase: postData['driftPhase'],
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching bubbles from Firestore: $e');
    }

    return bubbles;
  }

  /// Calculate bubble size based on relative likes count
  double _calculateSizeFromLikes(double likes, double minLikes, double maxLikes) {
    if (maxLikes == minLikes) {
      // If all posts have the same likes, use middle size
      return (minSize + maxSize) / 2;
    }
    // Normalize likes to 0-1 range, then scale to minSize-maxSize range
    final normalized = (likes - minLikes) / (maxLikes - minLikes);
    return minSize + (normalized * (maxSize - minSize));
  }

  Color _colorForTagIndex(int tagIndex) {
    const palette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
    ];
    return palette[tagIndex % palette.length];
  }
}



/// Convert bubbles → Positioned widgets for map objects
List<Widget> buildBubbleWidgets(List<Bubble> bubbles) {
  return bubbles.map((bubble) {
    return Positioned(
      left: bubble.position.dx,
      top: bubble.position.dy,
      child: Container(
        width: bubble.size,
        height: bubble.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bubble.color.withOpacity(0.65),
          border: Border.all(
            color: bubble.color,
            width: 5,
          ),
        ),
      ),
    );
  }).toList();
}

/// Calculate bubble size based on relative likes for a list of posts
/// Used by all map types to ensure consistent sizing logic
double calculateBubbleSizeFromLikes(
  int likes,
  List<int> allLikeCounts, {
  double minSize = 15,
  double maxSize = 150,
}) {
  if (allLikeCounts.isEmpty) return (minSize + maxSize) / 2;
  
  final minLikes = allLikeCounts.reduce((a, b) => a < b ? a : b).toDouble();
  final maxLikes = allLikeCounts.reduce((a, b) => a > b ? a : b).toDouble();
  
  if (maxLikes == minLikes) {
    return (minSize + maxSize) / 2;
  }
  
  final normalized = (likes - minLikes) / (maxLikes - minLikes);
  return minSize + (normalized * (maxSize - minSize));
}

/// Create bubbles from a list of post documents with consistent sizing logic
/// Used by all map types (home, user, group) to ensure uniform bubble creation
List<Map<String, dynamic>> createBubblesFromPosts(
  List<DocumentSnapshot<Map<String, dynamic>>> postDocs,
  List<String> baseLabelNames,
  double mapWidth,
  double mapHeight,
) {
  final List<int> allLikesCounts = [];
  final List<Map<String, dynamic>> postDataList = [];
  final random = Random();

  // First pass: collect likes counts and post data
  for (final postDoc in postDocs) {
    final postData = postDoc.data();
    if (postData == null) continue;
    final likes = (postData['likesCount'] as num?)?.toInt() ?? 0;
    allLikesCounts.add(likes);
    postDataList.add({
      'postId': postDoc.id,
      'data': postData,
      'likes': likes,
    });
  }

  // Second pass: create bubble data with calculated sizes
  final List<Map<String, dynamic>> bubbleDataList = [];
  
  for (final postInfo in postDataList) {
    try {
      final postId = postInfo['postId'];
      final postData = postInfo['data'] as Map<String, dynamic>;
      final likes = postInfo['likes'] as int;

      // Extract all relevant fields
      final List<dynamic>? tagsData = postData['tags'];
      final List<String> postTags =
          tagsData?.map((e) => e.toString()).toList() ?? [];
      final String? postUsername = postData['username'];
      final String? postUserID = postData['userID'];

      // Determine which label this post should be attracted to
      String primaryTag = '';

      // Priority: userID > username > tags (matching against baseLabelNames)
      if (postUserID != null && baseLabelNames.contains(postUserID)) {
        primaryTag = postUserID;
      } else if (postUsername != null && baseLabelNames.contains(postUsername)) {
        primaryTag = postUsername;
      } else {
        // Check if any post tag matches a label
        for (final tag in postTags) {
          if (baseLabelNames.contains(tag)) {
            primaryTag = tag;
            break;
          }
        }
      }

      // Get color and size based on likes
      final tagIndex = baseLabelNames.indexOf(primaryTag);
      // If no valid tag found, use grey; otherwise use color from palette
      final color = (primaryTag.isEmpty || tagIndex < 0)
          ? Colors.grey
          : _getColorFromTagIndex(tagIndex);
      final size = calculateBubbleSizeFromLikes(likes, allLikesCounts);

      bubbleDataList.add({
        'postId': postId,
        'color': color,
        'tag': primaryTag,
        'size': size,
        'x': random.nextDouble() * mapWidth,
        'y': random.nextDouble() * mapHeight,
      });
    } catch (e) {
      print('Error processing post: $e');
    }
  }

  return bubbleDataList;
}

Color _getColorFromTagIndex(int tagIndex) {
  const palette = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
  ];
  return palette[tagIndex % palette.length];
}