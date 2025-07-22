import 'package:equatable/equatable.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

abstract class MeasurementEvent extends Equatable {
  const MeasurementEvent();

  @override
  List<Object> get props => [];
}

class AddPointEvent extends MeasurementEvent {
  final vector.Vector3 position;

  const AddPointEvent(this.position);

  @override
  List<Object> get props => [position];
}

class CapturePointAtCenterEvent extends MeasurementEvent {
  const CapturePointAtCenterEvent();
}

class ClearMeasurementEvent extends MeasurementEvent {
  const ClearMeasurementEvent();
}

class ResetMeasurementEvent extends MeasurementEvent {
  const ResetMeasurementEvent();
}
