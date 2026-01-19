import 'dart:math';
import 'package:flutter/material.dart';

class MapLabel {
  Offset position;
  final String name;

  MapLabel({
    required this.position,
    required this.name,
  });
}

/// Place labels evenly in a circular formation
List<MapLabel> generateGeometricLabels({
  required List<String> names,
  required double mapWidth,
  required double mapHeight,
  double radius = 250,
}) {
  final center = Offset(mapWidth / 2, mapHeight / 2);
  final count = names.length;

  return List.generate(count, (i) {
    final angle = (2 * pi / count) * i - pi / 2;

    return MapLabel(
      position: Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      ),
      name: names[i],
    );
  });
}

/// Build draggable labels that dynamically scale with zoom
List<Widget> buildLabelWidgets(
  
  List<MapLabel> labels,
  void Function(int index, Offset newPos) onDrag,
  double zoom,
  BuildContext context,
) {
  const baseFont = 14.0;
  const baseHPad = 12.0;
  const baseVPad = 6.0;

  final visualScale = 1 / zoom; // inverse scaling: bigger when zoomed out
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final labelBgColor = isDark 
      ? Colors.white.withOpacity(0.2) 
      : Colors.black.withOpacity(0.7);
  final labelTextColor = isDark ? Colors.white : Colors.white;

  return List.generate(labels.length, (i) {
    final label = labels[i];

    return Positioned(
      left: label.position.dx,
      top: label.position.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          // ← follow cursor 1:1, independent of zoom
          onPanUpdate: (d) => onDrag(i, label.position + d.delta),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: baseHPad * visualScale,
              vertical: baseVPad * visualScale,
            ),
            decoration: BoxDecoration(
              color: labelBgColor,
              borderRadius: BorderRadius.circular(10 * visualScale),
            ),
            child: Text(
              label.name,
              style: TextStyle(
                color: labelTextColor,
                fontSize: baseFont * visualScale,
              ),
            ),
          ),
        ),
      ),
    );
  });
}

