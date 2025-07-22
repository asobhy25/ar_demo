# AR Measuring App

A Flutter-based augmented reality measuring application that replicates the functionality of the iOS Measure app.

## Features

### ✅ Implemented Features

1. **Multiple Distance Lines with Linking**
   - Tap the "+" button to enter measurement mode
   - Tap on AR planes to place measurement points
   - Automatically draws lines between consecutive points
   - Supports creating multiple connected measurement lines

2. **Virtual Line Drawing and Distance Display**
   - Real-time visualization of measurement lines in AR space
   - Clear distance labels displayed on each line segment
   - Visual markers (yellow dots) for measurement points

3. **Area Calculation Mode**
   - Switch between "Measure" and "Area" modes
   - Automatic polygon detection when points form a closed shape
   - Displays total area for closed polygons

4. **Cumulative Measurements**
   - Shows total distance for all connected lines
   - Displays cumulative area when multiple shapes are measured
   - Real-time updates as measurements are added

5. **User Interface Controls**
   - Back button: Undo last measurement point
   - Clear button: Remove all measurements
   - Mode toggle: Switch between distance and area measurement
   - Visual feedback with haptic responses

### 🚧 Advanced Features (Partially Implemented)

1. **Object Auto-Detection**
   - Basic rectangle detection algorithm implemented
   - Scans for planar rectangular objects in Area mode
   - Highlights detected objects with measurements

2. **Improved AR Rendering**
   - Uses small cubes to simulate lines (due to AR plugin limitations)
   - Point markers at measurement locations
   - Basic object highlighting for detected shapes

## Architecture

### Project Structure
```
lib/
├── main.dart                    # App entry point
├── ar_measuring_screen.dart     # Main AR measurement screen
├── models/
│   └── measurement_models.dart  # Data models for measurements
├── services/
│   ├── measurement_manager.dart # State management for measurements
│   ├── ar_renderer.dart        # AR object rendering
│   └── object_detection_service.dart # Rectangle/plane detection
└── widgets/
    └── measurement_display.dart # UI overlays for measurements
```

### Key Components

1. **MeasurementManager**: Handles all measurement state and calculations
2. **ARRenderer**: Manages AR object creation and removal
3. **ObjectDetectionService**: Detects rectangular shapes from AR hit points
4. **MeasurementDisplay Widgets**: Overlay UI components for showing measurements

## Technical Implementation

### Measurement System
- Uses ARCore/ARKit plane detection via `ar_flutter_plugin`
- Captures 3D world positions from AR hit tests
- Calculates distances using vector mathematics
- Implements shoelace formula for polygon area calculation

### AR Visualization
- Due to plugin limitations, lines are rendered as series of small cubes
- Uses GLTF models for 3D objects
- Overlays 2D UI elements on top of AR view

### State Management
- Uses Flutter's built-in state management with `setState`
- MeasurementManager extends ChangeNotifier for reactive updates
- Maintains lists of points, lines, and detected objects

## Usage

1. **Distance Measurement Mode**
   - Tap the "+" button
   - Tap on detected planes to place points
   - Lines automatically connect consecutive points
   - View individual and total distances

2. **Area Measurement Mode**
   - Switch to "Area" mode using bottom toggle
   - Tap "+" to start scanning
   - The app will attempt to detect rectangular objects
   - Detected objects show area and dimensions

3. **Managing Measurements**
   - Use back arrow to undo last point
   - Use "Clear" to remove all measurements
   - Switch modes to change measurement type

## Limitations

1. **AR Plugin Constraints**
   - Cannot render true lines; uses point approximation
   - Limited shape primitives available
   - Hit testing requires tap interaction

2. **Object Detection**
   - Basic rectangle detection only
   - Requires good lighting and clear surfaces
   - May not detect all rectangular objects accurately

3. **UI Positioning**
   - 2D overlay positioning is simplified
   - Would benefit from proper 3D-to-2D projection matrix

## Future Enhancements

1. **Improved Object Detection**
   - Machine learning-based object recognition
   - Support for more shape types
   - Better edge detection algorithms

2. **Enhanced Visualization**
   - Custom line rendering with shaders
   - Better measurement label positioning
   - 3D text rendering in AR space

3. **Additional Features**
   - Save/export measurements
   - Level tool functionality
   - Volume calculations for 3D objects
   - Measurement history

4. **Platform Optimization**
   - iOS-specific optimizations using ARKit
   - Android-specific features with ARCore
   - Better device compatibility

## Dependencies

- `ar_flutter_plugin: ^0.7.3` - AR functionality
- `vector_math: ^2.1.4` - 3D mathematics
- `provider: ^6.1.1` - State management (optional)

## Requirements

- Flutter SDK: ^3.5.0
- iOS: ARKit-compatible device (iPhone 6S or newer)
- Android: ARCore-compatible device

## Installation

1. Ensure Flutter is installed and configured
2. Clone this repository
3. Run `flutter pub get`
4. Connect an AR-capable device
5. Run `flutter run`

## Known Issues

- AR tracking may drift in low-light conditions
- Object detection accuracy varies with surface texture
- Some Android devices may have performance issues

## Contributing

This project demonstrates AR measurement capabilities in Flutter. Feel free to fork and enhance with additional features!
