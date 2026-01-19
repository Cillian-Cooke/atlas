import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viewing ${capturedPostIds.length} posts from ${result['userName']}'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Clear',
              onPressed: () {
                // Clear the filter to show all posts again
                widget.capturedBubbles?.value = [];
              },
            ),
          ),
        );
      } else {
        print('❌ No post IDs received or list was empty');
      }
    }
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

                        return _buildPostCard(data);
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

            return _buildPostCard(data);
          },
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String username = data['username'] ?? 'Unknown User';
    String userID = data['userID'] ?? 'Unknown ID';
    String description = data['description'] ?? '';
    int likesCount = data['likesCount'] ?? 0;
    int commentsCount = data['commentsCount'] ?? 0;
    List<dynamic> tags = data['tags'] ?? [];
    List<dynamic> imageUrls = data['imageUrls'] ?? [];
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
          
          // Image section with dynamic height
          _buildImageSection(imageUrls),
          
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
          // Likes + Comments Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.favorite_border, color: isDark ? Colors.white : Colors.black),
                      onPressed: () {
                        setState(() {});
                      },
                    ),
                    Text(_formatCount(likesCount), style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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

  Widget _buildImageSection(List<dynamic> imageUrls) {
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
      return _buildSingleImage(imageUrls[0].toString());
    }

    // Multiple images - Instagram-style carousel
    return _buildImageCarousel(imageUrls);
  }

  Widget _buildSingleImage(String imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color.fromARGB(255, 50, 50, 50) : Colors.grey[300];
    
    return Container(
      height: 400, // FIXED HEIGHT
      color: bgColor,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        maxHeightDiskCache: 400,
        maxWidthDiskCache: 400,
        memCacheHeight: 300,
        memCacheWidth: 300,
        placeholder: (context, url) => Container(
          color: bgColor,
          child: Center(
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
    );
  }

  Widget _buildImageCarousel(List<dynamic> imageUrls) {
    return ImageCarousel(imageUrls: imageUrls);
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

// Instagram-style Image Carousel Widget - SIMPLIFIED
class ImageCarousel extends StatefulWidget {
  final List<dynamic> imageUrls;

  const ImageCarousel({super.key, required this.imageUrls});

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
    
    return Container(
      height: 400, // FIXED HEIGHT - No dynamic calculation
      color: bgColor,
      child: Stack(
        children: [
          // Image PageView
          PageView.builder(
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
                maxHeightDiskCache: 400,
                maxWidthDiskCache: 400,
                memCacheHeight: 300,
                memCacheWidth: 300,
                placeholder: (context, url) => Container(
                  color: bgColor,
                  child: Center(
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
              );
            },
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
                  margin: EdgeInsets.symmetric(horizontal: 3),
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
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.imageUrls.length}',
                style: TextStyle(
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