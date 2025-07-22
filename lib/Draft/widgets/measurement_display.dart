import 'package:flutter/material.dart';
import '../models/measurement_models.dart';
import '../services/measurement_manager.dart';

class MeasurementOverlay extends StatelessWidget {
  final MeasurementLine line;
  final Offset screenPosition;
  final MeasurementManager manager;

  const MeasurementOverlay({
    Key? key,
    required this.line,
    required this.screenPosition,
    required this.manager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: screenPosition.dx - 60,
      top: screenPosition.dy - 25,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.straighten, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              manager.formatDistance(line.distance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
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

class ObjectMeasurementOverlay extends StatelessWidget {
  final DetectedObject object;
  final Offset screenPosition;
  final MeasurementManager manager;

  const ObjectMeasurementOverlay({
    Key? key,
    required this.object,
    required this.screenPosition,
    required this.manager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: screenPosition.dx - 80,
      top: screenPosition.dy - 60,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.pink.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.crop_free, color: Colors.purple, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    manager.formatArea(object.area),
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  manager.formatDistance(object.width),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.close, size: 14, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  manager.formatDistance(object.height),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MeasurementPoint3D extends StatelessWidget {
  final Offset screenPosition;
  final bool isActive;
  final int pointNumber;

  const MeasurementPoint3D({
    Key? key,
    required this.screenPosition,
    this.isActive = false,
    this.pointNumber = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: screenPosition.dx - 20,
      top: screenPosition.dy - 20,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow : Colors.green,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? Colors.yellow : Colors.green).withOpacity(0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${pointNumber + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class VirtualLine extends StatelessWidget {
  final Offset startPoint;
  final Offset endPoint;
  final Color color;

  const VirtualLine({
    Key? key,
    required this.startPoint,
    required this.endPoint,
    this.color = Colors.orange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: LinePainter(
        start: startPoint,
        end: endPoint,
        color: color,
      ),
      size: Size.infinite,
    );
  }
}

class LinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  LinePainter({
    required this.start,
    required this.end,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw main line
    canvas.drawLine(start, end, paint);

    // Draw glowing effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, glowPaint);
  }

  @override
  bool shouldRepaint(LinePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.color != color;
  }
}

class CumulativeMeasurementDisplay extends StatelessWidget {
  final double totalDistance;
  final double? totalArea;
  final MeasurementManager manager;

  const CumulativeMeasurementDisplay({
    Key? key,
    required this.totalDistance,
    this.totalArea,
    required this.manager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.9),
            Colors.grey[900]!.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.orange, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.straighten, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Distance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    manager.formatDistance(totalDistance),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (totalArea != null) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: Colors.orange.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.crop_free, color: Colors.purple, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Area',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      manager.formatArea(totalArea!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
