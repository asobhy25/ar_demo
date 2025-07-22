import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/measurement_models.dart';
import '../services/ar_renderer.dart';

class ARTrackedPointOverlay extends StatelessWidget {
  final MeasurementPoint point;
  final ARRenderer arRenderer;
  final ARSessionManager? arSessionManager;
  final bool isActive;
  final int pointNumber;

  const ARTrackedPointOverlay({
    Key? key,
    required this.point,
    required this.arRenderer,
    required this.arSessionManager,
    this.isActive = false,
    this.pointNumber = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final anchor = arRenderer.getAnchorForPoint(point.id);
    if (anchor == null) {
      return Container(); // No anchor yet
    }

    // Get the anchor's current world position
    final worldPos = anchor.transformation.getTranslation();

    // Use a more sophisticated world-to-screen projection
    final screenPosition = _projectWorldToScreen(worldPos, context);

    return Positioned(
      left: screenPosition.dx - 25,
      top: screenPosition.dy - 25,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isActive ? Colors.yellow : Colors.orange,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: (isActive ? Colors.yellow : Colors.orange).withOpacity(0.8),
              blurRadius: 12,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${pointNumber + 1}',
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
        ),
      ),
    );
  }

  Offset _projectWorldToScreen(vector.Vector3 worldPos, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // Calculate distance from origin to determine scale
    final distance = worldPos.length;
    final scaleFactor = 400 / (distance + 1); // Perspective-like scaling

    // Project with proper perspective
    return Offset(
      centerX + (worldPos.x * scaleFactor),
      centerY - (worldPos.y * scaleFactor) + (worldPos.z * scaleFactor * 0.5),
    );
  }
}

class ARTrackedLineOverlay extends StatelessWidget {
  final MeasurementLine line;
  final ARRenderer arRenderer;
  final ARSessionManager? arSessionManager;

  const ARTrackedLineOverlay({
    Key? key,
    required this.line,
    required this.arRenderer,
    required this.arSessionManager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!arRenderer.hasAnchorsForLine(line)) {
      return Container(); // No anchors yet
    }

    final startAnchor = arRenderer.getAnchorForPoint(line.startPoint.id);
    final endAnchor = arRenderer.getAnchorForPoint(line.endPoint.id);

    if (startAnchor == null || endAnchor == null) {
      return Container();
    }

    final startWorld = startAnchor.transformation.getTranslation();
    final endWorld = endAnchor.transformation.getTranslation();

    final startScreen = _projectWorldToScreen(startWorld, context);
    final endScreen = _projectWorldToScreen(endWorld, context);

    return CustomPaint(
      painter: ARLinePainter(
        start: startScreen,
        end: endScreen,
        distance: line.distance,
      ),
      size: Size.infinite,
    );
  }

  Offset _projectWorldToScreen(vector.Vector3 worldPos, BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    // Calculate distance from origin to determine scale
    final distance = worldPos.length;
    final scaleFactor = 400 / (distance + 1); // Perspective-like scaling

    // Project with proper perspective
    return Offset(
      centerX + (worldPos.x * scaleFactor),
      centerY - (worldPos.y * scaleFactor) + (worldPos.z * scaleFactor * 0.5),
    );
  }
}

class ARLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double distance;

  ARLinePainter({
    required this.start,
    required this.end,
    required this.distance,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw main line
    final linePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, linePaint);

    // Draw glowing effect
    final glowPaint = Paint()
      ..color = Colors.orange.withOpacity(0.4)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, glowPaint);

    // Draw distance label at midpoint
    final midPoint = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${(distance * 100).toInt()} cm',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black87,
              offset: Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    // Draw background for text
    final textBg = Paint()..color = Colors.orange.withOpacity(0.9);

    final textRect = Rect.fromCenter(
      center: midPoint,
      width: textPainter.width + 16,
      height: textPainter.height + 8,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(textRect, const Radius.circular(8)),
      textBg,
    );

    textPainter.paint(
      canvas,
      Offset(
        midPoint.dx - textPainter.width / 2,
        midPoint.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(ARLinePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.distance != distance;
  }
}
