//
//  ARMeasureView.swift
//  ar-demo-native
//
//  Created by Abdelrahman Sobhy on 22/07/2025.
//

import SwiftUI
import ARKit
import SceneKit

// Add public to make it accessible
@available(iOS 15.0, *)
public struct ARMeasureView: View {
    @ObservedObject var arViewModel: ARMeasureViewModel
    
    public init(viewModel: ARMeasureViewModel) {
        self.arViewModel = viewModel
    }
    
    public var body: some View {
        ZStack {
            // AR Scene View
            ARViewRepresentable(viewModel: arViewModel)
                .onTapGesture {
                    arViewModel.addMeasurementPoint()
                }
            
            // Top Controls
            VStack {
                HStack {
                    Button(action: {
                        arViewModel.undoLastPoint()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(arViewModel.measurementPoints.isEmpty)
                    
                    Spacer()
                    
                    // AR Session Status
                    if arViewModel.sessionStatus != .normal {
                        Text(arViewModel.sessionStatusText)
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        arViewModel.clearMeasurements()
                    }) {
                        Text("Clear")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 80, height: 44)
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(arViewModel.measurementPoints.isEmpty && arViewModel.detectedObjects.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                // Measurement Info Display - Moved to top
                if !arViewModel.measurements.isEmpty || !arViewModel.detectedObjects.isEmpty {
                    VStack(spacing: 8) {
                        if arViewModel.totalDistance > 0 {
                            Text("Total Distance: \(arViewModel.formattedTotalDistance)")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        if arViewModel.measurementPoints.count >= 3 && !arViewModel.isPolygonClosed {
                            Text("Long press to close polygon")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // Bottom Controls and Info section removed - measurements now at top
            }
            
            // Center Crosshair with Depth Detection - iOS Measure App Style
            ZStack {
                // Main crosshair circle with depth indicator
                ZStack {
                    // Outer detection circle (shows when surface detected)
                    Circle()
                        .stroke(Color.white.opacity(arViewModel.surfaceDetected ? 0.8 : 0.3), lineWidth: 2)
                        .frame(width: 60, height: 60)
                        .scaleEffect(arViewModel.surfaceDetected ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.3), value: arViewModel.surfaceDetected)
                    
                    // Inner crosshair circle
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 20, height: 20)
                    
                    // Center dot
                    Circle()
                        .fill(arViewModel.surfaceDetected ? Color.yellow : Color.white)
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: arViewModel.surfaceDetected)
                    
                    // Crosshair lines
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 15)
                        Spacer()
                            .frame(height: 20)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 15)
                    }
                    
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 15, height: 2)
                        Spacer()
                            .frame(width: 20)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 15, height: 2)
                    }
                }
                
                // Depth indicator text below crosshair
                VStack {
                    Spacer()
                        .frame(height: 100)
                    if arViewModel.surfaceDetected {
                        VStack(spacing: 4) {
                            Text("Surface Detected")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                            
                            // Distance to surface indicator
                            Text("\(String(format: "%.2f", arViewModel.currentDepth))m")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(6)
                        }
                        .transition(.opacity)
                    } else {
                        Text("Move to detect surface")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))
                            .cornerRadius(8)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: arViewModel.surfaceDetected)
                
                // Text below - positioned independently 
                if arViewModel.measurementPoints.isEmpty {
                    VStack {
                        Spacer()
                            .frame(height: 220) // Space for crosshair and depth indicator
                        Text("Tap to place points at center")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                }
            }
            
            // Bottom Controls
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    // Cancel Button
                    Button(action: {
                        arViewModel.cancelMeasurement()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(12)
                    }
                    
                    // Submit Button
                    Button(action: {
                        arViewModel.submitMeasurements()
                    }) {
                        Text("Submit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(12)
                    }
                    .disabled(arViewModel.measurementPoints.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50) // Increased padding for better clearance
            }
        }
    }
}

@available(iOS 15.0, *)
struct ARViewRepresentable: UIViewRepresentable {
    let viewModel: ARMeasureViewModel
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        viewModel.setupARView(arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // Updates handled by view model
    }
}

@available(iOS 15.0, *)
#Preview {
    ARMeasureView(viewModel: ARMeasureViewModel())
} 
