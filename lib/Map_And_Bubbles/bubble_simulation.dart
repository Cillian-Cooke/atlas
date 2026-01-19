import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'bubble_data.dart';
import 'label_data.dart';

class BubbleSimulation extends StatefulWidget {
  final List<Bubble> bubbles;
  final List<MapLabel> labels;
  final double mapWidth;
  final double mapHeight;

  const BubbleSimulation({
    Key? key,
    required this.bubbles,
    required this.labels,
    required this.mapWidth,
    required this.mapHeight,
  }) : super(key: key);

  @override
  BubbleSimulationState createState() => BubbleSimulationState();
}

class BubbleSimulationState extends State<BubbleSimulation>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void setDragging(bool d) {
    // no-op for now; kept for API compatibility
  }

  void _onTick(Duration elapsed) {
    final dt = (_lastTick == Duration.zero)
        ? 0.016
        : (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;

    // simple physics update
    final bubbles = widget.bubbles;
    final labels = {for (var l in widget.labels) l.name.toLowerCase(): l.position};

    const double maxSpeed = 160.0; // px/sec
    const double accel = 300.0; // px/sec^2
    const double drag = 0.9;
    const double driftSpeed = 15.0; // px/sec for driftless bubbles (reduced from 40)

    // Move toward target or apply individual drift
    for (final b in bubbles) {
      final tagKey = b.tag.toLowerCase();
      final target = labels[tagKey];
      if (target != null) {
        // Bubble has a target: steer toward it
        final dir = target - b.position;
        final dist = dir.distance;
        if (dist > 0.1) {
          final desired = Offset(dir.dx / dist, dir.dy / dist) * maxSpeed;
          final steer = desired - b.velocity;
          // limit steer
          final steerMag = steer.distance;
          final maxSteer = accel * dt;
          final appliedSteer = (steerMag > maxSteer && steerMag > 0)
              ? steer * (maxSteer / steerMag)
              : steer;
          b.velocity += appliedSteer;
        }
      } else {
        // Bubble has no target: apply individual random drift
        b.driftPhase += dt * 0.5; // phase controls when to pick a new random direction
        
        // Pick a new random direction periodically (~every 2 seconds)
        if (b.driftPhase > 1.0) {
          b.driftPhase = 0.0;
          final randomAngle = _random.nextDouble() * 2 * pi;
          final driftDir = Offset(cos(randomAngle), sin(randomAngle)) * driftSpeed;
          b.velocity += driftDir * 0.5; // gentle nudge, not full replacement
        }
      }

      // drag (applies to all bubbles)
      b.velocity *= pow(drag, dt).toDouble();

      // clamp speed
      final speed = b.velocity.distance;
      if (speed > maxSpeed) {
        b.velocity = (b.velocity / speed) * maxSpeed;
      }

      // integrate
      b.position += b.velocity * dt;
    }

    // simple collision push
    for (int i = 0; i < bubbles.length; i++) {
      for (int j = i + 1; j < bubbles.length; j++) {
        final a = bubbles[i];
        final b = bubbles[j];
        final dx = b.position.dx - a.position.dx;
        final dy = b.position.dy - a.position.dy;
        final dist = sqrt(dx * dx + dy * dy);
        final minDist = a.radius + b.radius + 1;
        if (dist < minDist && dist > 0) {
          final push = (minDist - dist) / 2;
          final nx = dx / dist;
          final ny = dy / dist;
          a.position = a.position - Offset(nx * push, ny * push);
          b.position = b.position + Offset(nx * push, ny * push);
        }
      }
    }

    // clamp inside map
    for (final b in bubbles) {
      final r = b.radius;
      b.position = Offset(
        b.position.dx.clamp(r, widget.mapWidth - r),
        b.position.dy.clamp(r, widget.mapHeight - r),
      );
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: widget.bubbles.map((b) {
        final radius = b.radius;
        return Positioned(
          left: b.position.dx - radius,
          top: b.position.dy - radius,
          child: Container(
            width: b.size,
            height: b.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: b.color.withOpacity(0.65),
              border: Border.all(color: b.color, width: 2),
            ),
            alignment: Alignment.center,
          ),
        );
      }).toList(),
    );
  }
}
