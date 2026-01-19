import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Map_And_Bubbles/map_logic.dart';
import '../Map_And_Bubbles/bubble_data.dart';
import '../Map_And_Bubbles/label_data.dart';
import '../Map_And_Bubbles/bubble_simulation.dart';
import 'dart:async';
import '../PopUps/edit/edit_map.dart';
import '../Widgets/icon_button.dart';
import '../Widgets/dropdown_menu.dart';
import '../Widgets/title_header.dart';


class UserMapPage extends StatefulWidget {
  final String userId;
  final String userName;
  final void Function(List<String>)? onCapturePostIds;
  final void Function(List<String>)? onCaptureBubbles;

  const UserMapPage({
    super.key,
    required this.userId,
    required this.userName,
    this.onCapturePostIds,
    this.onCaptureBubbles,
  });

  @override
  State<UserMapPage> createState() => _UserMapPageState();
}

class _UserMapPageState extends State<UserMapPage> with TickerProviderStateMixin {
  final List<Bubble> bubbles = [];
  
  // Base labels from Firebase (immutable during session)
  List<String> _baseLabelNames = [];
  
  // Current labels being displayed (can be edited locally)
  List<MapLabel> labels = [];
  
  final GlobalKey<BubbleSimulationState> _simKey = GlobalKey();
  final GlobalKey<TiledMapViewerState> _mapViewerKey = GlobalKey();
  final GlobalKey _userHeaderKey = GlobalKey();
  
  DropdownMenuController? _dropdownController;

  double _currentZoom = 1.0;
  bool _isLoadingBubbles = false;

  late AnimationController _screenshotController;

  @override
  void initState() {
    super.initState();
    _screenshotController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _screenshotController.dispose();
    _dropdownController?.dispose();
    super.dispose();
  }

  void _showDropdownMenu(List<DropdownMenuItemData> items) {
    _dropdownController?.dispose();
    
    _dropdownController = DropdownMenuController(
      triggerKey: _userHeaderKey,
      context: context,
      width: 250,
      backgroundColor: Colors.white,
      borderRadius: 12,
      items: items,
    );
    
    _dropdownController?.toggle();
  }

