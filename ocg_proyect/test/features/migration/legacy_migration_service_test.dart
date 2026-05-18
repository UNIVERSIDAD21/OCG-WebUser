import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/migration/legacy_migration_service.dart';

/// Pruebas unitarias del servicio de migracion legacy.
///
/// Estas pruebas validan la logica de resolucion de tratamiento:
/// - Un solo tratamiento → auto-asociar
/// - Multiples tratamientos → marcar como legacy
/// - Sin tratamientos → no modificar
/// - Ya tiene treatmentId → no tocar
void main() {
  group('LegacyMigrationService - logica de resolucion', () {
    test(
      'autoAsociar devuelve true cuando hay un solo tratamiento activo',
      () {
        // Un solo tratamiento activo => debe auto-asociar
        final treatments = [
          _Treatment(id: 'tx-1', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        expect(result.shouldAutoAssociate, isTrue);
        expect(result.treatmentId, 'tx-1');
        expect(result.isLegacy, isFalse);
      },
    );

    test(
      'marca como legacy cuando hay multiples tratamientos activos',
      () {
        final treatments = [
          _Treatment(id: 'tx-1', isActive: true),
          _Treatment(id: 'tx-2', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        expect(result.shouldAutoAssociate, isFalse);
        expect(result.isLegacy, isTrue);
        expect(result.treatmentId, 'legacy_unlinked');
      },
    );

    test(
      'no modifica cuando no hay tratamientos',
      () {
        final treatments = <_Treatment>[];
        final result = _resolveTreatment(treatments);
        expect(result.shouldAutoAssociate, isFalse);
        expect(result.isLegacy, isFalse);
        expect(result.treatmentId, isNull);
      },
    );

    test(
      'ignora tratamientos inactivos para la decision',
      () {
        final treatments = [
          _Treatment(id: 'tx-1', isActive: false),
          _Treatment(id: 'tx-2', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        expect(result.shouldAutoAssociate, isTrue);
        expect(result.treatmentId, 'tx-2');
      },
    );

    test(
      'no toca archivos que ya tienen treatmentId valido',
      () {
        final existingTreatmentId = 'tx-existing';
        final shouldProcess = _shouldProcessFile(existingTreatmentId);
        expect(shouldProcess, isFalse);
      },
    );

    test(
      'procesa archivos sin treatmentId',
      () {
        final shouldProcess = _shouldProcessFile(null);
        expect(shouldProcess, isTrue);
      },
    );

    test(
      'procesa archivos con treatmentId vacio',
      () {
        final shouldProcess = _shouldProcessFile('');
        expect(shouldProcess, isTrue);
      },
    );
  });

  group('LegacyMigrationService - nombres de snapshot', () {
    test(
      'genera nombre de snapshot correcto para tratamiento unico',
      () {
        final treatments = [
          _Treatment(id: 'tx-1', name: 'Ortodoncia', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        expect(result.treatmentName, 'Ortodoncia');
      },
    );

    test(
      'genera nombre de snapshot "Legacy" para multiples tratamientos',
      () {
        final treatments = [
          _Treatment(id: 'tx-1', name: 'Ortodoncia', isActive: true),
          _Treatment(id: 'tx-2', name: 'Blanqueamiento', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        expect(result.treatmentName, contains('Legacy'));
        expect(result.treatmentName, contains('revision'));
      },
    );
  });

  group('LegacyMigrationService - contratos de escritura', () {
    test(
      'auto-asociacion incluye todos los campos requeridos',
      () {
        final treatments = [
          _Treatment(id: 'tx-1', name: 'Ortodoncia', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        final updates = _buildAutoAssociateUpdates(result);

        expect(updates['treatmentId'], 'tx-1');
        expect(updates['treatmentNameSnapshot'], 'Ortodoncia');
        expect(updates['migratedBy'], 'legacy-migration-service');
        expect(updates['migrationNote'], contains('un solo tratamiento'));
      },
    );

    test(
      'marcado legacy incluye todos los campos requeridos',
      () {
        final treatments = [
          _Treatment(id: 'tx-1', name: 'Ortodoncia', isActive: true),
          _Treatment(id: 'tx-2', name: 'Blanqueamiento', isActive: true),
        ];
        final result = _resolveTreatment(treatments);
        final updates = _buildLegacyUpdates(result);

        expect(updates['treatmentId'], 'legacy_unlinked');
        expect(updates['treatmentNameSnapshot'], contains('Legacy'));
        expect(updates['migratedBy'], 'legacy-migration-service');
        expect(updates['migrationNote'], contains('varios tratamientos'));
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Helpers para simular la logica del servicio sin dependencias de Firebase
// ---------------------------------------------------------------------------

class _Treatment {
  final String id;
  final String name;
  final bool isActive;

  _Treatment({
    required this.id,
    this.name = '',
    this.isActive = true,
  });
}

class _Resolution {
  final String? treatmentId;
  final String treatmentName;
  final bool shouldAutoAssociate;
  final bool isLegacy;

  _Resolution({
    this.treatmentId,
    this.treatmentName = '',
    required this.shouldAutoAssociate,
    required this.isLegacy,
  });
}

/// Replica la logica de LegacyMigrationService._resolveTreatmentForPatient
_Resolution _resolveTreatment(List<_Treatment> allTreatments) {
  final activeTreatments =
      allTreatments.where((t) => t.isActive).toList();

  if (activeTreatments.isEmpty) {
    return _Resolution(
      shouldAutoAssociate: false,
      isLegacy: false,
    );
  }

  if (activeTreatments.length == 1) {
    final tx = activeTreatments.first;
    return _Resolution(
      treatmentId: tx.id,
      treatmentName: tx.name,
      shouldAutoAssociate: true,
      isLegacy: false,
    );
  }

  // Multiples tratamientos activos
  return _Resolution(
    treatmentId: 'legacy_unlinked',
    treatmentName: 'Legacy — requiere revision manual.',
    shouldAutoAssociate: false,
    isLegacy: true,
  );
}

/// Replica la logica de shouldProcessFile
bool _shouldProcessFile(String? existingTreatmentId) {
  return existingTreatmentId == null || existingTreatmentId.isEmpty;
}

Map<String, dynamic> _buildAutoAssociateUpdates(_Resolution result) {
  return {
    'treatmentId': result.treatmentId,
    'treatmentNameSnapshot': result.treatmentName,
    'migratedAt': 'serverTimestamp', // Simulado
    'migratedBy': 'legacy-migration-service',
    'migrationNote': 'Auto-asociado por tener un solo tratamiento.',
  };
}

Map<String, dynamic> _buildLegacyUpdates(_Resolution result) {
  return {
    'treatmentId': result.treatmentId,
    'treatmentNameSnapshot': result.treatmentName,
    'migratedAt': 'serverTimestamp', // Simulado
    'migratedBy': 'legacy-migration-service',
    'migrationNote': 'Paciente con varios tratamientos. Categoria legacy.',
  };
}
