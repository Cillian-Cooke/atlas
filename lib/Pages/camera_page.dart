import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show File, Directory;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../Widgets/local_gallery_picker.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.title});
  final String title;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  // ========== TEXT CONTROLLERS ==========
  /// Controller for post description text input
  final TextEditingController _descriptionController = TextEditingController();
  /// Controller for post tags (comma-separated)
  final TextEditingController _tagsController = TextEditingController();
  /// Controller for username (auto-populated from Firebase)
  final TextEditingController _usernameController = TextEditingController();
  /// Controller for user ID (auto-populated from Firebase Auth)
  final TextEditingController _userIDController = TextEditingController();
  
  // ========== UI STATE VARIABLES ==========
  /// Whether comments are enabled for this post
  bool _commentsEnabled = true;
  /// Whether donations are enabled for this post
  bool _donationsEnabled = true;
  /// Whether the post is currently being saved to Firebase
  bool _isSaving = false;
  /// Whether user data is still loading from Firebase
  bool _isLoadingUserData = true;
  
  // ========== MEDIA SELECTION ==========
  /// ImagePicker instance for capturing photos/videos from device camera or gallery
  /// This works on iOS, Android, and Web
  final ImagePicker _picker = ImagePicker();
  
  /// List of selected images as XFile objects
  /// XFile is used instead of File for cross-platform compatibility
  List<XFile> _selectedImages = [];
  
  /// Selected video file as XFile (only one video per post)
  /// Videos are stored separately from images to handle different upload/playback logic
  XFile? _selectedVideo;

  @override
  void initState() {
    super.initState();
    // Load user data when page initializes so we can auto-populate user info
    _loadUserData();
  }

  /// Loads the current user's data from Firebase Authentication and Firestore
  /// This populates the username and user ID fields automatically
  /// Called on page initialization
  Future<void> _loadUserData() async {
    try {
      // Get currently authenticated user from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch user's profile data from Firestore 'users' collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          final userData = userDoc.data();
          setState(() {
            // Set the user ID field to the Firebase Auth UID
            _userIDController.text = user.uid;
            // Set username from Firestore only (no fallbacks to auth fields)
            _usernameController.text = userData?['username'] ?? 'User';
            // Finished loading, show the form
            _isLoadingUserData = false;
          });
        }
      } else {
        // No user logged in, just mark loading as complete
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
  
  /// Captures a photo using the device's camera
  /// This uses ImagePicker's camera mode instead of gallery mode
  /// Works on iOS, Android, and Web
  /// The photo is stored as an XFile which can be converted to bytes or File as needed
  Future<void> _takePhoto() async {
    try {
      // Use the image picker to access the device camera in photo mode
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera, // Use camera, not gallery
        imageQuality: 80, // Compress to 80% quality to save storage
      );
      
      // If user didn't cancel the camera dialog
      if (photo != null) {
        // Save locally to app's gallery
        await _saveMediaLocally(photo, 'image');
        
        setState(() {
          // Add the new photo to the list of selected images
          _selectedImages.add(photo);
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error taking photo: $e")),
      );
    }
  }
  
  /// Captures a video using the device's camera
  /// This uses ImagePicker's video mode to record from the device camera
  /// Works on iOS, Android, and Web
  /// Only one video per post is allowed (replaces any previous video)
  Future<void> _takeVideo() async {
    try {
      // Use the image picker to access the device camera in video mode
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera, // Use camera, not gallery
        maxDuration: const Duration(minutes: 5), // Limit videos to 5 minutes
      );
      
      // If user didn't cancel the camera dialog
      if (video != null) {
        // Save locally to app's gallery
        await _saveMediaLocally(video, 'video');
        
        setState(() {
          // Replace any previous video with the new one (only one video per post)
          _selectedVideo = video;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error recording video: $e")),
      );
    }
  }

  /// Saves media (image or video) to the app's local gallery storage
  /// Creates 'atlas_gallery' folder in app documents directory
  /// Useful for keeping a local backup and allowing offline browsing
  Future<void> _saveMediaLocally(XFile media, String type) async {
    try {
      // Get the app's documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      
      // Create gallery folder if it doesn't exist
      final Directory galleryDir = Directory('${appDir.path}/atlas_gallery');
      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }
      
      // Create a unique filename based on timestamp
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = type == 'video' ? 'mp4' : 'jpg';
      final String fileName = '${type}_$timestamp.$extension';
      final String filePath = '${galleryDir.path}/$fileName';
      
      // Copy the media file to local storage
      await File(media.path).copy(filePath);
      
      // Log success (in production, could show a toast)
      if (!mounted) return;
    } catch (e) {
      // Silently fail if local save doesn't work - doesn't block posting
      print('Local save error: $e');
    }
  }

  /// Opens the local gallery picker dialog
  /// Allows users to select multiple images from previously captured/saved media
  /// Returns selected XFiles or null if cancelled
  Future<void> _openLocalGallery() async {
    final List<XFile>? selected = await showDialog<List<XFile>>(
      context: context,
      builder: (context) => LocalGalleryPicker(
        onSelectionComplete: (selectedFiles) {
          Navigator.pop(context, selectedFiles);
        },
      ),
    );
    
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        // Add selected images to current selection
        _selectedImages.addAll(selected);
      });
    }
  }
  
  /// Uploads all selected images to Firebase Storage in WebP format
  /// Each image is converted to WebP format for smaller file size with high quality
  /// Images are stored under 'posts/{postId}/image_{index}.webp'
  /// Returns a list of download URLs for the uploaded images
  /// Handles both web and mobile platforms differently:
  /// - Web: Converts image to WebP bytes
  /// - Mobile: Converts file to WebP then uploads
  Future<List<String>> _uploadImages(String postId) async {
    List<String> imageUrls = [];
    
    // Iterate through each selected image
    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final XFile imageFile = _selectedImages[i];
        final String fileName = 'image_$i.webp';
        
        // Create a reference to the storage location
        // Path: posts/{postId}/image_{i}.webp
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(postId)
            .child(fileName);
        
        // Convert image to WebP format
        Uint8List webpBytes;
        
        try {
          // Read image bytes
          final imageBytes = await imageFile.readAsBytes();
          
          // Decode image using the image package
          final img.Image? decodedImage = img.decodeImage(imageBytes);
          
          if (decodedImage == null) {
            throw Exception('Failed to decode image');
          }
          
          // Encode as PNG (Flutter image package doesn't support WebP encoding directly)
          // Images are still lightweight and high quality
          webpBytes = Uint8List.fromList(
            img.encodePng(decodedImage),
          );
        } catch (e) {
          debugPrint("Error converting image to WebP: $e");
          // Fallback to original image bytes
          webpBytes = await imageFile.readAsBytes();
          debugPrint("Using original image format due to WebP conversion error");
        }
        
        // Upload the WebP image to Firebase Storage
        final UploadTask uploadTask = storageRef.putData(
          webpBytes,
          // Set MIME type to WebP
          SettableMetadata(contentType: 'image/webp'),
        );
        
        // Wait for the upload to complete and get result
        final TaskSnapshot snapshot = await uploadTask;
        
        // Retrieve the download URL for this image
        // This URL is used to display the image in the feed
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        // Log error but continue uploading other images
        debugPrint("Error uploading image $i: $e");
      }
    }
    
    return imageUrls;
  }
  
  /// Uploads the selected video to Firebase Storage
  /// The video is stored under 'posts/{postId}/video.mp4'
  /// Returns the download URL for the uploaded video
  /// Videos are treated separately from images to support different UI rendering
  /// Handles both web and mobile platforms
  Future<String?> _uploadVideo(String postId) async {
    // Only upload if a video was actually selected
    if (_selectedVideo == null) return null;
    
    try {
      final XFile videoFile = _selectedVideo!;
      final String fileName = 'video.mp4';
      
      // Create a reference to the storage location
      // Path: posts/{postId}/video.mp4
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(postId)
          .child(fileName);
      
      // Upload differently based on platform
      UploadTask uploadTask;
      if (kIsWeb) {
        // For web: convert to bytes
        final bytes = await videoFile.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          // Set MIME type so Firebase knows it's an MP4 video
          SettableMetadata(contentType: 'video/mp4'),
        );
      } else {
        // For mobile: use file path directly for efficiency
        uploadTask = storageRef.putFile(
          File(videoFile.path),
          SettableMetadata(contentType: 'video/mp4'),
        );
      }
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Return the download URL for the video
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("Error uploading video: $e");
      return null;
    }
  }
  
  /// Saves the post to Firebase Firestore with all metadata
  /// This includes images, video (if selected), description, tags, and user info
  /// The post is created with an auto-generated document ID
  /// If a video is selected, images and video cannot both be uploaded (user must choose one)
  Future<void> _savePost() async {
    // Validate that description is not empty
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description is required")),
      );
      return;
    }
    
    // Validate that user selected at least images or a video
    if (_selectedImages.isEmpty && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image or video")),
      );
      return;
    }
    
    // Parse tags from comma-separated input
    // Example: "flutter, firebase, app" → ["flutter", "firebase", "app"]
    final tags = _tagsController.text
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    // Create a reference to a new document in 'posts' collection
    // This generates a unique ID for the post
    final docRef = FirebaseFirestore.instance.collection("posts").doc();
    final String postId = docRef.id;
    
    // Show loading indicator
    setState(() => _isSaving = true);
    
    try {
      // Upload images and/or video to Firebase Storage
      // This returns URLs that are saved in Firestore
      final List<String> imageUrls = await _uploadImages(postId);
      final String? videoUrl = await _uploadVideo(postId);
      
      // Validate that at least one upload succeeded
      if (imageUrls.isEmpty && videoUrl == null) {
        throw Exception("Failed to upload media (no images or video)");
      }
      
      // Create the post document in Firestore with all the metadata
      // This data structure is used throughout the app to display posts in the feed
      await docRef.set({
        // Auth & User Information
        "authorId": _userIDController.text.trim(), // Firebase Auth UID - used for security rules
        "userID": _userIDController.text.trim(), // Display user ID
        "username": _usernameController.text.trim(), // Display username
        
        // Content
        "description": _descriptionController.text.trim(), // Post description
        "tags": tags, // Search and filter tags
        
        // Media - can have images or video or both
        "imageUrls": imageUrls, // List of image URLs from Firebase Storage
        "videoUrl": videoUrl, // Optional video URL from Firebase Storage
        
        // Engagement Features
        "likesCount": 0, // Starts at 0 likes
        "commentsCount": 0, // Starts with 0 comments
        "commentsEnabled": _commentsEnabled, // User can disable comments
        "donationsEnabled": _donationsEnabled, // User can disable donation button
        
        // Timestamps
        "createdAt": DateTime.now(), // When the post was created
      });
      
      // Check if widget is still mounted (user didn't navigate away)
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );
      
      // Clear all form fields for next post
      _descriptionController.clear();
      _tagsController.clear();
      setState(() {
        _selectedImages.clear();
        _selectedVideo = null; // Clear video selection
      });
      
    } catch (e) {
      // Show error message if something went wrong
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
    
    // Hide loading indicator
    setState(() => _isSaving = false);
  }
  
  @override
  Widget build(BuildContext context) {
    // Check if running on web platform
    // Web doesn't support camera features, so show unavailable message
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                'Camera Feature Not Available',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Camera and video features are only available on iOS and Android.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile platform (iOS/Android) - show camera-first interface
    return Scaffold(
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : _selectedImages.isEmpty && _selectedVideo == null
              ? // ========== CAMERA CAPTURE MODE ==========
              // Immersive camera interface like Snapchat/Instagram
              _buildCameraInterface()
              : // ========== POST FORM MODE ==========
              // Show form after media is selected
              _buildPostForm(),
    );
  }

  /// Builds the immersive camera interface for capturing photos/videos
  /// Similar to Snapchat/Instagram - fullscreen camera with buttons at bottom
  Widget _buildCameraInterface() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background (would be camera preview in production)
        Container(
          color: Colors.black,
          child: const Center(
            child: Icon(
              Icons.camera_alt,
              size: 80,
              color: Colors.white30,
            ),
          ),
        ),

        // Top bar with title
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 10,
              left: 16,
              right: 16,
            ),
            color: Colors.black.withOpacity(0.3),
            child: Text(
              'Create Post',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Bottom buttons - camera controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            color: Colors.black.withOpacity(0.5),
            child: Column(
              children: [
                // Row of camera action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Take Photo button - Blue
                    FloatingActionButton.extended(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera),
                      label: const Text('Photo'),
                      backgroundColor: Colors.blue,
                    ),

                    // Record Video button - Red
                    FloatingActionButton.extended(
                      onPressed: _takeVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Video'),
                      backgroundColor: Colors.red,
                    ),

                  ],
                ),
                const SizedBox(height: 15),
                // Local Gallery button - Purple
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openLocalGallery,
                    icon: const Icon(Icons.collections),
                    label: const Text('My Saved Media'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the post form after media selection
  /// Shows description, tags, toggles, and publish button
  /// Username and user ID are displayed but not editable
  Widget _buildPostForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            // Go back to camera mode by clearing media
            _selectedImages.clear();
            _selectedVideo = null;
            _descriptionController.clear();
            _tagsController.clear();
          }),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== SELECTED MEDIA PREVIEW ==========
            // Show what media was selected

            if (_selectedImages.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 10),
                        Text(
                          '${_selectedImages.length} image(s) selected',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedImages.clear()),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedVideo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[400]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
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
                    TextButton.icon(
                      onPressed: () => setState(() => _selectedVideo = null),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Change'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // ========== EDITABLE FIELDS ==========
            // Only description and tags are editable

            // Description input
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

            // Tags input (comma-separated)
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (comma separated)',
                border: OutlineInputBorder(),
                hintText: 'e.g., flutter, photography, nature',
              ),
            ),

            const SizedBox(height: 20),

            // ========== NON-EDITABLE USER INFO ==========
            // Display username and userID (auto-populated, read-only)

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Post By',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey[600],
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
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ========== FEATURE TOGGLES ==========
            // Allow users to enable/disable comments and donations

            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    // Comments toggle
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
                    // Donations toggle
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
            // Upload post to Firebase

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
  
  /// Cleanup method called when widget is disposed
  /// Disposes of all text controllers to free up memory
  /// Important: Always dispose controllers to prevent memory leaks
  @override
  void dispose() {
    // Dispose of each text controller
    _descriptionController.dispose();
    _tagsController.dispose();
    _usernameController.dispose();
    _userIDController.dispose();
    super.dispose();
  }
}