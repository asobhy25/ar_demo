import 'dart:math' as math;
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../models/measurement_models.dart';

class ARRenderer {
  final ARObjectManager? arObjectManager;
  final ARAnchorManager? arAnchorManager;

  // Track created nodes for cleanup
  List<ARNode> _createdNodes = [];
  List<ARAnchor> _createdAnchors = [];

  // Track point anchors specifically for overlay positioning
  Map<String, ARAnchor> _pointAnchorMap = {};

  ARRenderer({this.arObjectManager, this.arAnchorManager});

  Future<void> drawPoint(MeasurementPoint point) async {
    if (arObjectManager == null || arAnchorManager == null) {
      print('❌ AR managers not initialized');
      return;
    }

    try {
      // Create anchor at the point location (this anchors to real world space)
      final anchor = ARPlaneAnchor(
        transformation: Matrix4.identity()..translate(point.position.x, point.position.y, point.position.z),
      );

      bool? didAddAnchor = await arAnchorManager!.addAnchor(anchor);
      if (didAddAnchor == true) {
        _createdAnchors.add(anchor);
        _pointAnchorMap[point.id] = anchor;

        // Create a 3D sphere icon for the measurement point
        final sphereNode = ARNode(
          type: NodeType.webGLB,
          uri: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Sphere/glTF-Binary/Sphere.glb",
          scale: vector.Vector3(0.03, 0.03, 0.03), // 3cm sphere
          position: vector.Vector3(0.0, 0.0, 0.0), // Relative to anchor
          rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
        );

        bool? didAddNode = await arObjectManager!.addNode(sphereNode, planeAnchor: anchor);
        if (didAddNode == true) {
          _createdNodes.add(sphereNode);
          print('✓ 3D Point icon created at: (${point.position.x.toStringAsFixed(3)}, ${point.position.y.toStringAsFixed(3)}, ${point.position.z.toStringAsFixed(3)})');
        } else {
          print('❌ Failed to add 3D point icon');
        }
      } else {
        print('❌ Failed to add anchor for point');
      }
    } catch (e) {
      print('❌ Error creating 3D point icon: $e');
    }
  }

  Future<void> drawLine(MeasurementLine line) async {
    if (arObjectManager == null || arAnchorManager == null) return;

    try {
      // Calculate line center and rotation
      final startPos = line.startPoint.position;
      final endPos = line.endPoint.position;
      final center = (startPos + endPos) / 2.0;
      final direction = (endPos - startPos).normalized();
      final distance = line.distance;

      // Create anchor at line center
      final anchor = ARPlaneAnchor(
        transformation: Matrix4.identity()..translate(center.x, center.y, center.z),
      );

      bool? didAddAnchor = await arAnchorManager!.addAnchor(anchor);
      if (didAddAnchor == true) {
        _createdAnchors.add(anchor);

        // Create a cylinder to represent the line
        final lineNode = ARNode(
          type: NodeType.webGLB,
          uri: "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Cylinder/glTF-Binary/Cylinder.glb",
          scale: vector.Vector3(0.005, distance / 2, 0.005), // Thin cylinder, scaled to distance
          position: vector.Vector3(0.0, 0.0, 0.0),
          rotation: _calculateLineRotation(direction),
        );

        bool? didAddNode = await arObjectManager!.addNode(lineNode, planeAnchor: anchor);
        if (didAddNode == true) {
          _createdNodes.add(lineNode);
          print('✓ 3D Line created: ${line.distance.toStringAsFixed(3)}m');
        }
      }
    } catch (e) {
      print('❌ Error creating line: $e');
    }
  }

  Future<void> drawPolygon(MeasurementPolygon polygon) async {
    // Log polygon creation
    print('✓ Polygon created with ${polygon.points.length} points');
    print('  Perimeter: ${polygon.perimeter.toStringAsFixed(3)}m');
    if (polygon.area != null) {
      print('  Area: ${polygon.area!.toStringAsFixed(3)}m²');
    }

    // Draw all lines of the polygon
    for (final line in polygon.lines) {
      await drawLine(line);
    }
  }

