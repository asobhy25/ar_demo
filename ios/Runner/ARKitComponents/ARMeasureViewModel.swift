//
//  ARMeasureViewModel.swift
//  ar-demo-native
//
//  Created by Abdelrahman Sobhy on 22/07/2025.
//

import SwiftUI
import ARKit
import SceneKit

// MARK: - Measurement Result Data Structure
@available(iOS 15.0, *)
public struct MeasurementResult {
    public let totalDistance: Float
    public let measurementLines: [MeasurementLine]
    
    public init(totalDistance: Float, measurementLines: [MeasurementLine]) {
        self.totalDistance = totalDistance
        self.measurementLines = measurementLines
    }
}

enum ARSessionStatus {
    case normal
    case limitedTracking
    case notAvailable
    case initializing
}

// Add public to make it accessible
@available(iOS 15.0, *)
public class ARMeasureViewModel: NSObject, ObservableObject {
    @Published var measurements: [MeasurementLine] = []
    @Published var detectedObjects: [DetectedObject] = []
    @Published var isObjectDetectionEnabled: Bool = false
    @Published var totalDistance: Float = 0.0
    @Published var totalArea: Float = 0.0
    @Published var surfaceDetected: Bool = false
    @Published var currentDepth: Float = 0.0
    @Published var surfaceNormal: SCNVector3 = SCNVector3(0, 1, 0) // Surface angle/normal
    @Published var sessionStatusText: String = "Point the device at a surface to start measuring"
    @Published var sessionStatus: ARSessionStatus = .initializing
    @Published var isPolygonClosed: Bool = false
    
    private var arView: ARSCNView?
     var measurementPoints: [SCNVector3] = []
    private var pointNodes: [SCNNode] = []
    private var lineNodes: [SCNNode] = []
    private var objectNodes: [SCNNode] = []
    private var polygonNodes: [SCNNode] = []
    
    private func formatDistance(_ distance: Float) -> String {
        // Convert meters to inches (1 meter = 39.3701 inches)
        let inches = distance * 39.3701
        
        if inches < 12.0 {
            // Small distances in inches with 2 decimals
            return String(format: "%.2f\"", inches)
        } else if inches < 120.0 {
            // Medium distances in inches with 1 decimal
            return String(format: "%.1f\"", inches)
        } else {
            // Large distances in feet and inches
            let feet = Int(inches / 12)
            let remainingInches = inches.truncatingRemainder(dividingBy: 12)
            if remainingInches < 0.1 {
                return String(format: "%d'", feet)
            } else {
                return String(format: "%d' %.1f\"", feet, remainingInches)
            }
        }
    }
    
    var formattedTotalDistance: String {
        return formatDistance(totalDistance)
    }
    
    var formattedTotalArea: String {
        if totalArea < 1.0 {
            return String(format: "%.0f cm²", totalArea * 10000)
        } else {
            return String(format: "%.2f m²", totalArea)
        }
    }
    
    func setupARView(_ arView: ARSCNView) {
        self.arView = arView
        arView.delegate = self
        arView.session.delegate = self
        
        // Check AR availability
        guard ARWorldTrackingConfiguration.isSupported else {
            sessionStatus = .notAvailable
            return
        }
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        arView.session.run(configuration)
        
        // Configure scene
        arView.automaticallyUpdatesLighting = true
        arView.antialiasingMode = .multisampling2X
        
        // Add some lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500
        arView.scene.rootNode.addChildNode(ambientLight)
        
        // AREA CALCULATION TEST COMMENTED OUT FOR NOW
        // Run area calculation tests for verification
        // testAreaCalculation()
    }
    
    func addMeasurementPoint() {
        guard let arView = arView else { return }
        
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Enhanced hit test with priority for detected surfaces
        let hitTestResults = arView.hitTest(screenCenter, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .estimatedVerticalPlane])
        
        guard let hitTestResult = hitTestResults.first else {
            DispatchQueue.main.async { [weak self] in
                self?.sessionStatusText = "No surface detected - move device to find a surface"
            }
            return
        }
        
