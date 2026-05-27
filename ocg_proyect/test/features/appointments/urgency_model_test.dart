import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/urgency_model.dart';

void main() {
  group('UrgencyRequestModel', () {
    test('serializa y deserializa correctamente', () {
      final now = DateTime(2026, 5, 27, 14, 30);
      final request = UrgencyRequestModel(
        id: 'urg-1',
        patientId: 'patient-1',
        patientName: 'Carlos Pérez',
        patientPhone: '3001234567',
        descripcion: 'Dolor severo en muela del juicio, inflamación en mejilla',
        estado: UrgencyStatus.pendiente,
        createdAt: now,
      );

      final json = request.toJson();

      expect(json['id'], 'urg-1');
      expect(json['patientId'], 'patient-1');
      expect(json['patientName'], 'Carlos Pérez');
      expect(json['patientPhone'], '3001234567');
      expect(json['descripcion'], 'Dolor severo en muela del juicio, inflamación en mejilla');
      expect(json['estado'], 'pendiente');
      expect(json['appointmentId'], isNull);
      expect(json['reprogramadaFromId'], isNull);
      expect(json['adminNotes'], isNull);
    });

    test('deserializa urgencia con campos opcionales', () {
      final now = DateTime(2026, 5, 27, 14, 30);
      final json = <String, dynamic>{
        'id': 'urg-2',
        'patientId': 'patient-2',
        'patientName': 'María López',
        'patientPhone': '3109876543',
        'descripcion': 'Sangrado post-extracción que no para',
        'estado': 'enProceso',
        'createdAt': now,
        'updatedAt': now.add(const Duration(minutes: 15)),
        'appointmentId': 'appt-urg-001',
        'reprogramadaFromId': 'appt-normal-042',
        'adminNotes': 'Se le asignó slot de las 16:00 reprogramando a Juan',
      };

      final restored = UrgencyRequestModel.fromJson(json);

      expect(restored.id, 'urg-2');
      expect(restored.patientId, 'patient-2');
      expect(restored.estado, UrgencyStatus.enProceso);
      expect(restored.appointmentId, 'appt-urg-001');
      expect(restored.reprogramadaFromId, 'appt-normal-042');
      expect(restored.adminNotes, 'Se le asignó slot de las 16:00 reprogramando a Juan');
    });

    test('tolera estados desconocidos y los mapea a pendiente', () {
      final now = DateTime.now();
      final restored = UrgencyRequestModel.fromJson({
        'id': 'urg-3',
        'patientId': 'p3',
        'patientName': 'Test',
        'patientPhone': '000',
        'descripcion': 'algo',
        'estado': 'estadoInexistente',
        'createdAt': now,
      });

      expect(restored.estado, UrgencyStatus.pendiente);
    });

    test('tolera campos null y missing', () {
      final now = DateTime.now();
      final restored = UrgencyRequestModel.fromJson({
        'id': 'urg-4',
        'patientId': 'p4',
        'patientName': 'Test Null',
        'descripcion': 'algo',
        'createdAt': now,
      });

      expect(restored.patientPhone, isEmpty);
      expect(restored.estado, UrgencyStatus.pendiente);
      expect(restored.appointmentId, isNull);
      expect(restored.reprogramadaFromId, isNull);
      expect(restored.adminNotes, isNull);
    });

    test('copyWith modifica solo los campos indicados', () {
      final now = DateTime.now();
      final original = UrgencyRequestModel(
        id: 'urg-5',
        patientId: 'p5',
        patientName: 'Original',
        patientPhone: '111',
        descripcion: 'Dolor',
        estado: UrgencyStatus.pendiente,
        createdAt: now,
      );

      final updated = original.copyWith(
        estado: UrgencyStatus.atendida,
        appointmentId: 'appt-100',
        adminNotes: 'Atendido por WhatsApp',
      );

      expect(updated.estado, UrgencyStatus.atendida);
      expect(updated.appointmentId, 'appt-100');
      expect(updated.adminNotes, 'Atendido por WhatsApp');
      // Los campos no modificados se mantienen
      expect(updated.id, 'urg-5');
      expect(updated.patientName, 'Original');
      expect(updated.descripcion, 'Dolor');
    });

    test('isActive es true para pendiente y enProceso', () {
      final now = DateTime.now();
      final pendiente = UrgencyRequestModel(
        id: '1', patientId: 'p', patientName: 'N', patientPhone: '0',
        descripcion: 'x', estado: UrgencyStatus.pendiente, createdAt: now,
      );
      final enProceso = UrgencyRequestModel(
        id: '2', patientId: 'p', patientName: 'N', patientPhone: '0',
        descripcion: 'x', estado: UrgencyStatus.enProceso, createdAt: now,
      );
      final atendida = UrgencyRequestModel(
        id: '3', patientId: 'p', patientName: 'N', patientPhone: '0',
        descripcion: 'x', estado: UrgencyStatus.atendida, createdAt: now,
      );

      expect(pendiente.isActive, isTrue);
      expect(enProceso.isActive, isTrue);
      expect(atendida.isActive, isFalse);
    });

    test('estadoLabel devuelve etiquetas correctas', () {
      final now = DateTime.now();
      expect(
        UrgencyRequestModel(
          id: '1', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.pendiente, createdAt: now,
        ).estadoLabel,
        '⏳ Pendiente',
      );
      expect(
        UrgencyRequestModel(
          id: '2', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.enProceso, createdAt: now,
        ).estadoLabel,
        '🔄 En proceso',
      );
      expect(
        UrgencyRequestModel(
          id: '3', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.atendida, createdAt: now,
        ).estadoLabel,
        '✅ Atendida',
      );
      expect(
        UrgencyRequestModel(
          id: '4', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.reprogramada, createdAt: now,
        ).estadoLabel,
        '📅 Reprogramada',
      );
      expect(
        UrgencyRequestModel(
          id: '5', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.rechazada, createdAt: now,
        ).estadoLabel,
        '❌ Rechazada',
      );
    });

    test('statusColorHex devuelve colores semánticos', () {
      final now = DateTime.now();
      expect(
        UrgencyRequestModel(
          id: '1', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.pendiente, createdAt: now,
        ).statusColorHex,
        '#EF4444',
      );
      expect(
        UrgencyRequestModel(
          id: '2', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.enProceso, createdAt: now,
        ).statusColorHex,
        '#F59E0B',
      );
      expect(
        UrgencyRequestModel(
          id: '3', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.atendida, createdAt: now,
        ).statusColorHex,
        '#10B981',
      );
      expect(
        UrgencyRequestModel(
          id: '4', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.reprogramada, createdAt: now,
        ).statusColorHex,
        '#6366F1',
      );
      expect(
        UrgencyRequestModel(
          id: '5', patientId: 'p', patientName: 'N', patientPhone: '0',
          descripcion: 'x', estado: UrgencyStatus.rechazada, createdAt: now,
        ).statusColorHex,
        '#6B7280',
      );
    });

    test('toJson incluye appointmentId y reprogramadaFromId cuando existen', () {
      final now = DateTime.now();
      final request = UrgencyRequestModel(
        id: 'urg-6',
        patientId: 'p6',
        patientName: 'Ana',
        patientPhone: '222',
        descripcion: 'Dolor post-operatorio',
        estado: UrgencyStatus.reprogramada,
        createdAt: now,
        appointmentId: 'appt-nuevo',
        reprogramadaFromId: 'appt-viejo',
        adminNotes: 'Reprogramado exitosamente',
      );

      final json = request.toJson();
      expect(json['appointmentId'], 'appt-nuevo');
      expect(json['reprogramadaFromId'], 'appt-viejo');
      expect(json['adminNotes'], 'Reprogramado exitosamente');
      expect(json['estado'], 'reprogramada');
    });
  });
}
