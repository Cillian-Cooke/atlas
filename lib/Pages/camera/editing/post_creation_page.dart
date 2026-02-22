import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Post creation page for uploading media to Firebase
/// Accepts image paths and optional video path from gallery
class PostCreationPage extends StatefulWidget {
  final List<String> imagePaths;
  final String? videoPath;

  const PostCreationPage({
    super.key,
    required this.imagePaths,
    this.videoPath,
  });

  @override
  State<PostCreationPage> createState() => _PostCreationPageState();
}

class _PostCreationPageState extends State<PostCreationPage> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _userIDController = TextEditingController();

  bool _commentsEnabled = true;
  bool _donationsEnabled = true;
  bool _isSaving = false;
  bool _isLoadingUserData = true;
  bool _isLoadingGroups = false;
  bool _isPublic = true; // true = public, false = personal/private map only
  List<Map<String, dynamic>> _userGroups = [];
  List<String> _selectedGroupIds = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserGroups();
  }

  /// Load user data from Firebase
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          final userData = userDoc.data();
          setState(() {
            _userIDController.text = user.uid;
            _usernameController.text = userData?['username'] ?? 'User';
            _isLoadingUserData = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingUserData = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoadingUserData = false);
      }
    }
  }

  /// Load groups that the user is a member of
  Future<void> _loadUserGroups() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('groups')
          .where('members', arrayContains: user.uid)
          .get();

      if (mounted) {
        setState(() {
          _userGroups = querySnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] ?? 'Unnamed Group',
                  })
              .toList();
          _isLoadingGroups = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading groups: $e');
      if (mounted) {
        setState(() => _isLoadingGroups = false);
      }
    }
  }

  /// Upload images to Firebase Storage and get their dimensions
  Future<List<Map<String, dynamic>>> _uploadImages(String postId) async {
    List<Map<String, dynamic>> imageData = [];

    for (int i = 0; i < widget.imagePaths.length; i++) {
      try {
        final imagePath = widget.imagePaths[i];
        final String fileName = 'image_$i.png';

        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(postId)
            .child(fileName);

        // Convert image to PNG and capture dimensions
        Uint8List imageBytes;
        int imageWidth = 0;
        int imageHeight = 0;
        try {
          final bytes = await File(imagePath).readAsBytes();
          final decodedImage = img.decodeImage(bytes);

          if (decodedImage == null) {
            throw Exception('Failed to decode image');
          }

          // Capture dimensions before encoding
          imageWidth = decodedImage.width;
          imageHeight = decodedImage.height;

          imageBytes = Uint8List.fromList(img.encodePng(decodedImage));
        } catch (e) {
          debugPrint("Error converting image: $e");
          imageBytes = await File(imagePath).readAsBytes();
        }

        // Upload to storage
        final uploadTask = storageRef.putData(imageBytes);
        final TaskSnapshot snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        imageData.add({
          'url': downloadUrl,
          'width': imageWidth,
          'height': imageHeight,
        });
      } catch (e) {
        debugPrint("Error uploading image $i: $e");
      }
    }

    return imageData;
  }

  /// Upload video to Firebase Storage
  Future<String?> _uploadVideo(String postId) async {
    if (widget.videoPath == null) return null;

    try {
      final String fileName = 'video.mp4';

      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(postId)
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(
        File(widget.videoPath!),
        SettableMetadata(contentType: 'video/mp4'),
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading video: $e");
      return null;
    }
  }

  /// Save post to Firestore
  Future<void> _savePost() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description is required")),
      );
      return;
    }

    final tags = _tagsController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final docRef = FirebaseFirestore.instance.collection("posts").doc();
    final String postId = docRef.id;

    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> imageDataList = await _uploadImages(postId);
      final String? videoUrl = await _uploadVideo(postId);

      if (imageDataList.isEmpty && videoUrl == null) {
        throw Exception("Failed to upload media");
      }

      // Extract URLs and dimensions for storage
      final List<String> imageUrls = imageDataList.map((data) => data['url'] as String).toList();
      final List<int> imageDimensionsWidth = imageDataList.map((data) => data['width'] as int).toList();
      final List<int> imageDimensionsHeight = imageDataList.map((data) => data['height'] as int).toList();

      await docRef.set({
        "authorId": _userIDController.text.trim(),
        "userID": _userIDController.text.trim(),
        "username": _usernameController.text.trim(),
        "description": _descriptionController.text.trim(),
        "tags": tags,
        "imageUrls": imageUrls,
        "imageDimensions": {
          "widths": imageDimensionsWidth,
          "heights": imageDimensionsHeight,
        },
        "videoUrl": videoUrl,
        "likesCount": 0,
        "commentsCount": 0,
        "commentsEnabled": _commentsEnabled,
        "donationsEnabled": _donationsEnabled,
        "isPublic": _isPublic,
        "groupIds": _selectedGroupIds,
        "createdAt": DateTime.now(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );

      // Navigate back to gallery or main feed
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingUserData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== MEDIA PREVIEW ==========
            if (widget.imagePaths.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.imagePaths.length} image(s) selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.videoPath != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[400]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.videocam, color: Colors.orange[700]),
                    const SizedBox(width: 10),
                    const Text(
                      'Video selected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ========== DESCRIPTION ==========
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Write a description for your post...',
              ),
            ),
            const SizedBox(height: 15),

            // ========== TAGS ==========
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                border: OutlineInputBorder(),
                hintText: 'e.g., flutter, photography, nature',
              ),
            ),

            const SizedBox(height: 20),

            // ========== VISIBILITY & GROUPS ==========
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Visibility toggle
                  Text(
                    'Post Visibility',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          segments: const <ButtonSegment<bool>>[
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Public'),
                              icon: Icon(Icons.public),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Personal'),
                              icon: Icon(Icons.lock),
                            ),
                          ],
                          selected: <bool>{_isPublic},
                        onSelectionChanged: (Set<bool> newSelection) {
                            setState(() {
                              _isPublic = newSelection.first;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Groups selection
                  Text(
                    'Add to Groups',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoadingGroups)
                    const SizedBox(
                      height: 30,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_userGroups.isEmpty)
                    Text(
                      'No groups yet. Create one to add posts to it.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else
                    Column(
                      children: _userGroups.map((group) {
                        final groupId = group['id'] as String;
                        final groupName = group['name'] as String;
                        final isSelected = _selectedGroupIds.contains(groupId);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedGroupIds.add(groupId);
                              } else {
                                _selectedGroupIds.remove(groupId);
                              }
                            });
                          },
                          title: Text(groupName),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ========== USER INFO ==========
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post By',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _usernameController.text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${_userIDController.text}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ========== TOGGLES ==========
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Allow Comments',
                          style: TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: _commentsEnabled,
                          onChanged: (v) =>
                              setState(() => _commentsEnabled = v),
                        ),
                      ],
                    ),
                    Divider(color: Colors.grey[300]),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Allow Donations',
                          style: TextStyle(fontSize: 16),
                        ),
                        Switch(
                          value: _donationsEnabled,
                          onChanged: (v) =>
                              setState(() => _donationsEnabled = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // ========== PUBLISH BUTTON ==========
            ElevatedButton(
              onPressed: _isSaving ? null : _savePost,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueAccent,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Publish Post',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tagsController.dispose();
    _usernameController.dispose();
    _userIDController.dispose();
    super.dispose();
  }

}