import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Widgets/description_box.dart';
import '../PopUps/map_menu_popup.dart';
import '../Widgets/profile_header.dart';
import '../Map_And_Bubbles/user_map_page.dart';

class PostFeedPage extends StatefulWidget {
  final String title;
  final ValueNotifier<List<String>>? capturedBubbles;

  const PostFeedPage({
    super.key,
    required this.title,
    this.capturedBubbles,
  });

  @override
  State<PostFeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<PostFeedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<DocumentSnapshot>> _fetchCapturedPosts(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    // Split into chunks of 10 (Firestore whereIn limit)
    List<List<String>> chunks = [];
    for (int i = 0; i < postIds.length; i += 10) {
      chunks.add(postIds.sublist(i, i + 10 > postIds.length ? postIds.length : i + 10));
    }

    // Fetch each chunk
    List<Future<QuerySnapshot>> futures = chunks.map((chunk) {
      return _firestore
          .collection('posts')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
    }).toList();

    // Wait for all
    List<QuerySnapshot> snapshots = await Future.wait(futures);

    // Combine all docs
    List<DocumentSnapshot> allDocs = [];
    for (var snap in snapshots) {
      allDocs.addAll(snap.docs);
    }

    return allDocs;
  }

  Future<void> _handleUserProfileTap(String userID) async {
    // Show the popup
    final result = await showMapMenuPopUp(context, userID);

    // Check if user wants to open the map
    if (result != null && result is Map && result['action'] == 'openMap') {
      print('📍 Opening UserMapPage for user: ${result['userName']}');
      
      // Navigate to the map from the parent context
      final capturedPostIds = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (context) => UserMapPage(
            userId: result['userId'],
            userName: result['userName'],
          ),
        ),
      );

      print('📍 Returned from UserMapPage with: $capturedPostIds');

