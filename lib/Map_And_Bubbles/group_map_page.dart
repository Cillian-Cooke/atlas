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



class GroupMapPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final void Function(List<String>)? onCapturePostIds;
  final void Function(List<String>)? onCaptureBubbles;

  const GroupMapPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.onCapturePostIds,
    this.onCaptureBubbles,
  });

  @override
  State<GroupMapPage> createState() => _GroupMapPageState();
}

class _GroupMapPageState extends State<GroupMapPage> with TickerProviderStateMixin, BaseMapMixin {
  final List<Bubble> bubbles = [];

  // Base labels from Firebase (immutable during session)
  List<String> _baseLabelNames = [];

  // Temporary labels being used in this session (overrides base labels for bubble matching)
  List<String>? _tempLabelNames;

  // Temporary filter settings (edited locally, not saved to Firebase)
  bool _tempUnseenPostsOnly = false;
  // Note: _tempRoguePostsEnabled is stored for future use with rogue posts filtering
  bool _tempRoguePostsEnabled = true;

  // Current labels being displayed (can be edited locally)
  List<MapLabel> labels = [];

  final GlobalKey<BubbleSimulationState> _simKey = GlobalKey();
  final GlobalKey<TiledMapViewerState> _mapViewerKey = GlobalKey();
  final GlobalKey _groupHeaderKey = GlobalKey();

  DropdownMenuController? _dropdownController;

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
    _loadGroupData();
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
      triggerKey: _groupHeaderKey,
      context: context,
      width: 250,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color.fromARGB(255, 40, 40, 40)
          : Colors.white,
      borderRadius: 12,
      items: items,
    );
    
    _dropdownController?.toggle();
  }

  Future<void> _loadGroupData() async {
    if (_isLoadingBubbles) return;

    setState(() {
      _isLoadingBubbles = true;
      bubbles.clear();
    });

    try {
      final postService = PostService();
      
      // Get group document
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (!groupDoc.exists) {
        print('Group not found');
        setState(() => _isLoadingBubbles = false);
        return;
      }

      final groupData = groupDoc.data() as Map<String, dynamic>;
      final postIds = List<String>.from(groupData['posts'] ?? []);

      // Store base labels from Firebase
      _baseLabelNames = List<String>.from(groupData['labels'] ?? []);

      // Use temporary labels if they have been set, otherwise use base labels
      final labelsToUse = _tempLabelNames ?? _baseLabelNames;

      print('Loading ${postIds.length} posts and ${labelsToUse.length} labels for group ${widget.groupName} (temp: ${_tempLabelNames != null})');

      // Setup labels from group using mixin method
      if (labelsToUse.isNotEmpty) {
        setupLabels(labelsToUse);
      }

      // Use temporary filter settings (these override any saved settings for this session)
      final unseenPostsOnly = _tempUnseenPostsOnly;
      final seenPostIds = unseenPostsOnly ? await postService.getSeenPostIds() : [];

      // Fetch all posts and create bubbles
      final List<DocumentSnapshot<Map<String, dynamic>>> postDocs = [];

      for (final postId in postIds) {
        // Skip if this post has been seen and unseenPostsOnly is enabled
        if (unseenPostsOnly && seenPostIds.contains(postId)) {
          continue;
        }
        
        try {
          final postDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(postId)
              .get();

          if (postDoc.exists) {
            postDocs.add(postDoc);
          }
        } catch (e) {
          print('Error fetching post $postId: $e');
        }
      }

      // Create bubbles using the labels (temporary or base)
      final bubbleDataList = createBubblesDataFromPosts(postDocs, labelsToUse);

      // Instantiate bubbles using mixin method
      await instantiateBubblesFromData(bubbleDataList);
    } catch (e) {
      print('Error loading group data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingBubbles = false);
      }
    }
  }

  /// Handle temporary label editing - updates labels without touching Firebase
  void _handleLabelEdit() async {
    final tempSettings = await handleLabelEdit('Edit Group Map', 'Edit Labels (Temporary)');
    
    // Store temporary settings and reload bubbles
    if (tempSettings['items'].isNotEmpty) {
      setState(() {
        _tempLabelNames = List<String>.from(tempSettings['items']);
        _tempUnseenPostsOnly = tempSettings['isUnseen'] ?? false;
        _tempRoguePostsEnabled = tempSettings['isRogue'] ?? true;
        print('Temp labels and filters set - Labels: $_tempLabelNames, Unseen: $_tempUnseenPostsOnly, Rogue: $_tempRoguePostsEnabled');
      });
      
      // Reload bubbles with new temporary labels and filters
      await _loadGroupData();
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.6)
                    : Colors.white.withOpacity(0.6),
              ),
            ),

            // Header with group name and back button
            Positioned(
              top: 50,
              left: 8,
              child: Row(
                children: [
                  TitleHeaderWidget(
                    key: _groupHeaderKey,
                    title: widget.groupName,
                    subtitle: '${bubbles.length} posts • ${labels.length} labels',
                    onTap: () => _showDropdownMenu([
                      DropdownMenuItemData(
                        label: 'Group Info',
                        icon: Icons.info,
                        onTap: () {
                          print('Show group info');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'Group Settings',
                        icon: Icons.settings,
                        onTap: () {
                          print('Navigate to group settings');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'Group Chat',
                        icon: Icons.group,
                        onTap: () {
                          print('Navigate to group settings');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'Share Group',
                        icon: Icons.share,
                        onTap: () {
                          print('Share group');
                        },
                      ),
                      DropdownMenuItemData(
                        label: 'Leave Group',
                        icon: Icons.exit_to_app,
                        onTap: () {
                          print('Leave group');
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
              Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
              ),

            // Empty state
            if (!_isLoadingBubbles && bubbles.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400] 
                          : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No posts in this group yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400] 
                            : Colors.grey,
                      ),
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