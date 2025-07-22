import 'package:vector_math/vector_math_64.dart' as vector;

class MeasurementPoint {
  final String id;
  final vector.Vector3 position;
  final DateTime timestamp;

  MeasurementPoint({
    required this.id,
    required this.position,
    required this.timestamp,
  });
}

class MeasurementLine {
  final String id;
  final MeasurementPoint startPoint;
  final MeasurementPoint endPoint;
  final double distance;

  MeasurementLine({
    required this.id,
    required this.startPoint,
    required this.endPoint,
  }) : distance = (endPoint.position - startPoint.position).length;
}

class MeasurementPolygon {
  final String id;
  final List<MeasurementPoint> points;
  final List<MeasurementLine> lines;
  final double perimeter;
  final double? area;
  final bool isClosed;

  MeasurementPolygon({
    required this.id,
    required this.points,
    required this.lines,
    required this.isClosed,
  })  : perimeter = lines.fold(0.0, (sum, line) => sum + line.distance),
        area = isClosed ? _calculateArea(points) : null;

  static double? _calculateArea(List<MeasurementPoint> points) {
    if (points.length < 3) return null;

    // Using shoelace formula for polygon area
    double area = 0.0;
    for (int i = 0; i < points.length; i++) {
      int j = (i + 1) % points.length;
      area += points[i].position.x * points[j].position.z;
      area -= points[j].position.x * points[i].position.z;
    }
    return (area.abs() / 2.0);
  }
}

class DetectedObject {
  final String id;
  final List<vector.Vector3> corners;
  final double width;
  final double height;
  final double area;
  final ObjectType type;

  DetectedObject({
    required this.id,
    required this.corners,
    required this.type,
  })  : width = (corners[1] - corners[0]).length,
        height = (corners[2] - corners[1]).length,
        area = (corners[1] - corners[0]).length * (corners[2] - corners[1]).length;
}

enum ObjectType { rectangle, square, plane, custom }

enum MeasurementMode { distance, area, level, automatic }
