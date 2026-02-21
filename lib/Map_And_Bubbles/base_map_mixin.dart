import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Map_And_Bubbles/label_data.dart';
import '../Map_And_Bubbles/bubble_data.dart';
import '../Map_And_Bubbles/map_logic.dart';
import '../Map_And_Bubbles/bubble_simulation.dart';
import '../PopUps/edit/edit_map.dart';

/// Mixin providing common map page logic for User and Group maps
/// Handles:
/// - Label management (loading, editing, color updates)
/// - Bubble color management
/// - Visible bubble capture
/// - Animation controller setup
mixin BaseMapMixin<T extends StatefulWidget> on State<T> {
  // These should be defined in the subclass
  List<Bubble> get bubbles;
  List<MapLabel> get labels;
  set labels(List<MapLabel> value);
  AnimationController get screenshotController;
  GlobalKey<TiledMapViewerState> get mapViewerKey;
  GlobalKey<BubbleSimulationState> get simKey;
  double get currentZoom;
  set currentZoom(double value);
  
  // Map constants
  static const double tileSize = 400.0;
  static const double visibleTiles = 8;
  
  double get mapSize => tileSize * visibleTiles;

  /// Get color for a label by index
  Color getColorFromTagIndex(int tagIndex) {
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

  /// Setup labels geometry
  void setupLabels(List<String> labelNames) {
    labels = generateGeometricLabels(
      names: labelNames,
      mapWidth: mapSize,
      mapHeight: mapSize,
      radius: 600,
    );
  }

  /// Update bubble colors based on new label arrangement
  void updateBubbleColorsForNewLabels(List<String> newLabelNames) {
    // Create new bubbles with updated colors
    final updatedBubbles = <Bubble>[];

    for (var bubble in bubbles) {
      final tagIndex = newLabelNames.indexOf(bubble.tag);
      final newColor = tagIndex >= 0 ? getColorFromTagIndex(tagIndex) : Colors.grey;

      // Create a new bubble with the updated color
      final updatedBubble = Bubble(
        position: bubble.position,
        velocity: bubble.velocity,
        size: bubble.size,
        color: newColor,
        tag: bubble.tag,
        postId: bubble.postId,
        driftPhase: bubble.driftPhase,
      );

      updatedBubbles.add(updatedBubble);
    }

    // Replace the bubbles list
    bubbles.clear();
    bubbles.addAll(updatedBubbles);
  }

  /// Handle label editing - this allows temporary label changes without saving to Firebase
  /// Returns a map with temporary settings
  Future<Map<String, dynamic>> handleLabelEdit(String editTitle, String editSubtitle) async {
    // Get current label names
    final currentLabelNames = labels.map((l) => l.name).toList();

    // Show edit popup
    final result = await showEditMapPagePopUp(
      context,
      editTitle,
      editSubtitle,
      currentLabelNames,
    );

    final tempSettings = {
      'items': <String>[],
      'isUnseen': true,
      'isRogue': true,
    };

    // If user saved changes, update local labels (not saved to Firebase)
    if (result != null && result['items'] is List && result['items'].isNotEmpty) {
      final updatedLabelNames = List<String>.from(result['items']);
      tempSettings['items'] = updatedLabelNames;
      tempSettings['isUnseen'] = result['isUnseen'] ?? true;
      tempSettings['isRogue'] = result['isRogue'] ?? true;

      setState(() {
        // Regenerate labels with new names
        setupLabels(updatedLabelNames);

        // Update bubble colors based on new label arrangement
        updateBubbleColorsForNewLabels(updatedLabelNames);
      });

      print('Labels updated locally (temporary): $updatedLabelNames');
      print('Temporary filters - Unseen: ${tempSettings['isUnseen']}, Rogue: ${tempSettings['isRogue']}');
    }
    
    return tempSettings;
  }

  /// Capture all visible bubbles and return their post IDs
  void captureVisibleBubbles() {
    final mapViewerState = mapViewerKey.currentState;
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

    // Quick flash animation
    screenshotController.forward().then((_) {
      screenshotController.reverse();
    });

    print('Captured ${visiblePostIds.length} post IDs: $visiblePostIds');

    // Pop with the captured post IDs
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

  /// Build label widgets with zoom scaling
  List<Widget> buildLabelWidgetsForMap() {
    return buildLabelWidgets(
      labels,
      (i, newPos) {
        setState(() => labels[i].position = newPos);
      },
      currentZoom,
      context,
    );
  }

  /// Create bubbles from post documents using label names
  List<Map<String, dynamic>> createBubblesDataFromPosts(
    List<DocumentSnapshot<Map<String, dynamic>>> postDocs,
    List<String> labelNames,
  ) {
    final bubbleDataList = createBubblesFromPosts(
      postDocs,
      labelNames,
      mapSize,
      mapSize,
    );
    return bubbleDataList;
  }

  /// Instantiate bubbles from bubble data
  Future<void> instantiateBubblesFromData(
    List<Map<String, dynamic>> bubbleDataList,
  ) async {
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
  }
}
