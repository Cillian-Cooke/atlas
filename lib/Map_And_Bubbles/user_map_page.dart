import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Map_And_Bubbles/map_logic.dart';
import '../Map_And_Bubbles/bubble_data.dart';
import '../Map_And_Bubbles/label_data.dart';
import '../Map_And_Bubbles/bubble_simulation.dart';
import '../Map_And_Bubbles/base_map_mixin.dart';
import 'dart:async';
import '../Widgets/icon_button.dart';
import '../Widgets/dropdown_menu.dart';
import '../Widgets/title_header.dart';
import '../Widgets/zoom_slider.dart';
import '../Services/post_service.dart';


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

class _UserMapPageState extends State<UserMapPage> with TickerProviderStateMixin, BaseMapMixin {
  final List<Bubble> bubbles = [];

  // Base labels from Firebase (immutable during session)
  List<String> _baseLabelNames = [];

  // Temporary filter settings (edited locally, not saved to Firebase)
  bool _tempUnseenPostsOnly = false;
  // Note: _tempRoguePostsEnabled is stored for future use with rogue posts filtering
  bool _tempRoguePostsEnabled = true;

  // Current labels being displayed (can be edited locally)
  List<MapLabel> labels = [];

  final GlobalKey<BubbleSimulationState> _simKey = GlobalKey();
  final GlobalKey<TiledMapViewerState> _mapViewerKey = GlobalKey();
  final GlobalKey _userHeaderKey = GlobalKey();

  DropdownMenuController? _dropdownController;
  final PostService _postService = PostService();

  double _currentZoom = 1.0;
  bool _isLoadingBubbles = false;

  late AnimationController _screenshotController;

  // Implement mixin getters/setters
  @override
  GlobalKey<BubbleSimulationState> get simKey => _simKey;

  @override
  GlobalKey<TiledMapViewerState> get mapViewerKey => _mapViewerKey;

  @override
  AnimationController get screenshotController => _screenshotController;

  @override
  double get currentZoom => _currentZoom;

  @override
  set currentZoom(double value) {
    _currentZoom = value;
  }

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

      // Setup labels from user using mixin method
      if (_baseLabelNames.isNotEmpty) {
        setupLabels(_baseLabelNames);
      }

      // Use temporary filter settings (these override any saved settings for this session)
      final unseenPostsOnly = _tempUnseenPostsOnly;
      final seenPostIds = unseenPostsOnly ? await _postService.getSeenPostIds() : [];

      // Query all posts made by this user
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userID', isEqualTo: widget.userId)
          .get();

      print('Found ${postsQuery.docs.length} posts by user');

      // Filter out seen posts if unseenPostsOnly is enabled
      final filteredDocs = unseenPostsOnly
          ? postsQuery.docs.where((doc) => !seenPostIds.contains(doc.id)).toList()
          : postsQuery.docs;

      // Create bubbles using mixin method
      final bubbleDataList = createBubblesDataFromPosts(filteredDocs, _baseLabelNames);

      // Instantiate bubbles using mixin method
      await instantiateBubblesFromData(bubbleDataList);
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBubbles = false);
      }
    }
  }

  /// Handle local label editing - updates labels without touching Firebase
  void _handleLabelEdit() async {
    final tempSettings = await handleLabelEdit('Edit User Map', 'Edit Labels (Temporary)');
    
    // Store temporary settings
    if (tempSettings['items'].isNotEmpty) {
      setState(() {
        _tempUnseenPostsOnly = tempSettings['isUnseen'] ?? false;
        _tempRoguePostsEnabled = tempSettings['isRogue'] ?? true;
        print('Temp filters set - Unseen: $_tempUnseenPostsOnly, Rogue: $_tempRoguePostsEnabled');
      });
      
      // Reload bubbles with new temporary filters
      await _loadUserData();
    }
  }

  void _captureVisibleBubbles() {
    captureVisibleBubbles();
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
              top: 50,
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

            // Zoom Slider
            Positioned(
              top: 200,
              right: 8,
              child: ZoomSliderWidget(
                currentZoom: _currentZoom,
                onZoomChanged: (newZoom) {
                  setState(() => _currentZoom = newZoom);
                  _mapViewerKey.currentState?.setZoom(newZoom);
                },
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