        // Create world position from hit test
        let transform = hitTestResult.worldTransform
        let worldPosition = SCNVector3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        
        // Add point to the scene
        // Calculate scaling distance based on distance from camera or existing measurements
        let scalingDistance = measurementPoints.isEmpty ? Float(hitTestResult.distance) : 
                             measurements.map { $0.distance }.max() ?? Float(hitTestResult.distance)
        let pointNode = createPointNode(at: worldPosition, surfaceType: hitTestResult.type, scalingDistance: scalingDistance)
        arView.scene.rootNode.addChildNode(pointNode)
        pointNodes.append(pointNode)
        measurementPoints.append(worldPosition)
        
        // Create line if we have more than one point
        if measurementPoints.count >= 2 {
            let startPoint = measurementPoints[measurementPoints.count - 2]
            let endPoint = measurementPoints[measurementPoints.count - 1]
            
            let distance = startPoint.distance(to: endPoint)
            let lineNode = createLineNode(from: startPoint, to: endPoint)
            arView.scene.rootNode.addChildNode(lineNode)
            lineNodes.append(lineNode)
            
            // Create measurement record
            let measurement = MeasurementLine(
                id: UUID(),
                startPoint: startPoint,
                endPoint: endPoint,
                distance: distance
            )
            measurements.append(measurement)
        }
        
        // Update measurements
        updateTotalMeasurements()
        
