import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class ARTrackedMeasuringDemo extends StatefulWidget {
  const ARTrackedMeasuringDemo({Key? key}) : super(key: key);

  @override
  State<ARTrackedMeasuringDemo> createState() => _ARTrackedMeasuringDemoState();
}

class _ARTrackedMeasuringDemoState extends State<ARTrackedMeasuringDemo> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
          Align(
            alignment: FractionalOffset.bottomCenter,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(onPressed: onRemoveEverything, child: const Text("Remove Everything")),
            ]),
          )
        ],
      ),
    );
  }

  Future<void> onRemoveEverything() async {
    nodes.forEach((node) {
      this.arObjectManager?.removeNode(node);
    });
    anchors.forEach((anchor) {
      this.arAnchorManager!.removeAnchor(anchor);
    });
    anchors = [];
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

    this.arSessionManager?.onInitialize(
          showFeaturePoints: false,
          showPlanes: false,
          customPlaneTexturePath: 'assets/textures/plane_grid.png',
          showWorldOrigin: false,
        );

    this.arObjectManager!.onInitialize();
    this.arSessionManager?.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstOrNull;
    if (singleHitTestResult != null) {
      var newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
      bool? didAddAnchor = await this.arAnchorManager!.addAnchor(newAnchor);
      if (didAddAnchor!) {
        this.anchors.add(newAnchor);
        // Add note to anchor

        final position = singleHitTestResult.worldTransform.getTranslation();
        final rotation = singleHitTestResult.worldTransform.getRow(0);
        final scale = singleHitTestResult.worldTransform.matrixScale;

        HapticFeedback.lightImpact();

        var newNode = ARNode(
          type: NodeType.webGLB,
          uri: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/AnimatedMorphSphere/glTF-Binary/AnimatedMorphSphere.glb",
          scale: scale,
          position: position,
          rotation: rotation,
        );
        bool? didAddNodeToAnchor = await this.arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
        if (didAddNodeToAnchor!) {
          this.nodes.add(newNode);
          print('✅ AR-tracked measurement point added successfully');
          print('✅ AR-tracked measurement point ${newNode.position.x}, ${newNode.position.y}, ${newNode.position.z}');
        } else {
          this.arSessionManager!.onError("Adding Node to Anchor failed");
        }
      } else {
        this.arSessionManager!.onError("Adding Anchor failed");
      }
    }
  }

  // void onPlaneOrPointTapped(List<ARHitTestResult> hits) async {
  //   if (hits.isEmpty) {
  //     return;
  //   }

  //   final hit = hits.firstWhere(
  //     (h) => h.type == ARHitTestResultType.plane || h.type == ARHitTestResultType.point,
  //     orElse: () => hits.first,
  //   );

  //   final position = hit.worldTransform.getTranslation();
  //   print('🎯 AR Hit at: (${position.x.toStringAsFixed(3)}, ${position.y.toStringAsFixed(3)}, ${position.z.toStringAsFixed(3)})');

  //   // Add measurement point
  //   HapticFeedback.lightImpact();
  //   // add point to anchor manager
  //   arAnchorManager?.addAnchor(ARPlaneAnchor(
  //     transformation: Matrix4.identity()..translate(position.x, position.y, position.z),
  //   ));

  //   print('✅ AR-tracked measurement point added successfully');
  // }
}
