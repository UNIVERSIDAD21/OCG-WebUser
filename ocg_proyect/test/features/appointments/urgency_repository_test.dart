import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/appointments/data/models/appointment_model.dart';
import 'package:ocg_proyect/features/appointments/data/models/urgency_model.dart';
import 'package:ocg_proyect/features/appointments/data/repositories/urgency_repository.dart';

void main() {
  group('UrgencyRepository admin actions', () {
    late FakeFirebaseFirestore db;
    late UrgencyRepository repo;

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = UrgencyRepository(db);
    });

    UrgencyRequestModel request({
      String id = 'urg-1',
      String patientId = 'urgent-patient',
    }) {
      return UrgencyRequestModel(
        id: id,
        patientId: patientId,
        patientName: 'Paciente Urgente',
        patientPhone: '3001234567',
        descripcion: 'Dolor fuerte por aparatologia.',
        estado: UrgencyStatus.pendiente,
        createdAt: DateTime(2030, 1, 1, 8),
      );
    }

    AppointmentModel appointment({
      String id = '',
      String patientId = 'urgent-patient',
      AppointmentType type = AppointmentType.urgencia,
      AppointmentStatus status = AppointmentStatus.programada,
      DateTime? start,
    }) {
      return AppointmentModel(
        id: id,
        patientId: patientId,
        patientName: patientId == 'urgent-patient'
            ? 'Paciente Urgente'
            : 'Paciente Normal',
        patientPhone: patientId == 'urgent-patient' ? '3001234567' : '3100000',
        tipo: type,
        estado: status,
        fechaHora: start ?? DateTime(2030, 1, 2, 10),
        duracionMinutos: 30,
        creadoPor: 'admin-1',
      );
    }

    test('crear cita de urgencia no falla si falta doc del paciente', () async {
      final urgency = request();
      await db
          .collection('urgencyRequests')
          .doc(urgency.id)
          .set(urgency.toJson());

      final appointmentId = await repo.createAppointmentFromUrgency(
        request: urgency,
        appointment: appointment(),
        adminId: 'admin-1',
      );

      final appointmentDoc = await db
          .collection('appointments')
          .doc(appointmentId)
          .get();
      final requestDoc = await db
          .collection('urgencyRequests')
          .doc(urgency.id)
          .get();
      final patientDoc = await db
          .collection('patients')
          .doc(urgency.patientId)
          .get();

      expect(appointmentDoc.exists, isTrue);
      expect(appointmentDoc.data()?['tipo'], AppointmentType.urgencia.name);
      expect(requestDoc.data()?['estado'], UrgencyStatus.atendida.name);
      expect(requestDoc.data()?['appointmentId'], appointmentId);
      expect(patientDoc.exists, isTrue);
      expect(patientDoc.data()?['proximaCita'], isA<Timestamp>());
    });

    test(
      'reprogramar para urgencia crea ambas citas aunque falten pacientes',
      () async {
        final urgency = request();
        final original = appointment(
          id: 'normal-appt',
          patientId: 'normal-patient',
          type: AppointmentType.control,
          start: DateTime(2030, 1, 3, 9),
        );
        final newDateTimeForOriginal = DateTime(2030, 1, 10, 9);

        await db
            .collection('urgencyRequests')
            .doc(urgency.id)
            .set(urgency.toJson());
        await db
            .collection('appointments')
            .doc(original.id)
            .set(original.toJson());

        final result = await repo.rescheduleAppointmentForUrgency(
          request: urgency,
          originalAppointment: original,
          newDateTimeForOriginal: newDateTimeForOriginal,
          adminId: 'admin-1',
        );

        final originalDoc = await db
            .collection('appointments')
            .doc(original.id)
            .get();
        final movedDoc = await db
            .collection('appointments')
            .doc(result.movedAppointmentId)
            .get();
        final urgentDoc = await db
            .collection('appointments')
            .doc(result.urgentAppointmentId)
            .get();
        final urgencyDoc = await db
            .collection('urgencyRequests')
            .doc(urgency.id)
            .get();

        expect(
          originalDoc.data()?['estado'],
          AppointmentStatus.reprogramada.name,
        );
        expect(movedDoc.exists, isTrue);
        expect(movedDoc.data()?['patientId'], original.patientId);
        expect(urgentDoc.exists, isTrue);
        expect(urgentDoc.data()?['patientId'], urgency.patientId);
        expect(urgentDoc.data()?['tipo'], AppointmentType.urgencia.name);
        expect(urgencyDoc.data()?['appointmentId'], result.urgentAppointmentId);
        expect(urgencyDoc.data()?['reprogramadaFromId'], original.id);
        expect(
          (await db.collection('patients').doc(original.patientId).get())
              .exists,
          isTrue,
        );
        expect(
          (await db.collection('patients').doc(urgency.patientId).get()).exists,
          isTrue,
        );
      },
    );
  });
}
