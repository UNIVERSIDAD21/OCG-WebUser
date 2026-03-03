import type { AppointmentStatus } from '../types/appointment.types';

export const appointmentStatusLabel: Record<AppointmentStatus, string> = {
  requested: 'Solicitada',
  pending_priority_review: 'En revisión prioritaria',
  confirmed: 'Confirmada',
  rescheduled: 'Reprogramada',
  cancelled_by_patient: 'Cancelada por paciente',
  cancelled_by_admin: 'Cancelada por administración',
  completed: 'Completada',
  no_show: 'No asistió',
};

export const serviceTypeLabel = {
  brackets: 'Brackets',
  diseno_sonrisa: 'Diseño de sonrisa',
  ortodoncia: 'Ortodoncia / corrección dental',
} as const;
