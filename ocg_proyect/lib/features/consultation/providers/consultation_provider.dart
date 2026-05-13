import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patients/providers/patients_provider.dart';
import '../data/models/consultation_model.dart';
import '../data/repositories/consultation_repository.dart';

// ─── Repository ───────────────────────────────────────────────────────────────

final consultationRepositoryProvider =
    Provider<ConsultationRepository>((ref) {
  return ConsultationRepository(ref.watch(firestoreProvider));
});

// ─── Consultas de un paciente ────────────────────────────────────────────────

final patientConsultationsProvider =
    StreamProvider.family<List<ConsultationModel>, String>((ref, patientId) {
  return ref
      .watch(consultationRepositoryProvider)
      .watchPatientConsultations(patientId);
});

// ─── Estado local de la pantalla de consulta (NotifierProvider pattern) ──────

class ConsultationFormState {
  const ConsultationFormState({
    this.clinicalNotes = '',
    this.advancePhase = false,
    this.targetStageName,
    this.isSaving = false,
    this.error,
  });

  final String clinicalNotes;
  final bool advancePhase;
  final String? targetStageName;
  final bool isSaving;
  final String? error;

  ConsultationFormState copyWith({
    String? clinicalNotes,
    bool? advancePhase,
    String? targetStageName,
    bool? isSaving,
    String? error,
  }) {
    return ConsultationFormState(
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      advancePhase: advancePhase ?? this.advancePhase,
      targetStageName: targetStageName ?? this.targetStageName,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class ConsultationFormNotifier extends Notifier<ConsultationFormState> {
  @override
  ConsultationFormState build() => const ConsultationFormState();

  void setNotes(String notes) =>
      state = state.copyWith(clinicalNotes: notes, error: null);

  void setAdvancePhase(bool value) =>
      state = state.copyWith(advancePhase: value, error: null);

  void setTargetStageName(String? name) =>
      state = state.copyWith(targetStageName: name);

  void setSaving(bool value) =>
      state = state.copyWith(isSaving: value, error: null);

  void setError(String error) =>
      state = state.copyWith(error: error, isSaving: false);

  void reset() => state = const ConsultationFormState();
}

final consultationFormProvider =
    NotifierProvider<ConsultationFormNotifier, ConsultationFormState>(
  ConsultationFormNotifier.new,
);