      if (capturedPostIds != null && capturedPostIds.isNotEmpty && mounted) {
        print('✅ Processing ${capturedPostIds.length} captured posts: $capturedPostIds');
        
        // Update the capturedBubbles ValueNotifier to refresh the feed
        widget.capturedBubbles?.value = capturedPostIds;
      } else {
        print('❌ No post IDs received or list was empty');
      }
    }
  }

  /// Toggle like on a post
  /// Creates/deletes like document and updates post likesCount
  Future<void> _toggleLike(String postId, bool currentlyLiked) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to like posts')),
      );
      return;
    }

    final userId = currentUser.uid;
    final likeDocRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId);

    final postRef = _firestore.collection('posts').doc(postId);

    try {
      if (currentlyLiked) {
        // Unlike: Delete like document and decrement count
        await _firestore.runTransaction((transaction) async {
          final postSnapshot = await transaction.get(postRef);
          if (!postSnapshot.exists) return;

          final currentCount = postSnapshot.data()?['likesCount'] ?? 0;
          transaction.delete(likeDocRef);
          transaction.update(postRef, {
            'likesCount': currentCount > 0 ? currentCount - 1 : 0,
          });
        });
      } else {
        // Like: Create like document and increment count
        await _firestore.runTransaction((transaction) async {
          final postSnapshot = await transaction.get(postRef);
          if (!postSnapshot.exists) return;

          final currentCount = postSnapshot.data()?['likesCount'] ?? 0;
          transaction.set(likeDocRef, {
            'userId': userId,
            'likedAt': FieldValue.serverTimestamp(),
          });
          transaction.update(postRef, {
            'likesCount': currentCount + 1,
          });
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update like: $e')),
      );
    }
  }

  /// Check if current user has liked a specific post
  Stream<bool> _isPostLikedStream(String postId) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(false);
    }

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(currentUser.uid)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.capturedBubbles != null
          ? ValueListenableBuilder<List<String>>(
              valueListenable: widget.capturedBubbles!,
              builder: (context, capturedTags, _) {
                print('ValueListenableBuilder triggered with capturedTags: $capturedTags');
                if (capturedTags.isEmpty) {
                  return _buildDefaultFeed();
                }
                // Fetch captured posts using FutureBuilder since we have specific IDs
                return FutureBuilder<List<DocumentSnapshot>>(
                  future: _fetchCapturedPosts(capturedTags),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('No posts found for captured bubbles'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                widget.capturedBubbles?.value = [];
                              },
                              child: const Text('Clear Filter'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data![index];
                        var data = doc.data() as Map<String, dynamic>;

                        return _buildPostCard(doc.id, data);
                      },
                    );
                  },
                );
              },
            )
          : _buildDefaultFeed(),
    );
  }

  Widget _buildDefaultFeed() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('posts').limit(50).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts available'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;

            return _buildPostCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildPostCard(String postId, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String username = data['username'] ?? 'Unknown User';
    String userID = data['userID'] ?? 'Unknown ID';
    String description = data['description'] ?? '';
    int likesCount = data['likesCount'] ?? 0;
    int commentsCount = data['commentsCount'] ?? 0;
    List<dynamic> tags = data['tags'] ?? [];
    List<dynamic> imageUrls = data['imageUrls'] ?? [];
    String? videoUrl = data['videoUrl'];
    Timestamp? createdAt = data['createdAt'];
    String dateString = createdAt != null
        ? _formatDate(createdAt.toDate())
        : 'Unknown Date';

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color.fromARGB(255, 30, 30, 30) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : const Color.fromARGB(255, 87, 87, 87),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // User header
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ProfileHeaderWidget(
                  header: username,
                  subheading: dateString,
                  onTap: () => _handleUserProfileTap(userID),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz),
                  iconSize: 40,
                  padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          
          // Media section - handles both images and videos with double-tap to like
          if (videoUrl != null && videoUrl.isNotEmpty)
            // Display video if one exists
            _buildVideoSection(videoUrl, postId)
          else if (imageUrls.isNotEmpty)
            // Display images if no video, but images exist
            _buildImageSection(imageUrls, postId)
          else
            // Display placeholder if neither video nor images
            _buildNoMediaPlaceholder(),
          
          // Tags
          if (tags.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tags.map((tag) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Container(
                    margin: EdgeInsets.all(5),
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _getTagColor(tag.toString()),
                    ),
                    child: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          // Likes + Comments Row with real-time like status
          StreamBuilder<bool>(
            stream: _isPostLikedStream(postId),
            builder: (context, likeSnapshot) {
              final isLiked = likeSnapshot.data ?? false;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : (isDark ? Colors.white : Colors.black),
                          ),
                          onPressed: () => _toggleLike(postId, isLiked),
                        ),
                        Text(
                          _formatCount(likesCount),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.comment_outlined, color: isDark ? Colors.white : Colors.black),
                          onPressed: () {
                            setState(() {});
                          },
                        ),
                        Text(_formatCount(commentsCount), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.upload, color: isDark ? Colors.white : Colors.black),
                          onPressed: () {
                            setState(() {});
                          },
                        ),
                        Text("Share", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      ],
                    ),
                  ),
                  SizedBox(
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.report_outlined, color: isDark ? Colors.white : Colors.black),
                          onPressed: () {
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 10),
          // Description
          if (description.isNotEmpty)
            Container(
              padding: EdgeInsets.all(10),
              child: LabeledBox(
                title: "Description",
                value: description,
              ),
            ),
          // Support button
          Center(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                elevation: 10,
                backgroundColor: Colors.lightBlueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                "Support Creator",
                style: TextStyle(
                  color: isDark ? Colors.lightBlueAccent : const Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }


  Widget _buildVideoSection(String videoUrl, String postId) {
    return VideoPlayerWidget(
      videoUrl: videoUrl,
      postId: postId,
      onDoubleTap: () async {
        // Check if already liked
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;
        
        final likeDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(currentUser.uid)
            .get();
        
        final isLiked = likeDoc.exists;
        
        // Only like if not already liked
        if (!isLiked) {
          await _toggleLike(postId, false);
        }
      },
    );
  }
  
  Widget _buildNoMediaPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 200,
      color: isDark ? const Color.fromARGB(255, 50, 50, 50) : Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 60, color: isDark ? Colors.grey[400] : Colors.grey[600]),
            SizedBox(height: 10),
            Text(
              'No media available',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(List<dynamic> imageUrls, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // No images available
    if (imageUrls.isEmpty) {
      return Container(
        height: 200,
        color: isDark ? const Color.fromARGB(255, 50, 50, 50) : Colors.grey[300],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_not_supported, size: 60, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              SizedBox(height: 10),
              Text(
                'No image available',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Single image
    if (imageUrls.length == 1) {
      return _buildSingleImage(imageUrls[0].toString(), postId);
    }

    // Multiple images - Instagram-style carousel
    return _buildImageCarousel(imageUrls, postId);
  }

  Widget _buildSingleImage(String imageUrl, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color.fromARGB(255, 50, 50, 50) : Colors.grey[300];
    
    return FutureBuilder<Size?>(
      future: _getImageDimensions(imageUrl),
      builder: (context, snapshot) {
        // Default height if dimensions can't be determined
        double containerHeight = 400;
        
        if (snapshot.hasData && snapshot.data != null) {
          // Calculate height based on actual image dimensions while maintaining aspect ratio
          // Max width is constrained by screen width
          final maxWidth = MediaQuery.of(context).size.width;
          final aspectRatio = snapshot.data!.width / snapshot.data!.height;
          containerHeight = (maxWidth / aspectRatio).clamp(200.0, 600.0);
        }
        
        return GestureDetector(
          onDoubleTap: () async {
            // Check if already liked
            final currentUser = _auth.currentUser;
            if (currentUser == null) return;
            
            final likeDoc = await _firestore
                .collection('posts')
                .doc(postId)
                .collection('likes')
                .doc(currentUser.uid)
                .get();
            
            final isLiked = likeDoc.exists;
            
            // Only like if not already liked
            if (!isLiked) {
              await _toggleLike(postId, false);
              
              // Show heart animation
              _showHeartAnimation(context);
            }
          },
          child: Container(
            height: containerHeight,
            color: bgColor,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: bgColor,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: bgColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 60, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      SizedBox(height: 10),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// Show heart animation when double-tapping to like
  void _showHeartAnimation(BuildContext context) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Opacity(
                opacity: 1.0 - value,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 100,
                ),
              ),
            );
          },
          onEnd: () {
            // Remove overlay after animation
            Future.delayed(const Duration(milliseconds: 100), () {
              overlayEntry.remove();
            });
          },
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
  }
  
  /// Get image dimensions from URL
  Future<Size?> _getImageDimensions(String imageUrl) async {
    try {
      final image = NetworkImage(imageUrl);
      final completer = Completer<Size>();
      image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((image, synchronousCall) {
          final myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          completer.complete(size);
        }),
      );
      return completer.future;
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }

  Widget _buildImageCarousel(List<dynamic> imageUrls, String postId) {
    return ImageCarousel(
      imageUrls: imageUrls,
      postId: postId,
      onDoubleTap: () async {
        // Check if already liked
        final currentUser = _auth.currentUser;
        if (currentUser == null) return;
        
        final likeDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('likes')
            .doc(currentUser.uid)
            .get();
        
        final isLiked = likeDoc.exists;
        
        // Only like if not already liked
        if (!isLiked) {
          await _toggleLike(postId, false);
          
          // Show heart animation
          _showHeartAnimation(context);
        }
      },
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day} ${_getMonthName(date.month)} ${date.year}";
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  Color _getTagColor(String tag) {
    int hash = tag.hashCode;
    return Color.fromARGB(
      255,
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      hash & 0x0000FF,
    ).withOpacity(0.7);
  }
}

// Instagram-style Image Carousel Widget with double-tap to like
class ImageCarousel extends StatefulWidget {
  final List<dynamic> imageUrls;
  final String postId;
  final VoidCallback onDoubleTap;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    required this.postId,
    required this.onDoubleTap,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  late List<Size?> _imageDimensions;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Preload all image dimensions
    _imageDimensions = List.filled(widget.imageUrls.length, null);
    _preloadImageDimensions();
  }

  Future<void> _preloadImageDimensions() async {
    for (int i = 0; i < widget.imageUrls.length; i++) {
      try {
        final dimensions = await _getImageDimensions(widget.imageUrls[i].toString());
        if (mounted) {
          setState(() {
            _imageDimensions[i] = dimensions;
          });
        }
      } catch (e) {
        debugPrint('Error loading image dimensions for image $i: $e');
      }
    }
  }

  Future<Size?> _getImageDimensions(String imageUrl) async {
    try {
      final image = NetworkImage(imageUrl);
      final completer = Completer<Size>();
      image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((image, synchronousCall) {
          final myImage = image.image;
          Size size = Size(myImage.width.toDouble(), myImage.height.toDouble());
          if (!completer.isCompleted) {
            completer.complete(size);
          }
        }),
      );
      return completer.future;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color.fromARGB(255, 50, 50, 50) : Colors.grey[300];
    
    // Get dimensions of current image
    Size? currentDimensions = _imageDimensions[_currentPage];
    double containerHeight = 400;
    
    if (currentDimensions != null) {
      final maxWidth = MediaQuery.of(context).size.width;
      final aspectRatio = currentDimensions.width / currentDimensions.height;
      containerHeight = (maxWidth / aspectRatio).clamp(200.0, 600.0);
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: containerHeight,
      color: bgColor,
      child: Stack(
        children: [
          // Image PageView with double-tap support
          GestureDetector(
            onDoubleTap: widget.onDoubleTap,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                return CachedNetworkImage(
                  imageUrl: widget.imageUrls[index].toString(),
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    color: bgColor,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: bgColor,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 60, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(height: 10),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Page indicators (dots)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.imageUrls.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
          
          // Page counter (top right)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.imageUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// VideoPlayerWidget - Stateful widget to manage video playback with double-tap to like
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String postId;
  final VoidCallback onDoubleTap;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.postId,
    required this.onDoubleTap,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoController;
  late Future<void> _initializeVideoFuture;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _showPauseIcon = false;
  Timer? _pauseIconTimer;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );
    
    _videoController.setVolume(0.0);
    
    _initializeVideoFuture = _videoController.initialize().then((_) {
      _videoController.play();
      _videoController.setLooping(true);
      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pauseIconTimer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_videoController.value.isPlaying) {
        _videoController.pause();
        _isPlaying = false;
        _showPauseIcon = true;
      } else {
        _videoController.play();
        _isPlaying = true;
        _showPauseIcon = false;
      }
    });
    
    if (!_isPlaying) {
      _pauseIconTimer?.cancel();
      _pauseIconTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showPauseIcon = false;
          });
        }
      });
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoController.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color.fromARGB(255, 50, 50, 50) : Colors.grey[300];
    
    return FutureBuilder<void>(
      future: _initializeVideoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          final videoAspectRatio = _videoController.value.aspectRatio;
          final maxWidth = MediaQuery.of(context).size.width;
          final containerHeight = (maxWidth / videoAspectRatio).clamp(200.0, 600.0);
          
          return Container(
            color: bgColor,
            height: containerHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: videoAspectRatio,
                    child: VideoPlayer(_videoController),
                  ),
                ),
                
                // Double-tap and single-tap detector
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    onDoubleTap: widget.onDoubleTap,
                    behavior: HitTestBehavior.translucent,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
                
                // Pause icon overlay
                if (_showPauseIcon || !_isPlaying)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                
                // Mute/Unmute button
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                
                // Video progress bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: VideoProgressIndicator(
                    _videoController,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.blue,
                      bufferedColor: Colors.grey,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            color: bgColor,
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Failed to load video',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          return Container(
            color: bgColor,
            height: 400,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? Colors.grey[400]! : Colors.grey[600]!,
                ),
              ),
            ),
          );
        }
      },
    );
  }
}