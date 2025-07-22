import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'dart:math' as math;

import '../bloc/measurement_bloc.dart';
import '../bloc/measurement_event.dart';
import '../bloc/measurement_state.dart';

class SimpleARMeasuringScreen extends StatelessWidget {
  const SimpleARMeasuringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MeasurementBloc(),
      child: const _SimpleARMeasuringView(),
    );
  }
}

class _SimpleARMeasuringView extends StatefulWidget {
  const _SimpleARMeasuringView();

  @override
  State<_SimpleARMeasuringView> createState() => _SimpleARMeasuringViewState();
}

class _SimpleARMeasuringViewState extends State<_SimpleARMeasuringView> {
  ARSessionManager? arSessionManager;
  ARAnchorManager? arAnchorManager;
  MeasurementBloc? measurementBloc;

  static const int maxNumMultiplePoints = 10;
  List<ARAnchor> placedAnchors = [];
  List<List<String>> distanceMatrix = [];

  @override
  void initState() {
    super.initState();
    initDistanceTable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    measurementBloc = context.read<MeasurementBloc>();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Simple AR Measuring',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: _onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          // Distance table overlay
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildDistanceTable(),
          ),
          // Clear button
          Positioned(
            top: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: clearAllAnchors,
              backgroundColor: Colors.red,
              child: const Icon(Icons.clear, color: Colors.white),
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
    this.arAnchorManager = arAnchorManager;

    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: null,
      showWorldOrigin: false,
      handleTaps: true,
    );

    arSessionManager.onPlaneOrPointTap = tapDistanceOfMultiplePoints;
  }

  Future<void> addAnchor(vector.Vector3 position) async {
    final anchor = ARPlaneAnchor(
      transformation: Matrix4.identity()..translate(position.x, position.y, position.z),
    );
    await arAnchorManager?.addAnchor(anchor);
    placedAnchors.add(anchor);
  }

  void tapDistanceOfMultiplePoints(List<ARHitTestResult> hitResults) async {
    if (hitResults.isNotEmpty) {
      final hitResult = hitResults.first;
      if (placedAnchors.length >= maxNumMultiplePoints) {
        clearAllAnchors();
      }

      final position = vector.Vector3(
        hitResult.worldTransform.getColumn(3).x,
        hitResult.worldTransform.getColumn(3).y,
        hitResult.worldTransform.getColumn(3).z,
      );

      // Create anchor first
      await addAnchor(position);

      // Update distance measurements
      measureMultipleDistances();

      // Then notify BLoC
      measurementBloc?.add(AddPointEvent(position));
    }
  }

  void initDistanceTable() {
    distanceMatrix = List.generate(
      maxNumMultiplePoints,
      (i) => List.generate(maxNumMultiplePoints, (j) => i == j ? "-" : "0.00"),
    );
  }

  void measureMultipleDistances() {
    if (placedAnchors.length > 1) {
      for (int i = 0; i < placedAnchors.length; i++) {
        for (int j = i + 1; j < placedAnchors.length; j++) {
          final pos1 = placedAnchors[i].transformation.getColumn(3);
          final pos2 = placedAnchors[j].transformation.getColumn(3);

          final distance = calculateDistance(
            vector.Vector3(pos1.x, pos1.y, pos1.z),
            vector.Vector3(pos2.x, pos2.y, pos2.z),
          );

          final distanceCM = (distance * 100).toStringAsFixed(2);

          if (i < distanceMatrix.length && j < distanceMatrix[i].length) {
            setState(() {
              distanceMatrix[i][j] = distanceCM;
              distanceMatrix[j][i] = distanceCM;
            });
          }
        }
      }
    }
  }

  double calculateDistance(vector.Vector3 objectPose0, vector.Vector3 objectPose1) {
    final dx = objectPose0.x - objectPose1.x;
    final dy = objectPose0.y - objectPose1.y;
    final dz = objectPose0.z - objectPose1.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }

  void clearAllAnchors() async {
    // Clear our tracking lists first
    placedAnchors.clear();

    initDistanceTable();
    setState(() {});
    measurementBloc?.add(ClearMeasurementEvent());
  }

  Widget _buildDistanceTable() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Distance Matrix (cm)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(color: Colors.white30),
            children: [
              // Header row
              TableRow(
                children: [
                  const TableCell(
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Text('', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  ...List.generate(
                    math.min(placedAnchors.length, 5),
                    (i) => TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          i.toString(),
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Data rows
              ...List.generate(
                math.min(placedAnchors.length, 5),
                (i) => TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          i.toString(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    ...List.generate(
                      math.min(placedAnchors.length, 5),
                      (j) => TableCell(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            i < distanceMatrix.length && j < distanceMatrix[i].length ? distanceMatrix[i][j] : "0.00",
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
