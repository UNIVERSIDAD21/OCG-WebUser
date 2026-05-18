import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../legacy_migration_service.dart';
import '../../patients/providers/patients_provider.dart';

final legacyMigrationServiceProvider =
    Provider<LegacyMigrationService>((ref) {
  return LegacyMigrationService(ref.watch(firestoreProvider));
});

/// Notifier para el estado de la migracion legacy.
class LegacyMigrationNotifier extends Notifier<AsyncValue<List<LegacyMigrationResult>>> {
  @override
  AsyncValue<List<LegacyMigrationResult>> build() => const AsyncData([]);

  /// Ejecuta la migracion para todos los pacientes.
  Future<void> migrateAll() async {
    final service = ref.read(legacyMigrationServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => service.migrateAll());
  }

  /// Ejecuta la migracion para un solo paciente.
  Future<void> migratePatient({
    required String patientId,
  }) async {
    final service = ref.read(legacyMigrationServiceProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final result = await service.migratePatient(patientId: patientId);
      return [result];
    });
  }

  void reset() => state = const AsyncData([]);
}

final legacyMigrationProvider =
    NotifierProvider<LegacyMigrationNotifier, AsyncValue<List<LegacyMigrationResult>>>(
      LegacyMigrationNotifier.new,
    );