        // Update status with surface quality info
        DispatchQueue.main.async { [weak self] in
            let surfaceType = hitTestResult.type == .existingPlaneUsingExtent ? "detected surface" : "estimated surface"
            self?.sessionStatusText = "Point placed on \(surfaceType)"
        }
    }
    
    private func addMeasurementPoint(_ position: SCNVector3) {
        // Don't add points if polygon is already closed
        if isPolygonClosed { return }
        
        // Add the point to our measurements
        measurementPoints.append(position)
        
        // Create visual point
        // Calculate scaling distance based on existing measurements or default
        let scalingDistance = measurements.map { $0.distance }.max() ?? 0.5
        let pointNode = createPointNode(at: position, scalingDistance: scalingDistance)
        arView?.scene.rootNode.addChildNode(pointNode)
        pointNodes.append(pointNode)
        
        // Create line if we have at least 2 points
        if measurementPoints.count >= 2 {
            let startPoint = measurementPoints[measurementPoints.count - 2]
            let endPoint = position
            
            let lineNode = createLineNode(from: startPoint, to: endPoint)
            arView?.scene.rootNode.addChildNode(lineNode)
            lineNodes.append(lineNode)
        
            
            // Update measurements array for tracking
            let measurement = MeasurementLine(
                id: UUID(),
                startPoint: startPoint,
                endPoint: endPoint,
                distance: startPoint.distance(to: endPoint)
            )
            measurements.append(measurement)
        }
        
        updateTotalMeasurements()
    }
    
    func closePolygon() {
        guard measurementPoints.count >= 3, !isPolygonClosed else { return }
        
        // Connect the last point to the first point
        let firstPoint = measurementPoints[0]
        let lastPoint = measurementPoints[measurementPoints.count - 1]
        
        let lineNode = createLineNode(from: lastPoint, to: firstPoint)
        arView?.scene.rootNode.addChildNode(lineNode)
        lineNodes.append(lineNode)
        
        // Create closing measurement line object
        let closingMeasurement = MeasurementLine(
            id: UUID(),
            startPoint: lastPoint,
            endPoint: firstPoint,
            distance: lastPoint.distance(to: firstPoint)
        )
        measurements.append(closingMeasurement)
        
        isPolygonClosed = true
        updateTotalMeasurements()
        
        // POLYGON FILL COMMENTED OUT FOR NOW (AREA FUNCTIONALITY DISABLED)
        // Create polygon fill for visualization
        // let polygonNode = createPolygonNode(points: measurementPoints)
        // arView?.scene.rootNode.addChildNode(polygonNode)
        // polygonNodes.append(polygonNode)
        
        // AREA CODE COMMENTED OUT FOR NOW
        // Add area text at the center using largest distance for scaling
        // let center = calculateCentroid(of: measurementPoints)
        // let areaText: String
        // if totalArea < 1.0 {
        //     areaText = "Area: \(String(format: "%.0f cm²", totalArea * 10000))"
        // } else {
        //     areaText = "Area: \(String(format: "%.2f m²", totalArea))"
        // }
        
        // Find the largest distance measurement for scaling
        // let largestDistance = measurements.map { $0.distance }.max() ?? 0.5
        // let areaTextNode = create2DLabelNode(text: areaText, at: center, scalingDistance: largestDistance)
        // arView?.scene.rootNode.addChildNode(areaTextNode)
        // polygonNodes.append(areaTextNode)
    }
    
    private func createPolygonFill() {
        guard measurementPoints.count >= 3 else { return }
        
        // Create a semi-transparent polygon fill
        let vertices = measurementPoints.map { point in
            SCNVector3(point.x, point.y, point.z)
        }
        
        // Create geometry from vertices (simplified triangulation)
        let geometry = createPolygonGeometry(from: vertices)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.2)
        material.isDoubleSided = true
        geometry.materials = [material]
        
        let polygonNode = SCNNode(geometry: geometry)
        arView?.scene.rootNode.addChildNode(polygonNode)
        polygonNodes.append(polygonNode)
        
        // AREA CODE COMMENTED OUT FOR NOW
        // Add area text at the center using largest distance for scaling
        // let center = calculateCentroid(of: measurementPoints)
        // let areaText: String
        // if totalArea < 1.0 {
        //     areaText = "Area: \(String(format: "%.0f cm²", totalArea * 10000))"
        // } else {
        //     areaText = "Area: \(String(format: "%.2f m²", totalArea))"
        // }
        
        // Find the largest distance measurement for scaling
        // let largestDistance = measurements.map { $0.distance }.max() ?? 0.5
        // let areaTextNode = create2DLabelNode(text: areaText, at: center, scalingDistance: largestDistance)
        // arView?.scene.rootNode.addChildNode(areaTextNode)
        // polygonNodes.append(areaTextNode)
    }
    
    private func createPolygonGeometry(from vertices: [SCNVector3]) -> SCNGeometry {
        // Simple triangulation for polygon (assuming convex polygon)
        var triangleIndices: [Int32] = []
        
        for i in 1..<vertices.count - 1 {
            triangleIndices.append(0)
            triangleIndices.append(Int32(i))
            triangleIndices.append(Int32(i + 1))
        }
        
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let indexData = Data(bytes: triangleIndices, count: triangleIndices.count * MemoryLayout<Int32>.size)
        let geometryElement = SCNGeometryElement(data: indexData, primitiveType: .triangles, primitiveCount: triangleIndices.count / 3, bytesPerIndex: MemoryLayout<Int32>.size)
        
        return SCNGeometry(sources: [vertexSource], elements: [geometryElement])
    }
    
    private func calculateCentroid(of points: [SCNVector3]) -> SCNVector3 {
        let sum = points.reduce(SCNVector3(0, 0, 0)) { result, point in
            SCNVector3(result.x + point.x, result.y + point.y, result.z + point.z)
        }
        let count = Float(points.count)
        return SCNVector3(sum.x / count, sum.y / count + 0.02, sum.z / count)
    }
    
    private func createPointNode(at position: SCNVector3, surfaceType: ARHitTestResult.ResultType = .estimatedHorizontalPlane, scalingDistance: Float = 0.5) -> SCNNode {
        // Create sphere geometry for the point - scale based on distance
        let baseRadius: Float = 0.025 // Much bigger base size
        let scaleFactor = min(max(scalingDistance * 0.1, 2.0), 5.0) // Scale between 2x-5x based on distance
        let sphere = SCNSphere(radius: CGFloat(baseRadius * scaleFactor))
        
        // Color based on surface detection quality
        let material = SCNMaterial()
        switch surfaceType {
        case .existingPlaneUsingExtent:
            material.diffuse.contents = UIColor.systemGreen // High confidence
        case .estimatedHorizontalPlane, .estimatedVerticalPlane:
            material.diffuse.contents = UIColor.white // Standard
        default:
            material.diffuse.contents = UIColor.systemOrange // Lower confidence
        }
        
        material.lightingModel = .constant
        sphere.materials = [material]
        
        let pointNode = SCNNode(geometry: sphere)
        pointNode.position = position
        
        // Add a subtle glow effect for better visibility
        let glowRadius: Float = 0.035 // Bigger glow to match bigger dots
        let glowGeometry = SCNSphere(radius: CGFloat(glowRadius * scaleFactor))
        let glowMaterial = SCNMaterial()
        glowMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        glowMaterial.lightingModel = .constant
        glowGeometry.materials = [glowMaterial]
        
        let glowNode = SCNNode(geometry: glowGeometry)
        pointNode.addChildNode(glowNode)
        
        return pointNode
    }
    
    private func createLineNode(from start: SCNVector3, to end: SCNVector3) -> SCNNode {
        let distance = start.distance(to: end)
        
        // Create a bold white line
        let cylinder = SCNCylinder(radius: 0.005, height: CGFloat(distance))
        
        // White material for the line
        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = UIColor.white
        lineMaterial.lightingModel = .constant
        cylinder.materials = [lineMaterial]
        
        let lineNode = SCNNode(geometry: cylinder)
        lineNode.position = start.midPoint(to: end)
        
        // Orient the cylinder towards the end point
        lineNode.look(at: end, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        
        // Create 2D label for distance
        let textString = formatDistance(distance)
        
        // Scale label size based on line distance
        let scaleFactor = min(max(CGFloat(distance) * 200, 60), 200) // Scale between 60-200 based on distance
        let sceneWidth = scaleFactor * 2
        let sceneHeight = scaleFactor * 0.6
        
        // Create a sprite text node for true 2D appearance
        let skScene = SKScene(size: CGSize(width: sceneWidth, height: sceneHeight))
        skScene.backgroundColor = UIColor.clear
        skScene.scaleMode = .aspectFit
        
        // Scale background and text based on line length
        let backgroundWidth = scaleFactor * 1.2
        let backgroundHeight = scaleFactor * 0.4
        let fontSize = scaleFactor * 0.24
        
        // Create the label background
        let backgroundNode = SKShapeNode(rectOf: CGSize(width: backgroundWidth, height: backgroundHeight), cornerRadius: backgroundHeight * 0.5)
        backgroundNode.fillColor = UIColor.white
        backgroundNode.strokeColor = UIColor.clear
        backgroundNode.position = CGPoint(x: sceneWidth/2, y: sceneHeight/2)
        skScene.addChild(backgroundNode)
        
        // Create the text label
        let label = SKLabelNode(text: textString)
        label.fontName = "Helvetica-Bold"
        label.fontSize = fontSize
        label.fontColor = UIColor.black
        label.position = CGPoint(x: sceneWidth/2, y: sceneHeight/2)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        skScene.addChild(label)
        
        // Create plane for the label - scale with distance
        let planeWidth = CGFloat(distance) * 0.3 + 0.05 // Proportional to line length
        let planeHeight = planeWidth * 0.3 // Maintain aspect ratio
        let plane = SCNPlane(width: planeWidth, height: planeHeight)
        let material = SCNMaterial()
        material.diffuse.contents = skScene
        material.isDoubleSided = true
        material.lightingModel = .constant
        
        // Fix flipped text by adjusting texture transform
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(1, -1, 1)
        material.diffuse.wrapT = .repeat
        
        plane.materials = [material]
        
        let textNode = SCNNode(geometry: plane)
        textNode.position = SCNVector3(0, 0, 0.05)
        
        // Add billboard constraint so label always faces camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.all]
        textNode.constraints = [billboardConstraint]
        
        // Add text as child of line
        lineNode.addChildNode(textNode)
        
        return lineNode
    }
    
    private func createTextNode(text: String, at position: SCNVector3) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 0.0) // Set to 0.0 for flat 2D text
        textGeometry.font = UIFont.systemFont(ofSize: 0.12, weight: .semibold)
        textGeometry.flatness = 0.01 // Make text smoother for 2D appearance
        
        // Create black text material
        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = UIColor.black
        textMaterial.lightingModel = .constant // Use constant lighting for flat appearance
        textMaterial.isDoubleSided = true // Make text visible from both sides
        textGeometry.materials = [textMaterial]
        
        let textNode = SCNNode(geometry: textGeometry)
        
        // Get text bounds for background sizing
        let textBounds = textGeometry.boundingBox
        let textWidth = textBounds.max.x - textBounds.min.x
        let textHeight = textBounds.max.y - textBounds.min.y
        
        // Create white background as flat plane for true 2D appearance
        let backgroundGeometry = SCNPlane(width: CGFloat(textWidth + 0.015), height: CGFloat(textHeight + 0.01))
        backgroundGeometry.cornerRadius = CGFloat((textHeight + 0.01) * 0.25) // Rounded corners
        let backgroundMaterial = SCNMaterial()
        backgroundMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.95)
        backgroundMaterial.lightingModel = .constant
        backgroundMaterial.isDoubleSided = true // Make background visible from both sides
        backgroundGeometry.materials = [backgroundMaterial]
        
        let backgroundNode = SCNNode(geometry: backgroundGeometry)
        
        // Position text and background at exactly the same z-depth (both completely flat)
        textNode.position = SCNVector3(-textWidth/2, -textHeight/2, 0.0)
        backgroundNode.position = SCNVector3(0, 0, 0.0)
        
        // Container node positioned at the exact world position
        let containerNode = SCNNode()
        containerNode.addChildNode(backgroundNode)
        containerNode.addChildNode(textNode)
        containerNode.position = position
        containerNode.scale = SCNVector3(0.08, 0.08, 0.08)
        
        // Keep flat orientation for 2D appearance
        containerNode.eulerAngles = SCNVector3(0, 0, 0)
        
        return containerNode
    }
    
    func undoLastPoint() {
        guard !measurementPoints.isEmpty else { return }
        
        // If polygon is closed, reopen it
        if isPolygonClosed {
            isPolygonClosed = false
            
            // Remove polygon fill
            polygonNodes.forEach { $0.removeFromParentNode() }
            polygonNodes.removeAll()
            
            // Remove the closing line
            if !lineNodes.isEmpty {
                lineNodes.removeLast().removeFromParentNode()
            }
            if !measurements.isEmpty {
                measurements.removeLast()
            }
        } else {
            // Remove the last point
            measurementPoints.removeLast()
            
            // Remove visual elements
            if let lastPointNode = pointNodes.popLast() {
                lastPointNode.removeFromParentNode()
            }
            
            if !lineNodes.isEmpty {
                let lastLineNode = lineNodes.removeLast()
                lastLineNode.removeFromParentNode()
            }
            
            if !measurements.isEmpty {
                measurements.removeLast()
            }
        }
        
        updateTotalMeasurements()
    }
    
    func clearMeasurements() {
        // Remove all measurement points
        measurementPoints.removeAll()
        measurements.removeAll()
        
        // Remove all visual elements from scene
        pointNodes.forEach { $0.removeFromParentNode() }
        lineNodes.forEach { $0.removeFromParentNode() }
        objectNodes.forEach { $0.removeFromParentNode() }
        polygonNodes.forEach { $0.removeFromParentNode() }
        
        // Clear arrays
        pointNodes.removeAll()
        lineNodes.removeAll()
        objectNodes.removeAll()
        polygonNodes.removeAll()
        
        // Reset measurements
        detectedObjects.removeAll()
        totalDistance = 0.0
        totalArea = 0.0
        isPolygonClosed = false
    }
    
    // MARK: - Dismiss Functionality
    var onDismiss: (() -> Void)?
    var onSubmit: ((MeasurementResult) -> Void)?
    
    func dismissView() {
        onDismiss?()
    }
    
    func cancelMeasurement() {
        pauseARSession()
        onDismiss?()
    }
    
    func submitMeasurements() {
        let result = MeasurementResult(
            totalDistance: totalDistance,
            measurementLines: measurements
        )
        pauseARSession()
        onSubmit?(result)
    }
    
    private func pauseARSession() {
        arView?.session.pause()
    }
    
    deinit {
        pauseARSession()
    }
    
    func toggleObjectDetection() {
        isObjectDetectionEnabled.toggle()
        
        if !isObjectDetectionEnabled {
            // Clear detected objects
            objectNodes.forEach { $0.removeFromParentNode() }
            objectNodes.removeAll()
            detectedObjects.removeAll()
        }
    }
    
    private func updateTotalMeasurements() {
        totalDistance = measurements.reduce(0) { $0 + $1.distance }
        
        // AREA FUNCTIONALITY COMMENTED OUT FOR NOW
        // Calculate area if we have a closed polygon (3+ points forming a closed shape)
        // if measurementPoints.count >= 3 {
        //     totalArea = calculatePolygonArea()
        // } else {
        //     totalArea = 0
        // }
    }
    
    private func calculatePolygonArea() -> Float {
        guard measurementPoints.count >= 3 else { return 0 }
        
        // Use the shoelace formula for polygon area calculation
        var area: Float = 0.0
        let points = measurementPoints
        
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            area += points[i].x * points[j].z - points[j].x * points[i].z
        }
        
        return abs(area) / 2.0
    }
    
    private func detectRectangularObjects(in frame: ARFrame) {
        guard isObjectDetectionEnabled else { return }
        
        // Enhanced object detection using plane anchors
        let anchors = frame.anchors.compactMap { $0 as? ARPlaneAnchor }
        
        for anchor in anchors {
            // Filter for reasonably sized rectangular objects
            if anchor.extent.x > 0.05 && anchor.extent.z > 0.05 && 
               anchor.extent.x < 2.0 && anchor.extent.z < 2.0 {
                
                let aspectRatio = anchor.extent.x / anchor.extent.z
                
                // Check if it's roughly rectangular (aspect ratio not too extreme)
                if aspectRatio > 0.3 && aspectRatio < 3.0 {
                    let detectedObject = DetectedObject(
                        id: anchor.identifier,
                        width: anchor.extent.x,
                        height: anchor.extent.z,
                        area: anchor.extent.x * anchor.extent.z,
                        center: SCNVector3(anchor.center.x, anchor.center.y, anchor.center.z)
                    )
                    
                    if !detectedObjects.contains(where: { $0.id == detectedObject.id }) {
                        detectedObjects.append(detectedObject)
                        createObjectVisualization(for: detectedObject, anchor: anchor)
                    }
                }
            }
        }
    }
    
    private func createObjectVisualization(for object: DetectedObject, anchor: ARPlaneAnchor) {
        // Create a rectangle outline with corner indicators
        let outlineNode = createRectangleOutline(width: object.width, height: object.height)
        outlineNode.position = SCNVector3(anchor.center.x, anchor.center.y + 0.001, anchor.center.z)
        outlineNode.eulerAngles.x = -.pi / 2 // Rotate to lie flat
        
        // Add measurement text with dynamic units
        // AREA CODE COMMENTED OUT FOR NOW
        // let areaText: String
        // if object.area < 1.0 {
        //     areaText = String(format: "%.0f cm²", object.area * 10000)
        // } else {
        //     areaText = String(format: "%.2f m²", object.area)
        // }
        
        let dimensionsText: String
        if object.width < 1.0 && object.height < 1.0 {
            dimensionsText = String(format: "%.1f × %.1f cm", object.width * 100, object.height * 100)
        } else {
            dimensionsText = String(format: "%.2f × %.2f m", object.width, object.height)
        }
        
        // AREA CODE COMMENTED OUT FOR NOW
        // let areaTextNode = create2DLabelNode(text: areaText, at: SCNVector3(anchor.center.x, anchor.center.y + 0.05, anchor.center.z), scalingDistance: measurements.map { $0.distance }.max() ?? max(object.width, object.height))
        let dimensionsTextNode = create2DLabelNode(text: dimensionsText, at: SCNVector3(anchor.center.x, anchor.center.y + 0.03, anchor.center.z), scalingDistance: measurements.map { $0.distance }.max() ?? max(object.width, object.height))
        
        arView?.scene.rootNode.addChildNode(outlineNode)
        // arView?.scene.rootNode.addChildNode(areaTextNode)
        arView?.scene.rootNode.addChildNode(dimensionsTextNode)
        
        objectNodes.append(outlineNode)
        // objectNodes.append(areaTextNode)
        objectNodes.append(dimensionsTextNode)
    }
    
    private func createRectangleOutline(width: Float, height: Float) -> SCNNode {
        let parentNode = SCNNode()
        
        // Create corner indicators
        let cornerRadius: Float = 0.002
        let cornerLength: Float = min(width, height) * 0.1
        
        let corners = [
            SCNVector3(-width/2, 0, -height/2),
            SCNVector3(width/2, 0, -height/2),
            SCNVector3(width/2, 0, height/2),
            SCNVector3(-width/2, 0, height/2)
        ]
        
        for corner in corners {
            let cornerNode = createCornerIndicator(at: corner, length: cornerLength, radius: cornerRadius)
            parentNode.addChildNode(cornerNode)
        }
        
        return parentNode
    }
    
    private func createCornerIndicator(at position: SCNVector3, length: Float, radius: Float) -> SCNNode {
        let parentNode = SCNNode()
        
        // Create two perpendicular lines for each corner
        let line1 = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
        let line2 = SCNCylinder(radius: CGFloat(radius), height: CGFloat(length))
        
        line1.materials.first?.diffuse.contents = UIColor.systemYellow
        line2.materials.first?.diffuse.contents = UIColor.systemYellow
        
        let node1 = SCNNode(geometry: line1)
        let node2 = SCNNode(geometry: line2)
        
        node1.position = SCNVector3(position.x + length/2, position.y, position.z)
        node2.position = SCNVector3(position.x, position.y, position.z + length/2)
        
        node1.eulerAngles.z = .pi / 2
        
        parentNode.addChildNode(node1)
        parentNode.addChildNode(node2)
        parentNode.position = position
        
        return parentNode
    }
    
    private func create2DLabelNode(text: String, at position: SCNVector3, scalingDistance: Float = 0.5) -> SCNNode {
        // Scale label size based on the largest distance measurement (like distance labels)
        let scaleFactor = min(max(CGFloat(scalingDistance) * 200, 60), 200) // Same scaling as distance labels
        let sceneWidth = scaleFactor * 1.5
        let sceneHeight = scaleFactor * 0.4
        
        // Create a sprite text node for true 2D appearance
        let skScene = SKScene(size: CGSize(width: sceneWidth, height: sceneHeight))
        skScene.backgroundColor = UIColor.clear
        skScene.scaleMode = .aspectFit
        
        // Scale background and text based on largest distance
        let backgroundWidth = scaleFactor * 1.0
        let backgroundHeight = scaleFactor * 0.3
        let centerX = sceneWidth / 2
        let centerY = sceneHeight / 2
        
        // Create the label background
        let backgroundNode = SKShapeNode(rectOf: CGSize(width: backgroundWidth, height: backgroundHeight), cornerRadius: backgroundHeight * 0.25)
        backgroundNode.fillColor = UIColor.white
        backgroundNode.strokeColor = UIColor.clear
        backgroundNode.position = CGPoint(x: centerX, y: centerY)
        skScene.addChild(backgroundNode)
        
        // Create the text label with scaled font size
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = scaleFactor * 0.2
        label.fontColor = UIColor.black
        label.position = CGPoint(x: centerX, y: centerY - label.fontSize * 0.3)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        skScene.addChild(label)
        
        // Create plane size based on scaling distance
        let labelPlane = SCNPlane(width: CGFloat(scalingDistance * 0.4), height: CGFloat(scalingDistance * 0.15))
        let material = SCNMaterial()
        material.diffuse.contents = skScene
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(1, -1, 1) // Fix flipped text
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        labelPlane.materials = [material]
        
        let labelNode = SCNNode(geometry: labelPlane)
        labelNode.position = position
        
        // Add billboard constraint so label always faces camera
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.Y]
        labelNode.constraints = [billboardConstraint]
        
        return labelNode
    }
    
    // MARK: - Real-time Surface Detection
    private func detectSurfaceAtCenter() {
        guard let arView = arView else { return }
        
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        
        // Perform hit test for surface detection
        let hitTestResults = arView.hitTest(screenCenter, types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .estimatedVerticalPlane])
        
        DispatchQueue.main.async { [weak self] in
            if let firstResult = hitTestResults.first {
                // Surface detected
                self?.surfaceDetected = true
                self?.currentDepth = Float(firstResult.distance)
                
                // Calculate surface normal (angle)
                let transform = firstResult.worldTransform
                let normal = SCNVector3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
                self?.surfaceNormal = normal
            } else {
                // No surface detected
                self?.surfaceDetected = false
                self?.currentDepth = 0.0
            }
        }
    }
}

