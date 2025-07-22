import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/measurement_models.dart';

class MeasurementManager extends ChangeNotifier {
  List<MeasurementPoint> _points = [];
  List<MeasurementLine> _lines = [];
  List<MeasurementPolygon> _polygons = [];
  List<DetectedObject> _detectedObjects = [];
  MeasurementMode _currentMode = MeasurementMode.distance;

  List<MeasurementPoint> get points => _points;
  List<MeasurementLine> get lines => _lines;
  List<MeasurementPolygon> get polygons => _polygons;
  List<DetectedObject> get detectedObjects => _detectedObjects;
  MeasurementMode get currentMode => _currentMode;

  double? get totalDistance {
    if (_lines.isEmpty) return null;
    return _lines.fold<double>(0.0, (sum, line) => sum + line.distance);
  }

  double? get totalArea {
    double area = 0.0;
    for (var polygon in _polygons) {
      if (polygon.area != null) {
        area += polygon.area!;
      }
    }
    for (var obj in _detectedObjects) {
      area += obj.area;
    }
    return area > 0 ? area : null;
  }

  void setMode(MeasurementMode mode) {
    _currentMode = mode;
    notifyListeners();
  }

  void addPoint(vector.Vector3 position) {
    final point = MeasurementPoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      position: position,
      timestamp: DateTime.now(),
    );

    _points.add(point);

    // Create line if we have at least 2 points
    if (_points.length >= 2) {
      final line = MeasurementLine(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startPoint: _points[_points.length - 2],
        endPoint: point,
      );
      _lines.add(line);
    }

    // Check if we can form a polygon
    _checkForPolygon();

    notifyListeners();
  }

  void _checkForPolygon() {
    if (_points.length >= 3) {
      // Check if the last point is close to the first point
      final firstPoint = _points.first.position;
      final lastPoint = _points.last.position;
      final distance = (lastPoint - firstPoint).length;

      // If points are close enough, consider it a closed polygon
      if (distance < 0.1) {
        // 10cm threshold
        final polygonPoints = List<MeasurementPoint>.from(_points);
        final polygonLines = List<MeasurementLine>.from(_lines);

        // Add closing line
        final closingLine = MeasurementLine(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          startPoint: _points.last,
          endPoint: _points.first,
        );
        polygonLines.add(closingLine);

        final polygon = MeasurementPolygon(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          points: polygonPoints,
          lines: polygonLines,
          isClosed: true,
        );

        _polygons.add(polygon);
        clearCurrentMeasurement();
      }
    }
  }

  void addDetectedObject(List<vector.Vector3> corners) {
    final objType = _determineObjectType(corners);
    final detectedObject = DetectedObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      corners: corners,
      type: objType,
    );

    _detectedObjects.add(detectedObject);
    notifyListeners();
  }

  ObjectType _determineObjectType(List<vector.Vector3> corners) {
    if (corners.length != 4) return ObjectType.custom;

    final width = (corners[1] - corners[0]).length;
    final height = (corners[2] - corners[1]).length;

    // Check if it's a square (within 5% tolerance)
    if ((width - height).abs() / width < 0.05) {
      return ObjectType.square;
    }

    return ObjectType.rectangle;
  }

  void removeLastPoint() {
    if (_points.isNotEmpty) {
      _points.removeLast();
      if (_lines.isNotEmpty) {
        _lines.removeLast();
      }
      notifyListeners();
    }
  }

  void clearCurrentMeasurement() {
    _points.clear();
    _lines.clear();
    notifyListeners();
  }

  void clearAll() {
    _points.clear();
    _lines.clear();
    _polygons.clear();
    _detectedObjects.clear();
    notifyListeners();
  }

  void removeDetectedObject(String id) {
    _detectedObjects.removeWhere((obj) => obj.id == id);
    notifyListeners();
  }

  void removePolygon(String id) {
    _polygons.removeWhere((polygon) => polygon.id == id);
    notifyListeners();
  }

  String formatDistance(double distance) {
    if (distance < 0.01) {
      return '${(distance * 1000).toStringAsFixed(1)} mm';
    } else if (distance < 1) {
      return '${(distance * 100).toStringAsFixed(1)} cm';
    } else {
      return '${distance.toStringAsFixed(2)} m';
    }
  }

  String formatArea(double area) {
    if (area < 0.01) {
      return '${(area * 10000).toStringAsFixed(0)} cm²';
    } else if (area < 1) {
      return '${(area * 10000).toStringAsFixed(0)} cm²';
    } else {
      return '${area.toStringAsFixed(2)} m²';
    }
  }
}
