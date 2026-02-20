import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditPostsPage extends StatefulWidget {
  const EditPostsPage({super.key});

  @override
  State<EditPostsPage> createState() => _EditPostsPageState();
}

class _EditPostsPageState extends State<EditPostsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PageController _pageController = PageController();
  
  List<DocumentSnapshot> _userPosts = [];
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPosts() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final postsQuery = await _firestore
          .collection('posts')
          .where('userID', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _userPosts = postsQuery.docs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('posts').doc(postId).update(updates);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post updated successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating post: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditDialog(DocumentSnapshot post) {
    final postData = post.data() as Map<String, dynamic>;
    final descriptionController = TextEditingController(
      text: postData['description'] ?? '',
    );
    bool commentsEnabled = postData['commentsEnabled'] ?? true;
    List<String> tags = List<String>.from(postData['tags'] ?? []);
    final tagController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description field
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Enter post description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Comments toggle
                const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Comments Enabled'),
                  value: commentsEnabled,
                  onChanged: (value) {
                    setDialogState(() {
                      commentsEnabled = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Tags section
                const Text(
                  'Tags',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final tag in tags)
                      Chip(
                        label: Text(tag),
                        onDeleted: () {
                          setDialogState(() {
                            tags.remove(tag);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tagController,
                        decoration: const InputDecoration(
                          hintText: 'Add a tag',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final tag = tagController.text.trim();
                        if (tag.isNotEmpty && !tags.contains(tag)) {
                          setDialogState(() {
                            tags.add(tag);
                            tagController.clear();
                          });
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updatePost(post.id, {
                  'description': descriptionController.text.trim(),
                  'commentsEnabled': commentsEnabled,
                  'tags': tags,
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Posts'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userPosts.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Posts'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No posts yet',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a post to edit it',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Posts'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Post counter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Post ${_currentIndex + 1} of ${_userPosts.length}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),

          // Swipeable carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemCount: _userPosts.length,
              itemBuilder: (context, index) {
                final post = _userPosts[index];
                final postData = post.data() as Map<String, dynamic>;
                final imageUrl = postData['imageUrl'] as String?;
                final description = postData['description'] as String? ?? '';
                final tags = List<String>.from(postData['tags'] ?? []);
                final commentsEnabled = postData['commentsEnabled'] ?? true;
                final createdAt = postData['createdAt'] as Timestamp?;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // Image preview
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(16),
                          constraints: BoxConstraints(
                            maxHeight: 400,
                            maxWidth: double.infinity,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.error),
                            ),
                          ),
                        ),

                      // Post details
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            if (description.isNotEmpty) ...[
                              const Text(
                                'Description',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(description),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Tags
                            if (tags.isNotEmpty) ...[
                              const Text(
                                'Tags',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  for (final tag in tags)
                                    Chip(
                                      label: Text(tag),
                                      backgroundColor:
                                          Colors.blue.withOpacity(0.2),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Comments setting
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Comments Enabled'),
                                  Icon(
                                    commentsEnabled
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: commentsEnabled
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ],
                              ),
                            ),

                            if (createdAt != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Created: ${createdAt.toDate()}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Edit button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _userPosts.isNotEmpty
                  ? () => _showEditDialog(_userPosts[_currentIndex])
                  : null,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Post'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
