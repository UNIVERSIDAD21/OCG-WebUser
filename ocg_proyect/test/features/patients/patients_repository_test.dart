import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/repositories/patients_repository.dart';

void main() {
  group('PatientsRepository', () {
    test(
      'watchAllPatients includes legacy docs without nombre field',
      () async {
        final db = FakeFirebaseFirestore();
        final repo = PatientsRepository(db);

        await db.collection('patients').doc('p-with-name').set({
          'id': 'p-with-name',
          'nombre': 'Ana Paciente',
          'email': 'ana@example.com',
        });
        await db.collection('patients').doc('p-legacy').set({
          'email': 'legacy@example.com',
        });
        await db.collection('patients').doc('admin-doc').set({
          'email': 'admin@ocg.com',
        });

        final patients = await repo.watchAllPatients().first;

        expect(patients.map((patient) => patient.id), contains('p-with-name'));
        expect(patients.map((patient) => patient.id), contains('p-legacy'));
        expect(
          patients.map((patient) => patient.email),
          isNot(contains('admin@ocg.com')),
        );
        expect(
          patients.firstWhere((patient) => patient.id == 'p-legacy').nombre,
          'legacy@example.com',
        );
      },
    );
  });
}
