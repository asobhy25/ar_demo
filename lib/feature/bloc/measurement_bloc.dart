import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'measurement_event.dart';
import 'measurement_state.dart';

class MeasurementBloc extends Bloc<MeasurementEvent, MeasurementState> {
  MeasurementBloc() : super(const MeasurementInitial()) {
    on<AddPointEvent>(_onAddPoint);
    on<ClearMeasurementEvent>(_onClearMeasurement);
    on<ResetMeasurementEvent>(_onResetMeasurement);
  }

  void _onAddPoint(AddPointEvent event, Emitter<MeasurementState> emit) {
    final currentState = state;

    if (currentState is MeasurementInitial) {
      // First point
      emit(MeasurementFirstPointPlaced(event.position));
    } else if (currentState is MeasurementFirstPointPlaced) {
      // Second point - calculate distance
      final distance = (event.position - currentState.firstPoint).length;
      emit(MeasurementCompleted(
        firstPoint: currentState.firstPoint,
        secondPoint: event.position,
        distance: distance,
      ));
    } else if (currentState is MeasurementCompleted) {
      // Third point - transition to multi-point
      final points = [
        currentState.firstPoint,
        currentState.secondPoint,
        event.position,
      ];
      final distances = _calculateDistances(points);
      final totalDistance = distances.fold<double>(0.0, (sum, dist) => sum + dist);

      emit(MeasurementMultiPoint(
        points: points,
        distances: distances,
        totalDistance: totalDistance,
      ));
    } else if (currentState is MeasurementMultiPoint) {
      // Add another point to existing multi-point measurement
      final newPoints = List<vector.Vector3>.from(currentState.points)..add(event.position);
      final distances = _calculateDistances(newPoints);
      final totalDistance = distances.fold<double>(0.0, (sum, dist) => sum + dist);

      emit(MeasurementMultiPoint(
        points: newPoints,
        distances: distances,
        totalDistance: totalDistance,
      ));
    }
  }

  List<double> _calculateDistances(List<vector.Vector3> points) {
    final distances = <double>[];
    for (int i = 0; i < points.length - 1; i++) {
      final distance = (points[i + 1] - points[i]).length;
      distances.add(distance);
    }
    return distances;
  }

  void _onClearMeasurement(ClearMeasurementEvent event, Emitter<MeasurementState> emit) {
    emit(const MeasurementInitial());
  }

  void _onResetMeasurement(ResetMeasurementEvent event, Emitter<MeasurementState> emit) {
    emit(const MeasurementInitial());
  }
}
