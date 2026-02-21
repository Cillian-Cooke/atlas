import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../popup_container.dart';
import '../../Services/post_service.dart';

class EditProfilePopUp extends StatefulWidget {

  const EditProfilePopUp({
    super.key,
  });

  @override
  State<EditProfilePopUp> createState() => _EditProfilePopUpState();
}

class _EditProfilePopUpState extends State<EditProfilePopUp> {
  late PostService _postService;
  bool _unseenPostsOnly = false;
  bool _roguePostsEnabled = true;
  bool _isLoading = true;
  
  // Profile fields
  String _bio = '';
  String _subheading = '';
  File? _profileImageFile;
  String? _profileImageUrl;
  bool _isUpdatingProfile = false;
  
  late TextEditingController _bioController;
  late TextEditingController _subheadingController;

  @override
  void initState() {
    super.initState();
    _postService = PostService();
    _bioController = TextEditingController();
    _subheadingController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _subheadingController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final unseenStatus = await _postService.getUnseenPostsOnlyFlag();
      final rogueStatus = await _postService.getRoguePostsEnabledFlag();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final data = userDoc.data();
          _bio = data?['bio'] ?? '';
          _subheading = data?['profileSubheading'] ?? '';
          _profileImageUrl = data?['profileImageUrl'];
          
          _bioController.text = _bio;
          _subheadingController.text = _subheading;
        }
      }
      
      if (mounted) {
        setState(() {
          _unseenPostsOnly = unseenStatus;
          _roguePostsEnabled = rogueStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show options for Camera or Gallery
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Select Photo Source'),
          content: const Text('Choose how to get your profile picture'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Take Photo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Choose from Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      
      if (source != null) {
        final XFile? image = await picker.pickImage(source: source);
        
        if (image != null) {
          setState(() {
            _profileImageFile = File(image.path);
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfileChanges() async {
    setState(() => _isUpdatingProfile = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      Map<String, dynamic> updateData = {
        'bio': _bioController.text.trim(),
        'profileSubheading': _subheadingController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Upload profile image to Firebase Storage if a new image was selected
      if (_profileImageFile != null) {
        try {
          final fileName = 'profile_pictures/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
          
          // Upload the file
          await storageRef.putFile(_profileImageFile!);
          
          // Get the download URL
          final String downloadUrl = await storageRef.getDownloadURL();
          updateData['profileImageUrl'] = downloadUrl;
          
          print('Profile picture uploaded: $downloadUrl');
        } catch (e) {
          print('Error uploading profile picture: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading profile picture: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isUpdatingProfile = false);
          return;
        }
      }
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        setState(() {
          _bio = _bioController.text.trim();
          _subheading = _subheadingController.text.trim();
          _profileImageFile = null;
          _isUpdatingProfile = false;
        });
      }
    } catch (e) {
      print('Error updating profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => _isUpdatingProfile = false);
      }
    }
  }

  Future<void> _toggleUnseenPostsOnly(bool value) async {
    setState(() {
      _unseenPostsOnly = value;
    });
    await _postService.setUnseenPostsOnly(value);
  }

  Future<void> _toggleRoguePostsEnabled(bool value) async {
    setState(() {
      _roguePostsEnabled = value;
    });
    await _postService.setRoguePostsEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Profile Picture Section
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[300],
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: _profileImageFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _profileImageFile!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : _profileImageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      _profileImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, size: 50),
                                    ),
                                  )
                                : const Icon(Icons.person, size: 50),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _pickProfileImage,
                        icon: const Icon(Icons.edit),
                        label: const Text('Change Profile Picture'),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Bio Field
                TextField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Tell something about yourself',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.description),
                    counterText: '${_bioController.text.length}/200',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  onChanged: (value) => setState(() {}),
                ),
                
                const SizedBox(height: 16),
                
                // Profile Subheading Field
                TextField(
                  controller: _subheadingController,
                  decoration: InputDecoration(
                    labelText: 'Profile Subheading',
                    hintText: 'e.g., Photographer, Designer, Student',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.badge),
                    counterText: '${_subheadingController.text.length}/50',
                  ),
                  maxLength: 50,
                  onChanged: (value) => setState(() {}),
                ),
                
                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 24),
                
                const Text(
                  'Feed Preferences',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Unseen Posts Only Toggle
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300] ?? Colors.grey,
                    ),
                  ),
                  child: ListTile(
                    title: Text(_unseenPostsOnly ? 'Show Unseen Posts Only' : 'Show All Posts'),
                    subtitle: Text(
                      _unseenPostsOnly
                          ? 'Viewing only posts you haven\'t seen yet'
                          : 'Viewing all posts',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Switch(
                      value: _unseenPostsOnly,
                      onChanged: _toggleUnseenPostsOnly,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Rogue Posts Toggle
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300] ?? Colors.grey,
                    ),
                  ),
                  child: ListTile(
                    title: Text(_roguePostsEnabled ? 'Rogue Posts Enabled' : 'Rogue Posts Disabled'),
                    subtitle: Text(
                      _roguePostsEnabled
                          ? 'Fill empty map space with random floating posts'
                          : 'Only show posts matching your labels',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Switch(
                      value: _roguePostsEnabled,
                      onChanged: _toggleRoguePostsEnabled,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Save Button
                ElevatedButton(
                  onPressed: _isUpdatingProfile ? null : _saveProfileChanges,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    backgroundColor: Colors.blue,
                  ),
                  child: _isUpdatingProfile
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ],
            ),
    );
  }
}

Future<void> showEditProfilePopUp(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (context) {
      return PopupContainer(
        child: EditProfilePopUp(),
      );
    },
  );
}