import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Map_And_Bubbles/map_logic.dart';
import '../Map_And_Bubbles/bubble_data.dart';
import '../Map_And_Bubbles/label_data.dart';
import '../Map_And_Bubbles/bubble_simulation.dart';
import '../Widgets/command_wheel.dart';
import '../Services/post_service.dart';
import 'dart:async';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  final String title;
  final String userId;
  final void Function(List<String>)? onCaptureBubbles;
  final void Function(List<String>)? onCapturePostIds;
  final void Function(double)? onZoomChanged;

  const HomePage({
    super.key, 
    required this.title,
    required this.userId,
    this.onCaptureBubbles,
    this.onCapturePostIds,
    this.onZoomChanged,
  });

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with TickerProviderStateMixin {
  
  // Editable label names (loaded from Firestore)
  List<String> labelNames = [];
  
  late List<MapLabel> labels;
  final List<Bubble> bubbles = [];
  final GlobalKey<BubbleSimulationState> _simKey = GlobalKey();
  final GlobalKey<TiledMapViewerState> _mapViewerKey = GlobalKey();
  final PostService _postService = PostService();

  double _currentZoom = 1.0;
  bool _isLoadingBubbles = false;
  bool _isLoadingLabels = true;
  
  late AnimationController _screenshotController;
  Offset? _commandWheelPosition;
  Offset? _commandWheelDragPosition;

  @override
  void initState() {
    super.initState();
    _screenshotController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loadLabelsFromFirestore();
  }

  @override
  void dispose() {
    _screenshotController.dispose();
    super.dispose();
  }

  // NEW: Load labels from Firestore
  Future<void> _loadLabelsFromFirestore() async {
    try {
      // Check if userId is valid
      if (widget.userId.isEmpty) {
        throw Exception('User ID is empty');
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .get(GetOptions(source: Source.server))
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Firestore connection timeout'),
          );

      if (mounted) {
        final data = doc.data();
        List<String> loadedLabels = [];

        if (data is Map<String, dynamic>) {
          // Try to get labels array from Firestore
          final labelsFromFirestore = data['labels'];
          
          if (labelsFromFirestore is List && labelsFromFirestore.isNotEmpty) {
            // Convert to List<String>
            loadedLabels = labelsFromFirestore
                .whereType<String>()
                .cast<String>()
                .where((label) => label.isNotEmpty)
                .toList();
          }
        }

        // If no labels found, use default
        if (loadedLabels.isEmpty) {
          loadedLabels = ["DoubleClick to View Posts"];
        }

        setState(() {
          labelNames = loadedLabels;
          _isLoadingLabels = false;
        });

        // Setup labels and spawn bubbles after loading
        _setupLabels();
        _spawnBubblesFromFirestore();
      }
    } catch (e) {
      print('Error loading labels from Firestore: $e');
      // Use default labels on error
      if (mounted) {
        setState(() {
          labelNames = ["DoubleClick to View Posts"];
          _isLoadingLabels = false;
        });
        _setupLabels();
        _spawnBubblesFromFirestore();
      }
    }
  }

  // NEW: Save labels to Firestore
  Future<void> _saveLabelsToFirestore(List<String> newLabels) async {
    try {
      // Check if userId is valid
      if (widget.userId.isEmpty) {
        print('Cannot save labels: User ID is empty');
        return;
      }

      // Filter out null or empty labels
      final validLabels = newLabels.where((label) => label.isNotEmpty).toList();
      if (validLabels.isEmpty) {
        print('Cannot save labels: No valid labels');
        return;
      }

      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .update({
        'labels': validLabels,
      }).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Save timeout'),
      );
      print('Labels saved to Firestore: $validLabels');
    } catch (e) {
      print('Error saving labels to Firestore: $e');
      // Only show error if not a connection issue on web
      if (mounted && !e.toString().contains('timeout')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Note: Labels not saved (offline or no account)'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _setupLabels() {
    const tileSize = 400.0;
    const visibleTiles = 8;
    final mapSize = tileSize * visibleTiles;

    labels = generateGeometricLabels(
      names: labelNames,
      mapWidth: mapSize,
      mapHeight: mapSize,
      radius: 600,
    );
  }

  Future<void> _spawnBubblesFromFirestore() async {
    if (_isLoadingBubbles) return;
    
    setState(() {
      _isLoadingBubbles = true;
      bubbles.clear();
    });

    const tileSize = 400.0;
    const visibleTiles = 8;
    final mapSize = tileSize * visibleTiles;

    try {
      // Get rogue posts enabled flag with fallback
      bool roguePostsEnabled = true;
      try {
        roguePostsEnabled = await _postService.getRoguePostsEnabledFlag();
      } catch (e) {
        print('Error getting rogue posts flag: $e');
        roguePostsEnabled = true; // Default to true
      }

      // Get unseenPostsOnly flag and seen posts list
      bool unseenPostsOnly = false;
      List<String> seenPostIds = [];
      try {
        unseenPostsOnly = await _postService.getUnseenPostsOnlyFlag();
        if (unseenPostsOnly) {
          seenPostIds = await _postService.getSeenPostIds();
        }
      } catch (e) {
        print('Error getting unseen posts filter: $e');
        unseenPostsOnly = false;
        seenPostIds = [];
      }

      final generator = FirestoreBubbleGenerator(
        mapWidth: mapSize,
        mapHeight: mapSize,
        labelTags: labelNames,
        labelUsernames: labelNames,
        labelUserIDs: labelNames,
        roguePostsEnabled: roguePostsEnabled,
        unseenPostsOnly: unseenPostsOnly,
        seenPostIds: seenPostIds,
      );

      final newBubbles = await generator.fetchBubbles()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => [],
          );
      
      if (newBubbles.isNotEmpty) {
        for (final b in newBubbles) {
          if (mounted) {
            setState(() => bubbles.add(b));
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
      }
    } catch (e) {
      print('Error spawning bubbles from Firestore: $e');
      // Don't crash, just continue with empty bubbles
    } finally {
      if (mounted) {
        setState(() => _isLoadingBubbles = false);
      }
    }
  }

  // MODIFIED: Now also saves to Firestore
  void updateLabelNames(List<String> newNames) {
    setState(() {
      labelNames = List.from(newNames);
      _setupLabels();
      _spawnBubblesFromFirestore();
    });
    
    // Save to Firestore
    _saveLabelsToFirestore(newNames);
  }

  List<String> getLabelNames() => List.from(labelNames);

  double getCurrentZoom() => _currentZoom;

  void setZoom(double zoomLevel) {
    _mapViewerKey.currentState?.setZoom(zoomLevel);
  }

  void _captureVisibleBubbles() {
    final mapViewerState = _mapViewerKey.currentState;
    if (mapViewerState == null) return;

    final visibleBounds = mapViewerState.getVisibleBounds();
    final visiblePostIds = <String>[];

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

    _screenshotController.forward().then((_) {
      _screenshotController.reverse();
    });

    if (widget.onCaptureBubbles != null) {
      widget.onCaptureBubbles!(visiblePostIds);
    }
    
    if (widget.onCapturePostIds != null) {
      widget.onCapturePostIds!(visiblePostIds);
    }

    print('Captured ${visiblePostIds.length} post IDs: $visiblePostIds');
  }

  void _showCommandWheel(Offset position) {
    setState(() {
      _commandWheelPosition = position;
      _commandWheelDragPosition = position;
    });
  }

  void _updateCommandWheelDrag(Offset position) {
    setState(() {
      _commandWheelDragPosition = position;
    });
  }

  void _hideCommandWheel() {
    setState(() {
      _commandWheelPosition = null;
      _commandWheelDragPosition = null;
    });
  }

  void _refreshBubbles() {
    setState(() {
      _setupLabels();
    });
    _spawnBubblesFromFirestore();
  }

  void _showAddLabelDialog() {
    final labelController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Label'),
        content: TextField(
          controller: labelController,
          decoration: const InputDecoration(
            hintText: 'Enter label name',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              final newLabels = [...labelNames, value.trim()];
              updateLabelNames(newLabels);
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final trimmedText = labelController.text.trim();
              if (trimmedText.isNotEmpty) {
                final newLabels = [...labelNames, trimmedText];
                updateLabelNames(newLabels);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const tileSize = 400.0;
    const visibleTiles = 8;
    final mapSize = tileSize * visibleTiles;

    // Show loading indicator while labels are being loaded
    if (_isLoadingLabels) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

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
        onLongPressStart: (details) {
          _showCommandWheel(details.globalPosition);
        },
        onLongPressMoveUpdate: (details) {
          _updateCommandWheelDrag(details.globalPosition);
        },
        onLongPressEnd: (_) {
          // Execute the selected command if one is selected
          if (_commandWheelPosition != null && _commandWheelDragPosition != null) {
            final wheelCenter = Offset(
              _commandWheelPosition!.dx,
              _commandWheelPosition!.dy,
            );

            final dx = _commandWheelDragPosition!.dx - wheelCenter.dx;
            final dy = _commandWheelDragPosition!.dy - wheelCenter.dy;
            final distance = math.sqrt(dx * dx + dy * dy);
            final radius = 120.0;

            // Check if within the wheel radius
            if (distance >= radius * 0.25 && distance <= radius * 1.4) {
              var angle = math.atan2(dy, dx);
              angle = (angle * 180 / math.pi) + 90;
              if (angle < 0) angle += 360;

              final itemCount = 4; // Updated to 4 commands: Edit, Attract, Reload, Add Label
              final itemAngle = 360 / itemCount;
              final index = (angle / itemAngle).floor() % itemCount;

              // Execute the selected command
              final items = [
                'Edit', 'Attract', 'Reload', 'Add Label'
              ];
              if (index >= 0 && index < items.length) {
                print(items[index]);
              }
            }
          }
          _hideCommandWheel();
        },
        child: Stack(
          children: [
            TiledMapViewer(
              key: _mapViewerKey,
              backgroundAsset: Theme.of(context).brightness == Brightness.dark
                  ? 'assets/background_dark.png' 
                  : 'assets/background_light.png',
              onZoomChanged: (z) {
                setState(() => _currentZoom = z);
                widget.onZoomChanged?.call(z);
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
            if (_isLoadingBubbles)
              Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
              ),
            // Command wheel overlay
            if (_commandWheelPosition != null)
              Positioned(
                left: _commandWheelPosition!.dx - 150,
                top: _commandWheelPosition!.dy - 150,
                child: Container(
                  color: Colors.transparent,
                  width: 300,
                  height: 300,
                  child: CommandWheel(
                    items: [
                      CommandWheelItem(
                        icon: Icons.compare_arrows,
                        label: 'Attract',
                        backgroundColor: Colors.red.withOpacity(0.7),
                        onSelected: () {
                          print('Attract');
                          _hideCommandWheel();
                        },
                      ),
                      CommandWheelItem(
                        icon: Icons.refresh,
                        label: 'Reload',
                        backgroundColor: Colors.pink.withOpacity(0.7),
                        onSelected: () {
                          _refreshBubbles();
                          _hideCommandWheel();
                        },
                      ),
                      CommandWheelItem(
                        icon: Icons.add,
                        label: 'Add Label',
                        backgroundColor: Colors.green.withOpacity(0.7),
                        onSelected: () {
                          _showAddLabelDialog();
                          _hideCommandWheel();
                        },
                      ),
                    ],
                    dragPosition: _commandWheelDragPosition != null
                        ? Offset(
                            _commandWheelDragPosition!.dx - _commandWheelPosition!.dx + 150,
                            _commandWheelDragPosition!.dy - _commandWheelPosition!.dy + 150,
                          )
                        : null,
                    radius: 120,
                    iconSize: 32,
                    centerColor: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}