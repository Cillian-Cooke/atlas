import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A command item for the radial wheel
class CommandWheelItem {
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? iconColor;
  final VoidCallback onSelected;

  CommandWheelItem({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.backgroundColor,
    this.iconColor,
  });
}

/// Radial command wheel widget (like a video game pie menu)
class CommandWheel extends StatefulWidget {
  final List<CommandWheelItem> items;
  final double radius;
  final double iconSize;
  final Color centerColor;
  final Color backgroundColor;
  final double wheelThickness;
  final Offset? dragPosition;
  final VoidCallback? onDragEnd;

  const CommandWheel({
    super.key,
    required this.items,
    this.radius = 140,
    this.iconSize = 28,
    this.centerColor = Colors.black,
    this.backgroundColor = Colors.white,
    this.wheelThickness = 80,
    this.dragPosition,
    this.onDragEnd,
  });

  @override
  State<CommandWheel> createState() => _CommandWheelState();
}

class _CommandWheelState extends State<CommandWheel>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommandWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dragPosition != null) {
      _updateSelectedIndex(widget.dragPosition!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.radius * 2.8,
          height: widget.radius * 2.8,
          child: CustomPaint(
            painter: WheelPainter(
              items: widget.items,
              radius: widget.radius,
              selectedIndex: _selectedIndex,
              centerColor: widget.centerColor,
              backgroundColor: widget.backgroundColor,
              wheelThickness: widget.wheelThickness,
              iconSize: widget.iconSize,
              animationValue: _scaleAnimation.value,
            ),
            child: Container(),
          ),
        ),
      ),
    );
  }

  void _updateSelectedIndex(Offset position) {
    final center = Offset(
      widget.radius * 1.4,
      widget.radius * 1.4,
    );

    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Check if within the donut radius range
    final innerBound = widget.radius * 0.3;
    final outerBound = widget.radius * 1.6;

    if (distance < innerBound || distance > outerBound) {
      setState(() {
        _selectedIndex = null;
      });
      return;
    }

    // Calculate angle
    var angle = math.atan2(dy, dx);
    angle = (angle * 180 / math.pi) + 90; // Convert to degrees and rotate
    if (angle < 0) angle += 360;

    final itemAngle = 360 / widget.items.length;
    final index = (angle / itemAngle).floor() % widget.items.length;

    setState(() {
      _selectedIndex = index;
    });
  }
}

/// Custom painter for the radial wheel
class WheelPainter extends CustomPainter {
  final List<CommandWheelItem> items;
  final double radius;
  final int? selectedIndex;
  final Color centerColor;
  final Color backgroundColor;
  final double wheelThickness;
  final double iconSize;
  final double animationValue;

