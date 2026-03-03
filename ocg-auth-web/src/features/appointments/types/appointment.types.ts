export type AppointmentServiceType = 'brackets' | 'diseno_sonrisa' | 'ortodoncia';

export type AppointmentStatus =
  | 'requested'
  | 'pending_priority_review'
  | 'confirmed'
  | 'rescheduled'
  | 'cancelled_by_patient'
  | 'cancelled_by_admin'
  | 'completed'
  | 'no_show';

export type AppointmentPriority = 'normal' | 'high';

export type ReminderStatus = 'pending' | 'sent' | 'failed';

export type Appointment = {
  id: string;
  patientId: string;
  patientName: string;
  patientEmail: string;
  serviceType: AppointmentServiceType;
  reason: string;
  appointmentDate: string;
  startTime: string;
  endTime: string;
  status: AppointmentStatus;
  priority: AppointmentPriority;
  priorityReason?: string;
  notesPatient?: string;
  notesAdmin?: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  assignedTo?: string;
  reminderStatus?: ReminderStatus;
  treatmentSessionId?: string | null;
};

export type AppointmentFilters = {
  status?: AppointmentStatus | 'all';
  priority?: AppointmentPriority | 'all';
  date?: string;
};
