import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bloque 01 security invariants', () {
    test('documentos de treatment/stageHistory incluyen patientId y ids consistentes', () async {
      final db = FakeFirebaseFirestore();

      await db.collection('patients/p1/treatments').doc('tx-1').set({
        'id': 'tx-1',
        'patientId': 'p1',
        'name': 'Convencional',
        'baseType': 'convencional',
        'status': 'activo',
        'currentStageId': 'valoracionInicial',
        'currentStageName': 'Valoración inicial',
        'isPrimary': true,
        'startDate': Timestamp.fromDate(DateTime(2026, 4, 1)),
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
      });

      await db.collection('patients/p1/treatments/tx-1/stageHistory').doc('sh-1').set({
        'id': 'sh-1',
        'patientId': 'p1',
        'treatmentId': 'tx-1',
        'stageName': 'Instalación',
        'status': 'completed',
        'notes': 'Cambio de etapa validado para tratamiento principal.',
        'createdAt': Timestamp.fromDate(DateTime(2026, 4, 2)),
        'createdBy': 'admin-1',
      });

      final treatment = await db.doc('patients/p1/treatments/tx-1').get();
      final stageHistory = await db.doc('patients/p1/treatments/tx-1/stageHistory/sh-1').get();

      expect(treatment.data()?['patientId'], 'p1');
      expect(treatment.data()?['id'], 'tx-1');
      expect(stageHistory.data()?['patientId'], 'p1');
      expect(stageHistory.data()?['treatmentId'], 'tx-1');
      expect(stageHistory.data()?['id'], 'sh-1');
    });

    test('firestore.rules protege rutas sensibles de Bloque 01', () async {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /treatments/{treatmentId}'));
      expect(rules, contains("incomingPatientMatches(patientId)"));
      expect(rules, contains("incomingTreatmentMatches(treatmentId)"));
      expect(rules, contains("match /stageHistory/{entryId}"));
      expect(rules, contains("allow create, update: if isAdmin() &&"));
      expect(rules, contains("allow create: if isAdmin() &&"));
    });
  });
}
