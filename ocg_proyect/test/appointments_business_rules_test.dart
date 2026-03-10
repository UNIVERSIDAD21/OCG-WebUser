import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/appointments/domain/appointments_business_rules.dart';

void main() {
  group('AppointmentsBusinessRules', () {
    test('Tipos permitidos por rol paciente: solo valoracion y control', () {
      expect(
        AppointmentsBusinessRules.patientAllowedTypes,
        containsAll([AppointmentType.valoracion, AppointmentType.control]),
      );
      expect(
        AppointmentsBusinessRules.patientAllowedTypes,
        isNot(contains(AppointmentType.urgencia)),
      );
      expect(
        AppointmentsBusinessRules.patientAllowedTypes,
        isNot(contains(AppointmentType.instalacion)),
      );
      expect(
        AppointmentsBusinessRules.patientAllowedTypes,
        isNot(contains(AppointmentType.alta)),
      );
    });

    test('Validación: no dos citas el mismo día', () {
      final citasExistentes = [
        AppointmentModel(
          id: 'a1',
          patientId: 'p1',
          patientName: 'Paciente 1',
          tipo: AppointmentType.valoracion,
          estado: AppointmentStatus.programada,
          fechaHora: DateTime(2026, 4, 15, 10, 0),
          duracionMinutos: 30,
        ),
      ];

      final error = AppointmentsBusinessRules.validateNoSameDayAppointment(
        existingAppointments: citasExistentes,
        newAppointmentDateTime: DateTime(2026, 4, 15, 16, 0),
      );

      expect(error, contains('Ya tienes una cita ese día'));
    });

    test('Regla de cancelación: >= 24h permite cancelar', () {
      final now = DateTime(2026, 4, 10, 10, 0);
      final fechaCita = now.add(const Duration(hours: 48));

      final puedeCancelar = AppointmentsBusinessRules.canCancelAppointment(
        fechaCita,
        now: now,
      );

      expect(puedeCancelar, isTrue);
    });

    test('Regla de cancelación: < 24h no permite cancelar', () {
      final now = DateTime(2026, 4, 10, 10, 0);
      final fechaCita = now.add(const Duration(hours: 10));

      final puedeCancelar = AppointmentsBusinessRules.canCancelAppointment(
        fechaCita,
        now: now,
      );

      expect(puedeCancelar, isFalse);
    });
  });

  group('AppointmentModel', () {
    test('serialización round-trip conserva todos los campos', () {
      final model = AppointmentModel(
        id: 'appt-1',
        patientId: 'patient-1',
        patientName: 'Paciente Prueba',
        tipo: AppointmentType.control,
        estado: AppointmentStatus.confirmada,
        fechaHora: DateTime(2026, 5, 1, 9, 30),
        duracionMinutos: 45,
        notas: 'Traer radiografías',
        createdAt: DateTime(2026, 4, 1, 8, 0),
        updatedAt: DateTime(2026, 4, 2, 8, 30),
      );

      final json = model.toJson();
      final roundTrip = AppointmentModel.fromJson({
        ...json,
        'fechaHora': (json['fechaHora'] as Timestamp).toDate().toIso8601String(),
        'createdAt': (json['createdAt'] as Timestamp).toDate().toIso8601String(),
        'updatedAt': model.updatedAt!.toIso8601String(),
      });

      expect(roundTrip.id, equals(model.id));
      expect(roundTrip.patientId, equals(model.patientId));
      expect(roundTrip.patientName, equals(model.patientName));
      expect(roundTrip.tipo, equals(model.tipo));
      expect(roundTrip.estado, equals(model.estado));
      expect(roundTrip.fechaHora, equals(model.fechaHora));
      expect(roundTrip.duracionMinutos, equals(model.duracionMinutos));
      expect(roundTrip.notas, equals(model.notas));
      expect(roundTrip.createdAt, equals(model.createdAt));
      expect(roundTrip.updatedAt, equals(model.updatedAt));
    });
  });
}
