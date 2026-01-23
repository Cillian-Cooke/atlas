import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.title});
  final String title;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  // Form controllers
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _userIDController = TextEditingController();
  
  bool _commentsEnabled = true;
  bool _donationsEnabled = true;
  bool _isSaving = false;
  bool _isLoadingUserData = true;
  
  // Image handling - store XFile instead of File
  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load current user data from Firebase Auth and Firestore
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get user data from Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          final userData = userDoc.data();
          setState(() {
            _userIDController.text = user.uid;
            _usernameController.text = userData?['username'] ?? user.displayName ?? user.email ?? '';
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
  
  /// Pick multiple images from gallery
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 80,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking images: $e")),
      );
    }
  }
  
  /// Upload images to Firebase Storage and return URLs
  Future<List<String>> _uploadImages(String postId) async {
    List<String> imageUrls = [];
    
    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final XFile imageFile = _selectedImages[i];
        final String fileName = 'image_$i.jpg';
        final Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('posts')
            .child(postId)
            .child(fileName);
        
        // Upload differently based on platform
        UploadTask uploadTask;
        if (kIsWeb) {
          // For web: use bytes
          final bytes = await imageFile.readAsBytes();
          uploadTask = storageRef.putData(
            bytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
        } else {
          // For mobile/desktop: use file
          uploadTask = storageRef.putFile(
            File(imageFile.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
        
        // Wait for upload to complete
        final TaskSnapshot snapshot = await uploadTask;
        
        // Get download URL
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      } catch (e) {
        debugPrint("Error uploading image $i: $e");
      }
    }
    
    return imageUrls;
  }
  
  Future<void> _savePost() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description is required")),
      );
      return;
    }
    
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image")),
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
      final List<String> imageUrls = await _uploadImages(postId);
      
      if (imageUrls.isEmpty) {
        throw Exception("Failed to upload images");
      }
      
      await docRef.set({
        "commentsCount": 0,
        "commentsEnabled": _commentsEnabled,
        "createdAt": DateTime.now(),
        "description": _descriptionController.text.trim(),
        "donationsEnabled": _donationsEnabled,
        "likesCount": 0,
        "tags": tags,
        "userID": _userIDController.text.trim(),
        "username": _usernameController.text.trim(),
        "imageUrls": imageUrls,
        "videoUrl": null,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post uploaded successfully!")),
      );
      
      _descriptionController.clear();
      _tagsController.clear();
      setState(() {
        _selectedImages.clear();
      });
      
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: _isLoadingUserData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Selection Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 60,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: Text(_selectedImages.isEmpty
                        ? "Select Images"
                        : "Change Images (${_selectedImages.length})"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            // Image Count Display (replaces preview)
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 15),
              Container(
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
                          "${_selectedImages.length} image(s) selected",
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
                      label: const Text("Clear all"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: "Tags (comma separated)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _usernameController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "Username (Auto-populated)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            
            TextField(
              controller: _userIDController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "UserID (Auto-populated)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 15),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch(
                      value: _commentsEnabled,
                      onChanged: (v) => setState(() => _commentsEnabled = v),
                    ),
                    const Text("Comments"),
                  ],
                ),
                Row(
                  children: [
                    Switch(
                      value: _donationsEnabled,
                      onChanged: (v) => setState(() => _donationsEnabled = v),
                    ),
                    const Text("Donations"),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),
            
            ElevatedButton(
              onPressed: _isSaving ? null : _savePost,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blueAccent,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Create Post",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
            ),
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