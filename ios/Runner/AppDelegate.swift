import Flutter
import UIKit
import ARKit  // Add ARKit import
import SwiftUI  // Add SwiftUI import for UIHostingController

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let arChannel = FlutterMethodChannel(
            name: AppChannelEnum.arMeasure.rawValue,
            binaryMessenger: controller.binaryMessenger
        )
        
        arChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == MethodChannelEnum.startARMeasurement.rawValue {
                if #available(iOS 15.0, *) {
                    self?.startARMeasurement(controller: controller, result: result)
                } else {
                    result(FlutterError(
                        code: "UNAVAILABLE",
                        message: "AR features require iOS 15.0 or later",
                        details: nil
                    ))
                }
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    @available(iOS 15.0, *)
    private func startARMeasurement(controller: FlutterViewController, result: @escaping FlutterResult) {
        let arViewModel = ARMeasureViewModel()
        let arView = UIHostingController(rootView: ARMeasureView(viewModel: arViewModel))
        
        // Set up dismiss callback
        arViewModel.onDismiss = { [weak arView] in
            DispatchQueue.main.async {
                arView?.dismiss(animated: true)
                result(nil)
            }
        }
        
        // Set up submit callback
        arViewModel.onSubmit = { [weak arView] measurementResult in
            DispatchQueue.main.async {
                // Convert to simple types for Flutter codec
                let measurementLinesData = measurementResult.measurementLines.map { line in
                    return [
                        "id": line.id.uuidString,
                        "distance": line.distance,
                        "startPoint": [
                            "x": line.startPoint.x,
                            "y": line.startPoint.y,
                            "z": line.startPoint.z
                        ],
                        "endPoint": [
                            "x": line.endPoint.x,
                            "y": line.endPoint.y,
                            "z": line.endPoint.z
                        ]
                    ]
                }
                
                let measurementData: [String: Any] = [
                    "totalDistance": measurementResult.totalDistance,
                    "measurementLines": measurementLinesData
                ]
                
                arView?.dismiss(animated: true)
                result(measurementData)
            }
        }
        
        // Present your custom AR view
        arView.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        controller.present(arView, animated: true)
    }
}