  WheelPainter({
    required this.items,
    required this.radius,
    required this.selectedIndex,
    required this.centerColor,
    required this.backgroundColor,
    required this.wheelThickness,
    required this.iconSize,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final itemCount = items.length;
    final anglePerItem = 360 / itemCount;
    
    // Spacing between segments (in degrees)
    final gapAngle = 8.0;

    // Draw wheel segments
    for (int i = 0; i < itemCount; i++) {
      final startAngle = (i * anglePerItem - 90 + gapAngle / 2) * math.pi / 180;
      final sweepAngle = (anglePerItem - gapAngle) * math.pi / 180;

      final isSelected = i == selectedIndex;

      // Larger inner radius to create open center
      final innerRad = radius * 0.35;
      final outerRad = isSelected ? radius * 1.5 : radius * 1.3;

      // Draw segment shadow for selected item
      if (isSelected) {
        _drawSegmentShadow(canvas, center, innerRad, outerRad, startAngle, sweepAngle);
      }

      // Draw segment with transparency
      final segmentColor = isSelected 
          ? Colors.black.withOpacity(0.85) 
          : Colors.white.withOpacity(0.75);
      final paint = Paint()
        ..color = segmentColor
        ..style = PaintingStyle.fill;

      _drawPillSegment(
          canvas, center, innerRad, outerRad, startAngle, sweepAngle, paint);

      // Draw segment border with transparency
      final borderPaint = Paint()
        ..color = isSelected 
            ? Colors.black.withOpacity(0.9) 
            : Colors.black.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;

      _drawPillSegment(canvas, center, innerRad, outerRad, startAngle,
          sweepAngle, borderPaint);

      // Draw icon and label
      _drawIconAndLabel(canvas, center, items[i], i, innerRad, outerRad,
          startAngle, sweepAngle, isSelected);
    }
  }

  void _drawSegmentShadow(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double outerRadius,
    double startAngle,
    double sweepAngle,
  ) {
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    _drawPillSegment(
      canvas,
      center.translate(0, 4),
      innerRadius,
      outerRadius,
      startAngle,
      sweepAngle,
      shadowPaint,
    );
  }

  void _drawPillSegment(
    Canvas canvas,
    Offset center,
    double innerRadius,
    double outerRadius,
    double startAngle,
    double sweepAngle,
    Paint paint,
  ) {
    final path = Path();
    
    // Calculate the width of the segment
    final segmentWidth = outerRadius - innerRadius;
    
    // Use larger radius for smoother, more pill-like curves
    final cornerRadius = segmentWidth * 0.48; // Nearly half the width for pill shape

    // Calculate control points for smooth bezier curves
    final innerStartPoint = Offset(
      center.dx + innerRadius * math.cos(startAngle),
      center.dy + innerRadius * math.sin(startAngle),
    );

    final outerStartPoint = Offset(
      center.dx + outerRadius * math.cos(startAngle),
      center.dy + outerRadius * math.sin(startAngle),
    );

    final innerEndPoint = Offset(
      center.dx + innerRadius * math.cos(startAngle + sweepAngle),
      center.dy + innerRadius * math.sin(startAngle + sweepAngle),
    );

    // Start path
    path.moveTo(innerStartPoint.dx, innerStartPoint.dy);

    // Smooth curved transition from inner to outer edge (start side)
    final startControl1 = Offset(
      center.dx + (innerRadius + cornerRadius) * math.cos(startAngle),
      center.dy + (innerRadius + cornerRadius) * math.sin(startAngle),
    );
    final startControl2 = Offset(
      center.dx + (outerRadius - cornerRadius) * math.cos(startAngle),
      center.dy + (outerRadius - cornerRadius) * math.sin(startAngle),
    );
    
    path.cubicTo(
      startControl1.dx, startControl1.dy,
      startControl2.dx, startControl2.dy,
      outerStartPoint.dx, outerStartPoint.dy,
    );

    // Outer arc
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      sweepAngle,
      false,
    );

    // Smooth curved transition from outer to inner edge (end side)
    final endControl1 = Offset(
      center.dx + (outerRadius - cornerRadius) * math.cos(startAngle + sweepAngle),
      center.dy + (outerRadius - cornerRadius) * math.sin(startAngle + sweepAngle),
    );
    final endControl2 = Offset(
      center.dx + (innerRadius + cornerRadius) * math.cos(startAngle + sweepAngle),
      center.dy + (innerRadius + cornerRadius) * math.sin(startAngle + sweepAngle),
    );
    
    path.cubicTo(
      endControl1.dx, endControl1.dy,
      endControl2.dx, endControl2.dy,
      innerEndPoint.dx, innerEndPoint.dy,
    );

    // Inner arc back
    path.arcTo(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle + sweepAngle,
      -sweepAngle,
      false,
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawIconAndLabel(
    Canvas canvas,
    Offset center,
    CommandWheelItem item,
    int index,
    double innerRadius,
    double outerRadius,
    double startAngle,
    double sweepAngle,
    bool isSelected,
  ) {
    // Calculate position for icon (middle of the segment)
    final angle = startAngle + sweepAngle / 2;
    final iconRadius = (innerRadius + outerRadius) / 2;
    final iconPosition = Offset(
      center.dx + iconRadius * math.cos(angle),
      center.dy + iconRadius * math.sin(angle),
    );

    // Draw icon using TextPainter
    final iconColor = isSelected ? Colors.white : Colors.black87;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(item.icon.codePoint),
        style: TextStyle(
          fontSize: isSelected ? iconSize * 1.5 : iconSize,
          fontFamily: item.icon.fontFamily,
          package: item.icon.fontPackage,
          color: iconColor,
          shadows: isSelected ? [
            Shadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
      ),
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        iconPosition.dx - textPainter.width / 2,
        iconPosition.dy - textPainter.height / 2,
      ),
    );

    // Draw label if selected
    if (isSelected) {
      final labelRadius = outerRadius * 1.15;
      final labelPosition = Offset(
        center.dx + labelRadius * math.cos(angle),
        center.dy + labelRadius * math.sin(angle),
      );

      final labelPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        text: TextSpan(
          text: item.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      );

      labelPainter.layout();
      
      // Draw label shadow
      final labelRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: labelPosition.translate(0, 2),
          width: labelPainter.width + 16,
          height: labelPainter.height + 8,
        ),
        const Radius.circular(14),
      );
      
      canvas.drawRRect(
        labelRect,
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Draw label background with transparency
      final labelBgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: labelPosition,
          width: labelPainter.width + 16,
          height: labelPainter.height + 8,
        ),
        const Radius.circular(14),
      );
      
      canvas.drawRRect(
        labelBgRect,
        Paint()
          ..color = Colors.white.withOpacity(0.95)
          ..style = PaintingStyle.fill,
      );
      
      // Draw label border with transparency
      canvas.drawRRect(
        labelBgRect,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Draw label text
      labelPainter.paint(
        canvas,
        Offset(
          labelPosition.dx - labelPainter.width / 2,
          labelPosition.dy - labelPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.items.length != items.length ||
        oldDelegate.animationValue != animationValue;
  }
}

/// Press-and-hold overlay for showing the wheel
class CommandWheelOverlay {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required List<CommandWheelItem> items,
    required Offset position,
  }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Semi-transparent background
          Positioned.fill(
            child: GestureDetector(
              onTap: hide,
              child: Container(
                color: Colors.black.withOpacity(0.35),
              ),
            ),
          ),
          // Wheel positioned at touch point
          Positioned(
            left: position.dx - 196,
            top: position.dy - 196,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 392,
                height: 392,
                child: CommandWheel(
                  items: items,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}