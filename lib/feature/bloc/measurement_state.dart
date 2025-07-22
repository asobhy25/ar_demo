import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

abstract class MeasurementState extends Equatable {
  const MeasurementState();

  @override
  List<Object> get props => [];
}

class MeasurementInitial extends MeasurementState {
  const MeasurementInitial();
}

class MeasurementFirstPointPlaced extends MeasurementState {
  final vector.Vector3 firstPoint;

  const MeasurementFirstPointPlaced(this.firstPoint);

  @override
  List<Object> get props => [firstPoint];
}

class MeasurementCompleted extends MeasurementState {
  final vector.Vector3 firstPoint;
  final vector.Vector3 secondPoint;
  final double distance;

  const MeasurementCompleted({
    required this.firstPoint,
    required this.secondPoint,
    required this.distance,
  });

  @override
  List<Object> get props => [firstPoint, secondPoint, distance];

  String get formattedDistance {
    if (distance < 1.0) {
      return '${(distance * 100).toStringAsFixed(1)} cm';
    } else {
      return '${distance.toStringAsFixed(2)} m';
    }
  }
}

class MeasurementMultiPoint extends MeasurementState {
  final List<vector.Vector3> points;
  final List<double> distances; // Distances between consecutive points
  final double? totalDistance; // Sum of all distances

  const MeasurementMultiPoint({
    required this.points,
    required this.distances,
    this.totalDistance,
  });

  @override
  List<Object> get props => [points, distances, totalDistance ?? 0];

  String get formattedTotalDistance {
    if (totalDistance == null) return '0.0 m';
    if (totalDistance! < 1.0) {
      return '${(totalDistance! * 100).toStringAsFixed(1)} cm';
    } else {
      return '${totalDistance!.toStringAsFixed(2)} m';
    }
  }

  String getDistanceAt(int index) {
    if (index >= distances.length) return '';
    final dist = distances[index];
    if (dist < 1.0) {
      return '${(dist * 100).toStringAsFixed(1)} cm';
    } else {
      return '${dist.toStringAsFixed(2)} m';
    }
  }
}
