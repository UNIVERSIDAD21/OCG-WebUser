import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/urgency_repository.dart';
import '../data/models/urgency_model.dart';

/// Provider del repositorio de urgencias.
final urgencyRepositoryProvider = Provider<UrgencyRepository>((ref) {
  return UrgencyRepository();
});

/// Stream de todas las urgencias (admin).
final allUrgenciesProvider =
    StreamProvider<List<UrgencyRequestModel>>((ref) {
  final repo = ref.watch(urgencyRepositoryProvider);
  return repo.watchAll();
});

/// Stream de urgencias activas (pendientes + en proceso).
final activeUrgenciesProvider =
    StreamProvider<List<UrgencyRequestModel>>((ref) {
  final repo = ref.watch(urgencyRepositoryProvider);
  return repo.watchActive();
});

/// Stream de urgencias de un paciente específico.
final urgenciesByPatientProvider =
    StreamProvider.family<List<UrgencyRequestModel>, String>((ref, patientId) {
  final repo = ref.watch(urgencyRepositoryProvider);
  return repo.watchByPatient(patientId);
});

/// Conteo de urgencias pendientes (para badge).
final pendingUrgenciesCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(urgencyRepositoryProvider);
  return repo.countPending();
});
