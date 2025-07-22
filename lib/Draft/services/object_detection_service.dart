import 'dart:math' as math;
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/measurement_models.dart';

class ObjectDetectionService {
  // Threshold for considering points coplanar
  static const double planarThreshold = 0.05; // 5cm

  // Detect rectangular objects from hit test results
  static DetectedObject? detectRectangle(List<ARHitTestResult> hits) {
    if (hits.length < 4) return null;

    // Try to find 4 coplanar points that form a rectangle
    for (int i = 0; i < hits.length - 3; i++) {
      for (int j = i + 1; j < hits.length - 2; j++) {
        for (int k = j + 1; k < hits.length - 1; k++) {
          for (int l = k + 1; l < hits.length; l++) {
            final corners = [
              hits[i].worldTransform.getTranslation(),
              hits[j].worldTransform.getTranslation(),
              hits[k].worldTransform.getTranslation(),
              hits[l].worldTransform.getTranslation(),
            ];

            if (_areCoplanar(corners) && _isRectangle(corners)) {
              // Sort corners in order
              final sortedCorners = _sortRectangleCorners(corners);

              return DetectedObject(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                corners: sortedCorners,
                type: _determineObjectType(sortedCorners),
              );
            }
          }
        }
      }
    }

    return null;
  }

  // Check if points are coplanar
  static bool _areCoplanar(List<vector.Vector3> points) {
    if (points.length < 4) return false;

    // Calculate plane from first 3 points
    final v1 = points[1] - points[0];
    final v2 = points[2] - points[0];
    final normal = v1.cross(v2).normalized();

    // Check if 4th point lies on the same plane
    final v3 = points[3] - points[0];
    final distance = (normal.dot(v3)).abs();

    return distance < planarThreshold;
  }

  // Check if 4 points form a rectangle
  static bool _isRectangle(List<vector.Vector3> points) {
    if (points.length != 4) return false;

    // Calculate all distances
    final distances = <double>[];
    for (int i = 0; i < 4; i++) {
      for (int j = i + 1; j < 4; j++) {
        distances.add((points[i] - points[j]).length);
      }
    }

    // Sort distances
    distances.sort();

    // In a rectangle: 2 short sides, 2 long sides, 2 diagonals
    // Check if we have 2 pairs of equal sides and 2 equal diagonals
    const tolerance = 0.05; // 5cm tolerance

    final side1 = distances[0];
    final side2 = distances[1];
    final side3 = distances[2];
    final side4 = distances[3];
    final diag1 = distances[4];
    final diag2 = distances[5];

    // Check pairs of sides
    final hasTwoEqualShortSides = (side1 - side2).abs() < tolerance;
    final hasTwoEqualLongSides = (side3 - side4).abs() < tolerance;
    final hasEqualDiagonals = (diag1 - diag2).abs() < tolerance;

    return hasTwoEqualShortSides && hasTwoEqualLongSides && hasEqualDiagonals;
  }

  // Sort rectangle corners in clockwise order
  static List<vector.Vector3> _sortRectangleCorners(List<vector.Vector3> corners) {
    if (corners.length != 4) return corners;

    // Find center
    final center = corners.fold(
          vector.Vector3.zero(),
          (sum, corner) => sum + corner,
        ) /
        4.0;

    // Sort by angle from center
    final sorted = List<vector.Vector3>.from(corners);
    sorted.sort((a, b) {
      final angleA = _angleFromCenter(a - center);
      final angleB = _angleFromCenter(b - center);
      return angleA.compareTo(angleB);
    });

    return sorted;
  }

  // Calculate angle from center for sorting
  static double _angleFromCenter(vector.Vector3 v) {
    return math.atan2(v.z, v.x);
  }

  // Determine if rectangle is actually a square
  static ObjectType _determineObjectType(List<vector.Vector3> corners) {
    if (corners.length != 4) return ObjectType.custom;

    final width = (corners[1] - corners[0]).length;
    final height = (corners[2] - corners[1]).length;

    // Check if it's a square (within 5% tolerance)
    if ((width - height).abs() / width < 0.05) {
      return ObjectType.square;
    }

    return ObjectType.rectangle;
  }

  // Detect planes from continuous scanning
  static List<vector.Vector3>? detectPlaneCorners(ARHitTestResult hit) {
    // Extract plane extent from hit result if available
    final transform = hit.worldTransform;
    final position = transform.getTranslation();

    // For now, create a default 1m x 1m plane centered at hit point
    // In a real implementation, this would use plane extent data from ARCore/ARKit
    final halfSize = 0.5;

    return [
      position + vector.Vector3(-halfSize, 0, -halfSize),
      position + vector.Vector3(halfSize, 0, -halfSize),
      position + vector.Vector3(halfSize, 0, halfSize),
      position + vector.Vector3(-halfSize, 0, halfSize),
    ];
  }
}
