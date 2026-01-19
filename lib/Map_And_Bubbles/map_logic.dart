import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

class TiledMapViewer extends StatefulWidget {
  final String backgroundAsset;
  final double tileSize;
  final int visibleTiles;
  final List<Widget> mapObjects;

  /// Notifies parent when zoom changes
  final void Function(double zoom)? onZoomChanged;

  const TiledMapViewer({
    super.key,
    required this.backgroundAsset,
    this.tileSize = 400.0,
    this.visibleTiles = 8,
    this.mapObjects = const [],
    this.onZoomChanged,
  });

  @override
  State<TiledMapViewer> createState() => TiledMapViewerState();
}

class TiledMapViewerState extends State<TiledMapViewer> with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late AnimationController _zoomAnimationController;
  late Animation<double> _zoomAnimation;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();

    // Setup zoom animation controller
    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create smooth zoom animation from far (0.25x) to normal (1.0x)
    _zoomAnimation = Tween<double>(
      begin: 0.25,
      end: 0.4,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOutCubic,
    ));

    _zoomAnimation.addListener(() {
      _updateZoomTransform();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startZoomInAnimation();
    });

    // Emit zoom updates
    _controller.addListener(() {
      final zoom = _controller.value.getMaxScaleOnAxis();
      widget.onZoomChanged?.call(zoom);
    });
  }

  /// Starts the zoom-in animation from far away
  void _startZoomInAnimation() {
    if (_hasAnimated) return;
    _hasAnimated = true;

    final size = MediaQuery.of(context).size;
    final mapSize = widget.tileSize * widget.visibleTiles;

    // Calculate center position
    final offsetX = (size.width - mapSize) / 2;
    final offsetY = (size.height - mapSize) / 2;

    // Start at far zoom (0.25x scale)
    _controller.value = Matrix4.identity()
      ..translate(offsetX + mapSize / 2, offsetY + mapSize / 2)
      ..scale(0.25)
      ..translate(-mapSize / 2, -mapSize / 2);

    // Animate to normal zoom
    _zoomAnimationController.forward();
  }

  /// Updates the transform during animation
  void _updateZoomTransform() {
    final size = MediaQuery.of(context).size;
    final mapSize = widget.tileSize * widget.visibleTiles;

    final offsetX = (size.width - mapSize) / 2;
    final offsetY = (size.height - mapSize) / 2;

    final currentScale = _zoomAnimation.value;

    // Apply zoom animation while keeping map centered
    _controller.value = Matrix4.identity()
      ..translate(offsetX + mapSize / 2, offsetY + mapSize / 2)
      ..scale(currentScale)
      ..translate(-mapSize / 2, -mapSize / 2);
  }


  /// Returns visible map region in map-space
  Rect getVisibleBounds() {
    final size = MediaQuery.of(context).size;
    final inverse = Matrix4.copy(_controller.value)..invert();

    final topLeft = inverse.perspectiveTransform(Vector3(0, 0, 0));
    final bottomRight =
        inverse.perspectiveTransform(Vector3(size.width, size.height, 0));

    return Rect.fromPoints(
      Offset(topLeft.x, topLeft.y),
      Offset(bottomRight.x, bottomRight.y),
    );
  }

  @override
  void dispose() {
    _zoomAnimationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapSize = widget.tileSize * widget.visibleTiles;

    return InteractiveViewer(
      transformationController: _controller,
      minScale: 0.25,
      maxScale: 4.0,
      boundaryMargin: EdgeInsets.zero,
      constrained: false,
      child: SizedBox(
        width: mapSize,
        height: mapSize,
        child: Stack(
          children: [
            // Tiled Background
            Positioned.fill(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.visibleTiles,
                  childAspectRatio: 1.0,
                ),
                itemCount: widget.visibleTiles * widget.visibleTiles,
                itemBuilder: (context, index) {
                  return Image.asset(
                    widget.backgroundAsset,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),

            // Map objects (labels, bubbles, markers, etc.)
            ...widget.mapObjects,
          ],
        ),
      ),
    );
  }
}