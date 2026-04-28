import '../../features/patients/data/models/patient_model.dart';
import '../../features/simulator/data/models/simulation_model.dart';

String formatCop(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
}

String formatTreatmentStage(TreatmentStage stage) {
  return stageNames[stage] ?? stage.name;
}

String formatSimulationStatus(SimulationStatus status) {
  switch (status) {
    case SimulationStatus.draft:
      return 'Borrador';
    case SimulationStatus.generating:
      return 'Generando';
    case SimulationStatus.ready:
      return 'Lista';
    case SimulationStatus.shared:
      return 'Compartida';
    case SimulationStatus.failed:
      return 'Error';
    case SimulationStatus.archived:
      return 'Archivada';
  }
}
