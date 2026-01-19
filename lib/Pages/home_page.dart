import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Map_And_Bubbles/map_logic.dart';
import '../Map_And_Bubbles/bubble_data.dart';
import '../Map_And_Bubbles/label_data.dart';
import '../Map_And_Bubbles/bubble_simulation.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  final String title;
  final String userId;
  final void Function(List<String>)? onCaptureBubbles;
  final void Function(List<String>)? onCapturePostIds;

  const HomePage({
    super.key, 
    required this.title,
    required this.userId,
    this.onCaptureBubbles,
    this.onCapturePostIds,
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

  double _currentZoom = 1.0;
  bool _isLoadingBubbles = false;
  bool _isLoadingLabels = true;
  
  late AnimationController _screenshotController;

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
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .get(GetOptions(source: Source.server));

      if (mounted) {
        final data = doc.data();
        List<String> loadedLabels = [];

        if (data is Map<String, dynamic>) {
          // Try to get labels array from Firestore
          final labelsFromFirestore = data['labels'];
          
          if (labelsFromFirestore is List) {
            // Convert to List<String>
            loadedLabels = labelsFromFirestore
                .where((item) => item is String)
                .cast<String>()
                .toList();
          }
        }

        // If no labels found, use default
        if (loadedLabels.isEmpty) {
          loadedLabels = ["cillianCooke", "Barra", "football", "yellow"];
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
          labelNames = ["cillianCooke", "Barra", "football", "yellow"];
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
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.userId)
          .update({
        'labels': newLabels,
      });
      print('Labels saved to Firestore: $newLabels');
    } catch (e) {
      print('Error saving labels to Firestore: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save labels: $e'),
            backgroundColor: Colors.red,
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
      final generator = FirestoreBubbleGenerator(
        mapWidth: mapSize,
        mapHeight: mapSize,
        labelTags: labelNames,
        labelUsernames: labelNames,
        labelUserIDs: labelNames,
      );

      final newBubbles = await generator.fetchBubbles();
      
      for (final b in newBubbles) {
        if (mounted) {
          setState(() => bubbles.add(b));
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    } catch (e) {
      print('Error spawning bubbles from Firestore: $e');
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
          ],
        ),
      ),
    );
  }
}