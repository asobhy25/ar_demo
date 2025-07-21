import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR Distance Measuring',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ARDistanceMeasuringPage(),
    );
  }
}

class ARDistanceMeasuringPage extends StatefulWidget {
  const ARDistanceMeasuringPage({super.key});

  @override
  State<ARDistanceMeasuringPage> createState() => _ARDistanceMeasuringPageState();
}

class _ARDistanceMeasuringPageState extends State<ARDistanceMeasuringPage> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<vector.Vector3> measurementPoints = [];
  List<String> measurements = [];
  bool isPlacingPoints = false;

  @override
  void dispose() {
    super.dispose();
    arSessionManager?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Distance Measuring'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          // Controls UI
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Instructions:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Point your device to detect planes\n'
                      '2. Tap "Start Measuring" button\n'
                      '3. Tap on surfaces to place points\n'
                      '4. Distance will be calculated automatically',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Measurement display
          if (measurements.isNotEmpty)
            Positioned(
              top: 180,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Measurements:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...measurements.map((measurement) => Text(
                            measurement,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.green.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                          )),
                    ],
                  ),
                ),
              ),
            ),
          // Bottom controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleMeasuring,
                  icon: Icon(isPlacingPoints ? Icons.stop : Icons.play_arrow),
                  label: Text(isPlacingPoints ? 'Stop Measuring' : 'Start Measuring'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPlacingPoints ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _clearMeasurements,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          customPlaneTexturePath: null,
          showWorldOrigin: false,
          handlePans: true,
          handleRotation: true,
        );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = _onPlaneOrPointTapped;
  }

  void _onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) {
    if (!isPlacingPoints) return;

    // Find a plane hit result
    ARHitTestResult? singleHitTestResult;
    try {
      singleHitTestResult = hitTestResults.firstWhere(
        (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
      );
    } catch (e) {
      // No plane found, try any hit result
      if (hitTestResults.isNotEmpty) {
        singleHitTestResult = hitTestResults.first;
      }
    }

    if (singleHitTestResult != null && singleHitTestResult.worldTransform != null) {
      var newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform!);
      bool didAddAnchor = arAnchorManager!.addAnchor(newAnchor) != null;

      if (didAddAnchor) {
        // Extract position from transformation matrix
        var transform = singleHitTestResult.worldTransform!;
        var position = vector.Vector3(
          transform[12], // X
          transform[13], // Y
          transform[14], // Z
        );

        _addMeasurementPoint(position, newAnchor);
      }
    }
  }

  void _addMeasurementPoint(vector.Vector3 position, ARPlaneAnchor anchor) {
    setState(() {
      measurementPoints.add(position);
    });

    // Add visual marker (simple sphere)
    _addSphere(position, anchor);

    // Calculate distance if we have at least 2 points
    if (measurementPoints.length >= 2) {
      var lastTwoPoints = measurementPoints.sublist(measurementPoints.length - 2);
      double distance = _calculateDistance(lastTwoPoints[0], lastTwoPoints[1]);

      setState(() {
        measurements.add('Point ${measurementPoints.length - 1} to ${measurementPoints.length}: '
            '${distance.toStringAsFixed(2)} meters');
      });
    }
  }

  void _addSphere(vector.Vector3 position, ARPlaneAnchor anchor) {
    // Create a simple sphere node
    var sphere = ARNode(
      type: NodeType.webGLB,
      uri: "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Sphere/glTF-Binary/Sphere.glb",
      scale: vector.Vector3(0.02, 0.02, 0.02),
      position: position,
    );
    arObjectManager!.addNode(sphere, planeAnchor: anchor);
  }

  double _calculateDistance(vector.Vector3 point1, vector.Vector3 point2) {
    return math.sqrt(math.pow(point2.x - point1.x, 2) + math.pow(point2.y - point1.y, 2) + math.pow(point2.z - point1.z, 2));
  }

  void _toggleMeasuring() {
    setState(() {
      isPlacingPoints = !isPlacingPoints;
    });

    if (isPlacingPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap on detected planes to place measurement points'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearMeasurements() {
    setState(() {
      measurementPoints.clear();
      measurements.clear();
      isPlacingPoints = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All measurements cleared'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
