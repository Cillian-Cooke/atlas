import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'post_creation_page.dart';

/// Gallery page that displays all saved media from atlas_gallery
/// Users can view, select, and create posts from saved media
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<FileSystemEntity> _mediaFiles = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<String> _selectedFiles = {};

  @override
  void initState() {
    super.initState();
    _loadGalleryMedia();
  }

  /// Load all media files from the atlas_gallery directory
  Future<void> _loadGalleryMedia() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory galleryDir = Directory('${appDir.path}/atlas_gallery');

      if (!await galleryDir.exists()) {
        await galleryDir.create(recursive: true);
      }

      final List<FileSystemEntity> files = galleryDir.listSync()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      setState(() {
        _mediaFiles = files.where((file) {
          final ext = file.path.toLowerCase();
          return ext.endsWith('.jpg') || 
                 ext.endsWith('.jpeg') || 
                 ext.endsWith('.png') ||
                 ext.endsWith('.mp4');
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading gallery: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Check if a file is a video
  bool _isVideo(String path) {
    return path.toLowerCase().endsWith('.mp4');
  }

  /// Toggle selection mode
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedFiles.clear();
      }
    });
  }

  /// Toggle file selection
  void _toggleFileSelection(String filePath) {
    setState(() {
      if (_selectedFiles.contains(filePath)) {
        _selectedFiles.remove(filePath);
      } else {
        _selectedFiles.add(filePath);
      }
    });
  }

  /// Create post from selected media
  void _createPostFromSelection() {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one item')),
      );
      return;
    }

    // Separate images and videos
    final images = _selectedFiles.where((path) => !_isVideo(path)).toList();
    final videos = _selectedFiles.where((path) => _isVideo(path)).toList();

    // Navigate to post creation page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostCreationPage(
          imagePaths: images,
          videoPath: videos.isNotEmpty ? videos.first : null,
        ),
      ),
    ).then((_) {
      // Reset selection after returning
      setState(() {
        _isSelectionMode = false;
        _selectedFiles.clear();
      });
    });
  }

  /// Delete selected files
  Future<void> _deleteSelected() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: Text('Delete ${_selectedFiles.length} item(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        for (final path in _selectedFiles) {
          await File(path).delete();
        }
        
        setState(() {
          _selectedFiles.clear();
          _isSelectionMode = false;
        });
        
        await _loadGalleryMedia();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Media deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode 
            ? '${_selectedFiles.length} selected' 
            : 'Gallery'),
        centerTitle: true,
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _toggleSelectionMode,
              tooltip: 'Select',
            )
          else ...[
            if (_selectedFiles.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteSelected,
                tooltip: 'Delete',
              ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
              tooltip: 'Cancel',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 80,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No media saved yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take photos or videos to see them here',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _mediaFiles.length,
                  itemBuilder: (context, index) {
                    final file = _mediaFiles[index];
                    final isVideo = _isVideo(file.path);
                    final isSelected = _selectedFiles.contains(file.path);

                    return GestureDetector(
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleFileSelection(file.path);
                        } else {
                          // Open full screen preview
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MediaFullscreenPreview(
                                mediaPath: file.path,
                                isVideo: isVideo,
                              ),
                            ),
                          );
                        }
                      },
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          _toggleSelectionMode();
                          _toggleFileSelection(file.path);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Media thumbnail
                          if (isVideo)
                            _VideoThumbnail(videoPath: file.path)
                          else
                            Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                            ),

                          // Video indicator
                          if (isVideo && !_isSelectionMode)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 24,
                                shadows: [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),

                          // Selection overlay
                          if (_isSelectionMode)
                            Container(
                              color: isSelected
                                  ? Colors.blue.withOpacity(0.5)
                                  : Colors.black.withOpacity(0.2),
                              child: isSelected
                                  ? const Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: _isSelectionMode && _selectedFiles.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _createPostFromSelection,
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }
}

/// Video thumbnail widget
class _VideoThumbnail extends StatefulWidget {
  final String videoPath;

  const _VideoThumbnail({required this.videoPath});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.grey[800],
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return VideoPlayer(_controller!);
  }
}

/// Fullscreen media preview
class MediaFullscreenPreview extends StatefulWidget {
  final String mediaPath;
  final bool isVideo;

  const MediaFullscreenPreview({
    super.key,
    required this.mediaPath,
    required this.isVideo,
  });

  @override
  State<MediaFullscreenPreview> createState() => _MediaFullscreenPreviewState();
}

class _MediaFullscreenPreviewState extends State<MediaFullscreenPreview> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

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
    setState(() {});
  }

  void _togglePlayback() {
    if (_videoController == null) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: widget.isVideo
            ? _videoController != null && _videoController!.value.isInitialized
                ? GestureDetector(
                    onTap: _togglePlayback,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                        if (!_isPlaying)
                          const Icon(
                            Icons.play_circle_outline,
                            size: 80,
                            color: Colors.white,
                          ),
                      ],
                    ),
                  )
                : const CircularProgressIndicator()
            : Image.file(File(widget.mediaPath)),
      ),
    );
  }
}