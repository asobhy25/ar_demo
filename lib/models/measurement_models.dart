// MARK: - Flutter Measurement Models

class MeasurementPoint {
  final double? x;
  final double? y;
  final double? z;

  const MeasurementPoint({
    this.x,
    this.y,
    this.z,
  });

  factory MeasurementPoint.fromMap(Map<String, dynamic> map) {
    return MeasurementPoint(
      x: (map['x'] as num?)?.toDouble(),
      y: (map['y'] as num?)?.toDouble(),
      z: (map['z'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x': x,
      'y': y,
      'z': z,
    };
  }

  @override
  String toString() => 'MeasurementPoint(x: $x, y: $y, z: $z)';
}

class MeasurementLine {
  final String? id;
  final double? distance;
  final MeasurementPoint? startPoint;
  final MeasurementPoint? endPoint;

  const MeasurementLine({
    this.id,
    this.distance,
    this.startPoint,
    this.endPoint,
  });

  factory MeasurementLine.fromMap(Map<String, dynamic> map) {
    try {
      return MeasurementLine(
        id: map['id'] as String?,
        distance: (map['distance'] as num?)?.toDouble(),
        startPoint: map['startPoint'] != null ? _parsePoint(map['startPoint']) : null,
        endPoint: map['endPoint'] != null ? _parsePoint(map['endPoint']) : null,
      );
    } catch (e) {
      print('Error in MeasurementLine.fromMap: $e');
      print('Map content: $map');
      rethrow;
    }
  }

  static MeasurementPoint _parsePoint(dynamic pointData) {
    if (pointData is Map<String, dynamic>) {
      return MeasurementPoint.fromMap(pointData);
    } else if (pointData is Map) {
      return MeasurementPoint.fromMap(Map<String, dynamic>.from(pointData));
    } else {
      throw Exception('Invalid point data type: ${pointData.runtimeType}');
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distance': distance,
      'startPoint': startPoint?.toMap(),
      'endPoint': endPoint?.toMap(),
    };
  }

  @override
  String toString() => 'MeasurementLine(id: $id, distance: ${distance?.toStringAsFixed(3)}m)';
}

class MeasurementResult {
  final double? totalDistance;
  final List<MeasurementLine>? measurementLines;

  const MeasurementResult({
    this.totalDistance,
    this.measurementLines,
  });

  factory MeasurementResult.fromMap(Map<String, dynamic> map) {
    try {
      final linesData = map['measurementLines'] as List<dynamic>? ?? [];

      final lines = linesData.map((lineMap) {
        if (lineMap is Map<String, dynamic>) {
          return MeasurementLine.fromMap(lineMap);
        } else if (lineMap is Map) {
          return MeasurementLine.fromMap(Map<String, dynamic>.from(lineMap));
        } else {
          throw Exception('Invalid line data type: ${lineMap.runtimeType}');
        }
      }).toList();

      return MeasurementResult(
        totalDistance: (map['totalDistance'] as num?)?.toDouble(),
        measurementLines: lines.isNotEmpty ? lines : null,
      );
    } catch (e) {
      print('Error in MeasurementResult.fromMap: $e');
      print('Map content: $map');
      rethrow;
    }
  }

  /// Factory constructor to handle method channel results directly
  /// Handles different Map types that can come from iOS method channel
  factory MeasurementResult.fromMethodChannelResult(dynamic result) {
    try {
      print('Raw result type: ${result.runtimeType}');
      print('Raw result content: $result');

      // Handle different result types from method channel
      Map<String, dynamic> resultMap;
      if (result is Map<String, dynamic>) {
        resultMap = result;
      } else if (result is Map) {
        resultMap = Map<String, dynamic>.from(result);
      } else {
        throw Exception('Unexpected result type: ${result.runtimeType}');
      }

      return MeasurementResult.fromMap(resultMap);
    } catch (e) {
      print('Error in MeasurementResult.fromMethodChannelResult: $e');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'totalDistance': totalDistance,
      'measurementLines': measurementLines?.map((line) => line.toMap()).toList(),
    };
  }

  String get formattedTotalDistance => '${totalDistance?.toStringAsFixed(2) ?? '0.00'}m';

  int get measurementLinesCount => measurementLines?.length ?? 0;

  @override
  String toString() => 'MeasurementResult(totalDistance: $formattedTotalDistance, lines: $measurementLinesCount)';
}
