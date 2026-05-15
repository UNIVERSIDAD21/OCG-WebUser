import '../../appointments/data/models/appointment_model.dart';
import '../../treatment/data/models/patient_treatment.dart';

enum ConsultationTreatmentResolutionSource {
  appointment,
  primary,
  firstAvailable,
  none,
}

class ConsultationTreatmentResolution {
  const ConsultationTreatmentResolution({
    required this.treatment,
    required this.source,
    required this.appointmentTreatmentId,
  });

  final PatientTreatment? treatment;
  final ConsultationTreatmentResolutionSource source;
  final String? appointmentTreatmentId;

  bool get cameFromAppointment =>
      source == ConsultationTreatmentResolutionSource.appointment;

  bool get appointmentTreatmentWasMissing =>
      appointmentTreatmentId != null &&
      appointmentTreatmentId!.isNotEmpty &&
      source != ConsultationTreatmentResolutionSource.appointment;
}

class ConsultationTreatmentResolver {
  const ConsultationTreatmentResolver();

  ConsultationTreatmentResolution resolve({
    required AppointmentModel appointment,
    required List<PatientTreatment> treatments,
  }) {
    final appointmentTreatmentId = appointment.treatmentId?.trim();
    if (appointmentTreatmentId != null && appointmentTreatmentId.isNotEmpty) {
      for (final treatment in treatments) {
        if (treatment.id == appointmentTreatmentId) {
          return ConsultationTreatmentResolution(
            treatment: treatment,
            source: ConsultationTreatmentResolutionSource.appointment,
            appointmentTreatmentId: appointmentTreatmentId,
          );
        }
      }
    }

    for (final treatment in treatments) {
      if (treatment.isPrimary) {
        return ConsultationTreatmentResolution(
          treatment: treatment,
          source: ConsultationTreatmentResolutionSource.primary,
          appointmentTreatmentId: appointmentTreatmentId,
        );
      }
    }

    if (treatments.isNotEmpty) {
      return ConsultationTreatmentResolution(
        treatment: treatments.first,
        source: ConsultationTreatmentResolutionSource.firstAvailable,
        appointmentTreatmentId: appointmentTreatmentId,
      );
    }

    return ConsultationTreatmentResolution(
      treatment: null,
      source: ConsultationTreatmentResolutionSource.none,
      appointmentTreatmentId: appointmentTreatmentId,
    );
  }
}