  Future<void> _loadUserData() async {
    if (_isLoadingBubbles) return;

    setState(() {
      _isLoadingBubbles = true;
      bubbles.clear();
    });

    const tileSize = 400.0;
    const visibleTiles = 8;
    final mapSize = tileSize * visibleTiles;

    try {
      // Get user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        print('User not found');
        setState(() => _isLoadingBubbles = false);
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Store base labels from user's userMapLabels field
      _baseLabelNames = List<String>.from(userData['userMapLabels'] ?? []);

      print('Loading posts for user ${widget.userName} with ${_baseLabelNames.length} labels');

      // Setup labels from user - this creates the initial working copy
      if (_baseLabelNames.isNotEmpty) {
        labels = generateGeometricLabels(
          names: _baseLabelNames,
          mapWidth: mapSize,
          mapHeight: mapSize,
          radius: 600,
        );
      }

      // Query all posts made by this user
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userID', isEqualTo: widget.userId)
          .get();

      print('Found ${postsQuery.docs.length} posts by user');

      // Create bubbles using shared logic
      final bubbleDataList = createBubblesFromPosts(
        postsQuery.docs,
        _baseLabelNames,
        mapSize,
        mapSize,
      );

      // Instantiate bubbles with calculated data
      for (final bubbleData in bubbleDataList) {
        try {
          final bubble = Bubble(
            position: Offset(bubbleData['x'], bubbleData['y']),
            velocity: Offset.zero,
            size: bubbleData['size'],
            color: bubbleData['color'],
            tag: bubbleData['tag'],
            postId: bubbleData['postId'],
          );

          if (mounted) {
            setState(() => bubbles.add(bubble));
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } catch (e) {
          print('Error creating bubble: $e');
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBubbles = false);
      }
    }
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

  /// Handle local label editing - updates labels without touching Firebase
  void _handleLabelEdit() async {
    // Get current label names
    final currentLabelNames = labels.map((l) => l.name).toList();
    
    // Show edit popup
    final updatedLabelNames = await showEditMapPagePopUp(
      context,
      'Edit User Map',
      'Edit Labels (Local Only)',
      currentLabelNames,
    );

    // If user saved changes, update local labels
    if (updatedLabelNames != null && updatedLabelNames.isNotEmpty) {
      setState(() {
        const tileSize = 400.0;
        const visibleTiles = 8;
        final mapSize = tileSize * visibleTiles;

        // Regenerate labels with new names
        labels = generateGeometricLabels(
          names: updatedLabelNames,
          mapWidth: mapSize,
          mapHeight: mapSize,
          radius: 600,
        );

        // Optionally: You could also update bubble colors here based on new label arrangement
        // This would make bubbles re-color based on the new label order
        _updateBubbleColorsForNewLabels(updatedLabelNames);
      });

      print('Labels updated locally: $updatedLabelNames');
      print('Base labels remain unchanged: $_baseLabelNames');
    }
  }

  /// Update bubble colors based on new label arrangement
  void _updateBubbleColorsForNewLabels(List<String> newLabelNames) {
    // Create new bubbles with updated colors
    final updatedBubbles = <Bubble>[];
    
    for (var bubble in bubbles) {
      final tagIndex = newLabelNames.indexOf(bubble.tag);
      final newColor = tagIndex >= 0 ? _getColorFromTagIndex(tagIndex) : Colors.grey;
      
      // Create a new bubble with the updated color
      final updatedBubble = Bubble(
        position: bubble.position,
        velocity: bubble.velocity,
        size: bubble.size,
        color: newColor,
        tag: bubble.tag,
        postId: bubble.postId,
      );
      
      updatedBubbles.add(updatedBubble);
    }
    
    // Replace the bubbles list
    bubbles.clear();
    bubbles.addAll(updatedBubbles);
  }

  void _captureVisibleBubbles() {
    final mapViewerState = _mapViewerKey.currentState;
    if (mapViewerState == null) return;

    final visibleBounds = mapViewerState.getVisibleBounds();
    final visiblePostIds = <String>[];

    // Collect all visible bubble post IDs
    for (final b in bubbles) {
      final r = b.radius;
      if (b.position.dx - r < visibleBounds.right &&
          b.position.dx + r > visibleBounds.left &&
          b.position.dy - r < visibleBounds.bottom &&
          b.position.dy + r > visibleBounds.top) {
        if (b.postId.isNotEmpty) {
          visiblePostIds.add(b.postId);
        }
      }
    }

    // Quick flash animation (optional - can be removed)
    _screenshotController.forward().then((_) {
      _screenshotController.reverse();
    });

    // Debug output
    print('Captured ${visiblePostIds.length} post IDs: $visiblePostIds');

    // Immediately pop with the captured post IDs (like HomePage)
    if (visiblePostIds.isNotEmpty) {
      Navigator.pop(context, visiblePostIds);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No posts visible in current view'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const tileSize = 400.0;
    const visibleTiles = 8;
    final mapSize = tileSize * visibleTiles;

    // Build label widgets dynamically with zoom scaling
    final labelWidgets = buildLabelWidgets(
      labels,
      (i, newPos) {
        setState(() => labels[i].position = newPos);
      },
      _currentZoom,
      context,
    );

    return Scaffold(
      body: GestureDetector(
        onDoubleTap: _captureVisibleBubbles,
        child: Stack(
          children: [
            TiledMapViewer(
              key: _mapViewerKey,
              backgroundAsset: Theme.of(context).brightness == Brightness.dark
                ? 'assets/background_dark.png' 
                  : 'assets/background_light.png',
              onZoomChanged: (z) {
                setState(() => _currentZoom = z);
              },
              mapObjects: [
                SizedBox(
                  width: mapSize,
                  height: mapSize,
                  child: BubbleSimulation(
                    key: _simKey,
                    bubbles: bubbles,
                    labels: labels,
                    mapWidth: mapSize,
                    mapHeight: mapSize,
                  ),
                ),
                ...labelWidgets,
              ],
            ),

            // Screenshot animation overlay
            ScaleTransition(
              scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: _screenshotController, curve: Curves.easeOut),
              ),
              child: Container(
                color: Colors.white.withOpacity(0.6),
              ),
            ),

            // Header with user name and back button
            Positioned(
              top: 10,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  TitleHeaderWidget(
                    key: _userHeaderKey,
                    title: widget.userName,
                    subtitle: '${bubbles.length} posts • ${labels.length} labels',
                    onTap: () => _showDropdownMenu([
                      DropdownMenuItemData(
                        label: 'User Info',
                        icon: Icons.person,
                        onTap: () {
                          print('Show user info');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'View Profile',
                        icon: Icons.account_circle,
                        onTap: () {
                          print('Navigate to user profile');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'Direct Message',
                        icon: Icons.message,
                        onTap: () {
                          print('Share user map');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'Share Map',
                        icon: Icons.share,
                        onTap: () {
                          print('Share user map');
                        },
                      ),
                    ]),
                  ),
                  const Spacer(),
                ],
              ),
            ),


            Positioned(
              top: 50,
              right: 8,
              child: IconButtonWidget(
                icon: Icons.edit,
                onPressed: _handleLabelEdit,
                buttonSize: 70,
              ),
            ),

            // Loading indicator
            if (_isLoadingBubbles)
              const Center(
                child: CircularProgressIndicator(),
              ),

            // Empty state
            if (!_isLoadingBubbles && bubbles.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No posts by ${widget.userName} yet',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}