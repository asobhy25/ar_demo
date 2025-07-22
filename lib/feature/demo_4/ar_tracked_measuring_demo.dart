import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
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
          showPlanes: true,
          customPlaneTexturePath: 'assets/textures/plane_grid.png',
          showWorldOrigin: true,
          handlePans: true,
          handleRotation: true,
        );

    this.arObjectManager!.onInitialize();

    this.arSessionManager?.onPlaneOrPointTap = onPlaneOrPointTapped;
    this.arObjectManager?.onPanStart = onPanStarted;
    this.arObjectManager?.onPanChange = onPanChanged;
    this.arObjectManager?.onPanEnd = onPanEnded;
    this.arObjectManager?.onRotationStart = onRotationStarted;
    this.arObjectManager?.onRotationChange = onRotationChanged;
    this.arObjectManager?.onRotationEnd = onRotationEnded;
  }

  onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstOrNull;
    if (singleHitTestResult != null) {
      var newAnchor = ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
      bool? didAddAnchor = await this.arAnchorManager!.addAnchor(newAnchor);
      if (didAddAnchor!) {
        this.anchors.add(newAnchor);
        // Add note to anchor
        var newNode = ARNode(
          type: NodeType.webGLB,
          uri: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/AnimatedMorphSphere/glTF-Binary/AnimatedMorphSphere.glb",
          scale: vector.Vector3(0.2, 0.2, 0.2),
          position: vector.Vector3(0.0, 0.0, 0.0),
          rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
        );
        bool? didAddNodeToAnchor = await this.arObjectManager!.addNode(newNode, planeAnchor: newAnchor);
        if (didAddNodeToAnchor!) {
          this.nodes.add(newNode);
        } else {
          this.arSessionManager!.onError("Adding Node to Anchor failed");
        }
      } else {
        this.arSessionManager!.onError("Adding Anchor failed");
      }
    }
  }

  onPanStarted(String nodeName) {
    print('🔄 Pan started: ${nodeName}');
  }

  onPanChanged(String nodeName) {
    print('🔄 Pan changed: ${nodeName}');
  }

  onPanEnded(String nodeName, Matrix4 newTransform) {
    print("Ended panning node " + nodeName);
    // final pannedNode = this.nodes.firstWhere((element) => element.name == nodeName);

    /*
    * Uncomment the following command if you want to keep the transformations of the Flutter representations of the nodes up to date
    * (e.g. if you intend to share the nodes through the cloud)
    */
    // pannedNode.transform = newTransform;
  }

  onRotationStarted(String nodeName) {
    print('🔄 Rotation started: ${nodeName}');
  }

  onRotationChanged(String nodeName) {
    print('🔄 Rotation changed: ${nodeName}');
  }

  onRotationEnded(String nodeName, Matrix4 newTransform) {
    print("Ended rotating node " + nodeName);
    // final rotatedNode = this.nodes.firstWhere((element) => element.name == nodeName);

    /*
    * Uncomment the following command if you want to keep the transformations of the Flutter representations of the nodes up to date
    * (e.g. if you intend to share the nodes through the cloud)
    */
    // rotatedNode.transform = newTransform;
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