// MARK: - ARSCNViewDelegate
@available(iOS 15.0, *)
extension ARMeasureViewModel: ARSCNViewDelegate {
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let _ = anchor as? ARPlaneAnchor else { return }
        
        // Handle plane detection for object recognition
        DispatchQueue.main.async {
            if self.isObjectDetectionEnabled {
                // Object detection will be handled in session delegate
            }
        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle plane updates
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Continuously detect surface for crosshair feedback
        detectSurfaceAtCenter()
    }
}

// MARK: - ARSessionDelegate
@available(iOS 15.0, *)
extension ARMeasureViewModel: ARSessionDelegate {
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.main.async {
            self.detectRectangularObjects(in: frame)
        }
    }
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        DispatchQueue.main.async {
            switch camera.trackingState {
            case .normal:
                self.sessionStatus = .normal
            case .limited:
                self.sessionStatus = .limitedTracking
            case .notAvailable:
                self.sessionStatus = .notAvailable
            }
        }
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.sessionStatus = .notAvailable
        }
    }
}

// MARK: - Data Models
public struct MeasurementLine: Identifiable {
    public let id: UUID
    public let startPoint: SCNVector3
    public let endPoint: SCNVector3
    public let distance: Float
    
    public init(id: UUID, startPoint: SCNVector3, endPoint: SCNVector3, distance: Float) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.distance = distance
    }
}

public struct DetectedObject: Identifiable {
    public let id: UUID
    public let width: Float
    public let height: Float
    public let area: Float
    public let center: SCNVector3
    
    public init(id: UUID, width: Float, height: Float, area: Float, center: SCNVector3) {
        self.id = id
        self.width = width
        self.height = height
        self.area = area
        self.center = center
    }
}

// MARK: - SCNVector3 Extensions
extension SCNVector3 {
    func distance(to vector: SCNVector3) -> Float {
        let dx = self.x - vector.x
        let dy = self.y - vector.y
        let dz = self.z - vector.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    func midPoint(to vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            (self.x + vector.x) / 2,
            (self.y + vector.y) / 2,
            (self.z + vector.z) / 2
        )
    }
} 
