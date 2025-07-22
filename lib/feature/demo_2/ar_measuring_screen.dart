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
import '../../Draft/models/measurement_models.dart';
import '../../Draft/services/measurement_manager.dart';
import '../../Draft/services/ar_renderer.dart';
import '../../Draft/services/object_detection_service.dart';
import '../../Draft/widgets/measurement_display.dart';
import '../../Draft/widgets/ar_measurement_overlay.dart';

class ARMeasureScreen extends StatefulWidget {
  @override
  State<ARMeasureScreen> createState() => _ARMeasureScreenState();
}

class _ARMeasureScreenState extends State<ARMeasureScreen> with TickerProviderStateMixin {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  late MeasurementManager measurementManager;
  ARRenderer? arRenderer;

  bool isScanning = false;
  bool waitingForTap = false;
  List<ARHitTestResult> recentHits = [];

  // UI Animation controllers
  late AnimationController _fabAnimationController;
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();
    measurementManager = MeasurementManager();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scanAnimationController.dispose();
    measurementManager.dispose();
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // AR View
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),

          // Measurement overlays - now AR-tracked!
          StreamBuilder(
            stream: Stream.periodic(const Duration(milliseconds: 60)), // 60fps updates
            builder: (context, snapshot) {
              return Stack(
                children: [
                  // Draw AR-tracked lines
                  ...measurementManager.lines.map((line) {
                    return ARTrackedLineOverlay(
                      line: line,
                      arRenderer: arRenderer!,
                      arSessionManager: arSessionManager,
                    );
                  }),

                  // Draw AR-tracked points
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

          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _buildControlButton(
                    icon: Icons.arrow_back_ios,
                    onPressed: measurementManager.points.isNotEmpty
                        ? () {
                            measurementManager.removeLastPoint();
                            if (arRenderer != null && measurementManager.points.isNotEmpty) {
                              arRenderer!.removePoint(measurementManager.points.length.toString());
                            }
                          }
                        : () => Navigator.pop(context),
                  ),

                  // Clear button
                  _buildControlButton(
                    text: 'Clear',
                    onPressed: measurementManager.lines.isNotEmpty || measurementManager.detectedObjects.isNotEmpty
                        ? () {
                            measurementManager.clearAll();
                            arRenderer?.clearAll();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),

          // Center crosshair
          if (measurementManager.currentMode == MeasurementMode.distance && waitingForTap)
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.yellow,
                    size: 24,
                  ),
                ),
              ),
            ),

          // Cumulative measurement display
          if (measurementManager.totalDistance != null)
            Positioned(
              bottom: 180,
              left: 0,
              right: 0,
              child: Center(
                child: CumulativeMeasurementDisplay(
                  totalDistance: measurementManager.totalDistance!,
                  totalArea: measurementManager.totalArea,
                  manager: measurementManager,
                ),
              ),
            ),

          // Current measurement status
          if (measurementManager.points.isNotEmpty)
            Positioned(
              bottom: 320,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Points: ${measurementManager.points.length} | Lines: ${measurementManager.lines.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom controls
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
              child: Column(
                children: [
                  // Add measurement button
                  FloatingActionButton(
                    onPressed: _onAddMeasurement,
                    backgroundColor: Colors.white,
                    child: AnimatedIcon(
                      icon: AnimatedIcons.add_event,
                      progress: _fabAnimationController,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mode selection buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeButton(
                        icon: Icons.straighten,
                        label: 'Measure',
                        mode: MeasurementMode.distance,
                        isSelected: measurementManager.currentMode == MeasurementMode.distance,
                      ),
                      _buildModeButton(
                        icon: Icons.crop_free,
                        label: 'Area',
                        mode: MeasurementMode.area,
                        isSelected: measurementManager.currentMode == MeasurementMode.area,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Scanning indicator
          if (isScanning)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnimationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ScanningPainter(
                      progress: _scanAnimationController.value,
                    ),
                  );
                },
              ),
            ),

          // Instructions
          if (waitingForTap)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.yellow.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.touch_app, color: Colors.black, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tap on a surface to place a point',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Success feedback
          if (measurementManager.points.isNotEmpty && !waitingForTap)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${measurementManager.points.length} point${measurementManager.points.length == 1 ? '' : 's'} placed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    IconData? icon,
    String? text,
    required VoidCallback? onPressed,
  }) {
    return Material(
      color: Colors.grey[900]?.withOpacity(0.8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: icon != null
              ? Icon(icon, color: Colors.white, size: 20)
              : Text(
                  text!,
                  style: TextStyle(
                    color: onPressed != null ? Colors.white : Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required MeasurementMode mode,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          measurementManager.setMode(mode);
          waitingForTap = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.grey[900]?.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
      customPlaneTexturePath: "assets/textures/plane_grid.png",
      showWorldOrigin: false,
      handleTaps: true,
    );

    // CRITICAL: Add this line!
    arObjectManager.onInitialize();

    // Set up tap handler
    arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  void onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
    if (hits.isEmpty) {
      print('❌ No AR hits detected');
      return;
    }

    final hit = hits.firstWhere(
      (h) => h.type == ARHitTestResultType.plane || h.type == ARHitTestResultType.point,
      orElse: () => hits.first,
    );

    final position = hit.worldTransform.getTranslation();
    print('🎯 AR Hit at: (${position.x.toStringAsFixed(3)}, ${position.y.toStringAsFixed(3)}, ${position.z.toStringAsFixed(3)})');

    if (waitingForTap && measurementManager.currentMode == MeasurementMode.distance) {
      // Add measurement point
      HapticFeedback.lightImpact();
      measurementManager.addPoint(position);

      print('📍 Point ${measurementManager.points.length} placed');

      // Draw point and line in AR
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

      print('✅ Measurement point added successfully');
    } else if (measurementManager.currentMode == MeasurementMode.area) {
      // Collect points for area detection
      recentHits.add(hit);
      if (recentHits.length > 20) {
        recentHits.removeAt(0);
      }

      print('🔍 Collected ${recentHits.length} hits for object detection');

      // Try to detect rectangles
      final detectedObject = ObjectDetectionService.detectRectangle(recentHits);
      if (detectedObject != null) {
        HapticFeedback.mediumImpact();
        measurementManager.addDetectedObject(detectedObject.corners);
        // await arRenderer?.highlightDetectedObject(detectedObject); // This line is removed as per the simplified ARRenderer
        recentHits.clear();
        print('🎉 Object detected and added!');
      }
    }
  }

  void _onAddMeasurement() {
    if (measurementManager.currentMode == MeasurementMode.distance) {
      setState(() {
        waitingForTap = true;
      });

      _fabAnimationController.forward().then((_) {
        _fabAnimationController.reverse();
      });
    } else if (measurementManager.currentMode == MeasurementMode.area) {
      // Toggle scanning mode
      setState(() {
        isScanning = !isScanning;
        if (!isScanning) {
          recentHits.clear();
        }
      });
    }
  }
}

// Custom painter for scanning animation
class ScanningPainter extends CustomPainter {
  final double progress;

  ScanningPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4 * progress;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(ScanningPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
