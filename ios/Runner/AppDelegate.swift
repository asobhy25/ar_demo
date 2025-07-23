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
            name: "com.example.ar_measure/ar",
            binaryMessenger: controller.binaryMessenger
        )
        
        arChannel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "startARMeasurement" {
                if #available(iOS 15.0, *) {
                    self?.startARMeasurement(controller: controller)
                    result(nil)
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
    private func startARMeasurement(controller: FlutterViewController) {
        // Check if SwiftUI is available
        if #available(iOS 15.0, *) {
            // Initialize your existing AR components - ARMeasureView creates its own viewModel
            let arView = UIHostingController(rootView: ARMeasureView())
            
            // Present your custom AR view
            arView.modalPresentationStyle = UIModalPresentationStyle.fullScreen
            controller.present(arView, animated: true)
        } else {
            // Fallback for older iOS versions
            let alert = UIAlertController(
                title: "AR Not Available", 
                message: "AR features require iOS 15.0 or later", 
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            controller.present(alert, animated: true)
        }
    }
}
