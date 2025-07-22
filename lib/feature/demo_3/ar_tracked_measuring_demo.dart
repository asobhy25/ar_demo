import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import '../../Draft/models/measurement_models.dart';
import '../../Draft/services/measurement_manager.dart';
import '../../Draft/services/ar_renderer.dart';
import '../../Draft/widgets/ar_measurement_overlay.dart';

class ARTrackedMeasuringDemo extends StatefulWidget {
  const ARTrackedMeasuringDemo({Key? key}) : super(key: key);

  @override
  State<ARTrackedMeasuringDemo> createState() => _ARTrackedMeasuringDemoState();
}

class _ARTrackedMeasuringDemoState extends State<ARTrackedMeasuringDemo> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  late MeasurementManager measurementManager;
  ARRenderer? arRenderer;

  bool waitingForTap = false;

  @override
  void initState() {
    super.initState();
    measurementManager = MeasurementManager();
  }

  @override
  void dispose() {
    measurementManager.dispose();
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'AR Tracked Measuring Demo',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          // AR View
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // AR-tracked overlays that follow real-world positions
          StreamBuilder(
            stream: Stream.periodic(const Duration(milliseconds: 100)), // 10fps updates for debugging
            builder: (context, snapshot) {
              return Stack(
                children: [
                  // Debug info showing anchor count
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Anchors: ${arRenderer?.getAnchorCount() ?? 0}\nPoints: ${measurementManager.points.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),

                  // Draw AR-tracked lines
                  ...measurementManager.lines.map((line) {
                    return ARTrackedLineOverlay(
                      line: line,
                      arRenderer: arRenderer!,
                      arSessionManager: arSessionManager,
                    );
                  }),

                  // Draw AR-tracked points (ellipses)
                  ...measurementManager.points.asMap().entries.map((entry) {
                    final index = entry.key;
                    final point = entry.value;

                    return ARTrackedPointOverlay(
                      point: point,
                      arRenderer: arRenderer!,
                      arSessionManager: arSessionManager,
                      isActive: measurementManager.points.length > 0 && measurementManager.points.last == point,
                      pointNumber: index,
                    );
                  }),
                ],
              );
            },
          ),

          // Instructions
          if (waitingForTap)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap on a surface to place an AR point!',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

          // Status display
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Points: ${measurementManager.points.length} | Lines: ${measurementManager.lines.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Add point button
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        waitingForTap = true;
                      });
                    },
                    backgroundColor: Colors.orange,
                    heroTag: "add",
                    child: const Icon(Icons.add, color: Colors.white),
                  ),

                  // Clear all button
                  FloatingActionButton(
                    onPressed: measurementManager.points.isNotEmpty
                        ? () {
                            measurementManager.clearAll();
                            arRenderer?.clearAll();
                            setState(() {});
                          }
                        : null,
                    backgroundColor: Colors.red,
                    heroTag: "clear",
                    child: const Icon(Icons.clear, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = anchorManager;

    arRenderer = ARRenderer(
      arObjectManager: arObjectManager,
      arAnchorManager: anchorManager,
    );

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
    );

    // CRITICAL: Initialize the AR object manager
    arObjectManager.onInitialize();

    // Set up tap handler
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  void onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty || !waitingForTap) {
      print('❌ No AR hits detected or not waiting for tap');
      return;
    }

    final hit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane || h.type == ARHitTestResultType.point,
      orElse: () => hits.first,
    );

    final position = hit.worldTransform.getTranslation();
    print('🎯 AR Hit at: (${position.x.toStringAsFixed(3)}, ${position.y.toStringAsFixed(3)}, ${position.z.toStringAsFixed(3)})');

    // Add measurement point
    HapticFeedback.lightImpact();
    measurementManager.addPoint(position);

    print('📍 Point ${measurementManager.points.length} placed');

    // Create AR anchor for the point
    if (arRenderer != null) {
      await arRenderer!.drawPoint(measurementManager.points.last);

      if (measurementManager.lines.isNotEmpty) {
        await arRenderer!.drawLine(measurementManager.lines.last);
        print('📏 Line created with distance: ${measurementManager.lines.last.distance.toStringAsFixed(3)}m');
      }
    }

    setState(() {
      waitingForTap = false;
    });

    print('✅ AR-tracked measurement point added successfully');
  }
}