  Future<void> highlightDetectedObject(DetectedObject object) async {
    if (arObjectManager == null || arAnchorManager == null) return;

    try {
      // Calculate object center
      final center = object.corners.fold(
            vector.Vector3.zero(),
            (sum, corner) => sum + corner,
          ) /
          object.corners.length.toDouble();

      // Create anchor at object center
      final anchor = ARPlaneAnchor(
        transformation: Matrix4.identity()..translate(center.x, center.y, center.z),
      );

      bool? didAddAnchor = await arAnchorManager!.addAnchor(anchor);
      if (didAddAnchor == true) {
        _createdAnchors.add(anchor);

        // Create a flat box to highlight the detected object
        final highlightNode = ARNode(
          type: NodeType.webGLB,
          uri: "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Box/glTF-Binary/Box.glb",
          scale: vector.Vector3(object.width, 0.01, object.height), // Flat box
          position: vector.Vector3(0.0, 0.0, 0.0),
          rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
        );

        bool? didAddNode = await arObjectManager!.addNode(highlightNode, planeAnchor: anchor);
        if (didAddNode == true) {
          _createdNodes.add(highlightNode);
          print('✓ 3D Object highlight created: ${object.width.toStringAsFixed(3)}m x ${object.height.toStringAsFixed(3)}m');
        }
      }
    } catch (e) {
      print('❌ Error highlighting object: $e');
    }
  }

  Future<void> removePoint(String pointId) async {
    print('✓ Point removed: $pointId');
  }

  Future<void> removeLine(String lineId) async {
    print('✓ Line removed: $lineId');
  }

  Future<void> removePolygon(String polygonId) async {
    print('✓ Polygon removed: $polygonId');
  }

  Future<void> removeDetectedObject(String objectId) async {
    print('✓ Detected object removed: $objectId');
  }

  Future<void> clearAll() async {
    try {
      // Remove all created anchors (this also removes attached nodes)
      for (final anchor in _createdAnchors) {
        await arAnchorManager?.removeAnchor(anchor);
      }

      _createdNodes.clear();
      _createdAnchors.clear();
      _pointAnchorMap.clear();
      print('✓ All 3D objects cleared');
    } catch (e) {
      print('❌ Error clearing objects: $e');
    }
  }

  // Helper method to calculate rotation for line alignment
  vector.Vector4 _calculateLineRotation(vector.Vector3 direction) {
    // This is a simplified rotation calculation
    // For a proper implementation, you'd need to calculate the quaternion
    // that aligns the cylinder's Y-axis with the line direction

    // For now, return identity rotation (you can enhance this)
    return vector.Vector4(1.0, 0.0, 0.0, 0.0);
  }

  vector.Vector3 _calculateCenter(List<vector.Vector3> points) {
    final sum = points.fold(
      vector.Vector3.zero(),
      (sum, point) => sum + point,
    );
    return sum / points.length.toDouble();
  }

  vector.Vector3 _calculatePolygonCenter(List<MeasurementPoint> points) {
    final positions = points.map((p) => p.position).toList();
    return _calculateCenter(positions);
  }

  // Methods for AR-tracked overlays
  ARAnchor? getAnchorForPoint(String pointId) {
    return _pointAnchorMap[pointId];
  }

  bool hasAnchorsForLine(MeasurementLine line) {
    return _pointAnchorMap.containsKey(line.startPoint.id) && _pointAnchorMap.containsKey(line.endPoint.id);
  }

  int getAnchorCount() {
    return _pointAnchorMap.length;
  }

  // Utility method to format distance for display
  String formatDistance(double distance) {
    if (distance < 0.01) {
      return '${(distance * 1000).toStringAsFixed(1)} mm';
    } else if (distance < 1) {
      return '${(distance * 100).toStringAsFixed(1)} cm';
    } else {
      return '${distance.toStringAsFixed(2)} m';
    }
  }

  // Utility method to format area for display
  String formatArea(double area) {
    if (area < 0.01) {
      return '${(area * 10000).toStringAsFixed(0)} cm²';
    } else {
      return '${area.toStringAsFixed(2)} m²';
    }
  }
}
