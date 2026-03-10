import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/patient_model.dart';
import '../data/repositories/patients_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  return PatientsRepository(ref.watch(firestoreProvider));
});

final patientsStreamProvider = StreamProvider<List<PatientModel>>((ref) {
  return ref.watch(patientsRepositoryProvider).watchAllPatients();
});

final patientByIdProvider = StreamProvider.family<PatientModel?, String>((ref, patientId) {
  return ref.watch(patientsRepositoryProvider).watchPatient(patientId);
});

class PatientsSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final patientsSearchQueryProvider = NotifierProvider<PatientsSearchQueryNotifier, String>(
  PatientsSearchQueryNotifier.new,
);

class PatientsFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Todos';

  void setFilter(String value) => state = value;
}

final patientsFilterProvider = NotifierProvider<PatientsFilterNotifier, String>(
  PatientsFilterNotifier.new,
);

final filteredPatientsProvider = Provider<List<PatientModel>>((ref) {
  final asyncPatients = ref.watch(patientsStreamProvider);
  final query = ref.watch(patientsSearchQueryProvider).trim().toLowerCase();
  final filter = ref.watch(patientsFilterProvider);

  final patients = asyncPatients.asData?.value ?? const <PatientModel>[];

  bool matchesFilter(PatientModel p) {
    if (filter == 'Todos') return true;
    if (filter == 'Pendientes') {
      return p.tipoTratamiento == null;
    }
    if (filter == 'Alta') return p.etapaActual == TreatmentStage.alta;
    if (filter == 'Activos') return p.etapaActual != TreatmentStage.alta;
    return p.tipoTratamiento?.name == filter.toLowerCase();
  }

  bool matchesQuery(PatientModel p) {
    if (query.isEmpty) return true;
    return p.nombre.toLowerCase().contains(query) || p.email.toLowerCase().contains(query);
  }

  return patients.where((p) => matchesFilter(p) && matchesQuery(p)).toList();
});
