import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Custom camera page for taking photos and videos
/// After capture, prompts user to save or discard
class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  
  // Flash mode
  FlashMode _flashMode = FlashMode.off;
  
  // Camera direction
  int _selectedCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes (pause camera when app is in background)
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  /// Initialize the camera
  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras found on device')),
          );
        }
        return;
      }

      // Initialize with selected camera (default: back camera)
      _cameraController = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  /// Switch between front and back camera
  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
      _isCameraInitialized = false;
    });

    await _cameraController?.dispose();
    await _initializeCamera();
  }

  /// Toggle flash mode
  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;

    try {
      if (_flashMode == FlashMode.off) {
        _flashMode = FlashMode.auto;
      } else if (_flashMode == FlashMode.auto) {
        _flashMode = FlashMode.always;
      } else {
        _flashMode = FlashMode.off;
      }

      await _cameraController!.setFlashMode(_flashMode);
      setState(() {});
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  /// Take a photo
  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Capture the photo
      final XFile photo = await _cameraController!.takePicture();

      // Show preview and prompt to save
      if (mounted) {
        await _showMediaPreview(
          mediaPath: photo.path,
          isVideo: false,
        );
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking photo: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Start/stop video recording
  Future<void> _toggleVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      // Stop recording
      try {
        final XFile video = await _cameraController!.stopVideoRecording();
        setState(() => _isRecording = false);

        // Show preview and prompt to save
        if (mounted) {
          await _showMediaPreview(
            mediaPath: video.path,
            isVideo: true,
          );
        }
      } catch (e) {
        debugPrint('Error stopping video: $e');
      }
    } else {
      // Start recording
      try {
        await _cameraController!.startVideoRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        debugPrint('Error starting video: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error recording video: $e')),
          );
        }
      }
    }
  }

  /// Show media preview with save/discard options
  Future<void> _showMediaPreview({
    required String mediaPath,
    required bool isVideo,
  }) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewPage(
          mediaPath: mediaPath,
          isVideo: isVideo,
        ),
      ),
    );

    // If user chose to save
    if (result == true) {
      await _saveMediaToGallery(mediaPath, isVideo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVideo ? 'Video saved to gallery' : 'Photo saved to gallery',
            ),
          ),
        );
      }
    } else {
      // User discarded - delete the file
      try {
        await File(mediaPath).delete();
      } catch (e) {
        debugPrint('Error deleting media: $e');
      }
    }
  }

  /// Save media to app's local gallery
  Future<void> _saveMediaToGallery(String sourcePath, bool isVideo) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory galleryDir = Directory('${appDir.path}/atlas_gallery');
      
      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = isVideo ? 'mp4' : 'jpg';
      final String fileName = '${isVideo ? 'video' : 'image'}_$timestamp.$extension';
      final String destinationPath = '${galleryDir.path}/$fileName';

      await File(sourcePath).copy(destinationPath);
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          Center(
            child: CameraPreview(_cameraController!),
          ),

          // Top bar with controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),

                    // Flash toggle
                    IconButton(
                      icon: Icon(
                        _flashMode == FlashMode.off
                            ? Icons.flash_off
                            : _flashMode == FlashMode.auto
                                ? Icons.flash_auto
                                : Icons.flash_on,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Switch camera button
                    IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: _switchCamera,
                    ),

                    // Capture button
                    GestureDetector(
                      onTap: _takePhoto,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: _isProcessing ? Colors.grey : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),

                    // Video record button
                    GestureDetector(
                      onTap: _toggleVideoRecording,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? Colors.red : Colors.white,
                          border: Border.all(
                            color: _isRecording ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _isRecording
                            ? const Icon(Icons.stop, color: Colors.white)
                            : const Icon(Icons.videocam, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 70),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Recording...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Preview page for captured media with save/discard options
class MediaPreviewPage extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;

  const MediaPreviewPage({
    super.key,
    required this.mediaPath,
    required this.isVideo,
  });

  @override
  State<MediaPreviewPage> createState() => _MediaPreviewPageState();
}

class _MediaPreviewPageState extends State<MediaPreviewPage> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(File(widget.mediaPath));
    await _videoController!.initialize();
    _videoController!.setLooping(true);
    _videoController!.play();
    setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media preview
          Center(
            child: widget.isVideo
                ? _videoController != null && _videoController!.value.isInitialized
                    ? AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : const CircularProgressIndicator()
                : Image.file(File(widget.mediaPath)),
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Save to Gallery?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // Bottom buttons
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Discard button
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.delete),
                      label: const Text('Discard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),

                    // Save button
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}