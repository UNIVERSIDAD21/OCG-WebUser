import type { AppUser } from '../../../services/auth.service';
import { appointmentsStorage } from './appointments.storage';
import type {
  Appointment,
  AppointmentFilters,
  AppointmentPriority,
  AppointmentStatus,
} from '../types/appointment.types';

export type CreateAppointmentPayload = {
  serviceType: Appointment['serviceType'];
  reason: string;
  appointmentDate: string;
  slotTime: string;
  priority?: AppointmentPriority;
  priorityReason?: string;
  notesPatient?: string;
};

const closedStatuses: AppointmentStatus[] = ['cancelled_by_patient', 'cancelled_by_admin', 'completed', 'no_show'];
const blockingStatuses: AppointmentStatus[] = ['requested', 'pending_priority_review', 'confirmed', 'rescheduled'];
const doctorSlots = ['08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30'];

const addMinutesToTime = (time: string, minutes: number) => {
  const [h, m] = time.split(':').map(Number);
  const total = h * 60 + m + minutes;
  const nh = String(Math.floor(total / 60)).padStart(2, '0');
  const nm = String(total % 60).padStart(2, '0');
  return `${nh}:${nm}`;
};

const sortByDateTime = (a: Appointment, b: Appointment) => {
  const aDate = new Date(`${a.appointmentDate}T${a.startTime}:00`).getTime();
  const bDate = new Date(`${b.appointmentDate}T${b.startTime}:00`).getTime();
  return aDate - bDate;
};

export const seedAppointmentsIfEmpty = () => appointmentsStorage.seedIfEmpty();

export const getAppointmentsByPatient = (patientId: string) => {
  seedAppointmentsIfEmpty();
  return appointmentsStorage
    .getAppointments()
    .filter((appointment) => appointment.patientId === patientId)
    .sort(sortByDateTime);
};

export const getAllAppointments = (filters?: AppointmentFilters) => {
  seedAppointmentsIfEmpty();
  return appointmentsStorage
    .getAppointments()
    .filter((appointment) => {
      if (filters?.status && filters.status !== 'all' && appointment.status !== filters.status) return false;
      if (filters?.priority && filters.priority !== 'all' && appointment.priority !== filters.priority) return false;
      if (filters?.date && appointment.appointmentDate !== filters.date) return false;
      return true;
    })
    .sort(sortByDateTime);
};

export const getNextAppointmentForPatient = (patientId: string) => {
  const now = Date.now();
  return getAppointmentsByPatient(patientId)
    .filter((appointment) => !closedStatuses.includes(appointment.status))
    .find((appointment) => new Date(`${appointment.appointmentDate}T${appointment.startTime}:00`).getTime() >= now) ?? null;
};

export const getAvailableSlotsByDate = (date: string) => {
  seedAppointmentsIfEmpty();
  if (!date) return [];
  const taken = new Set(
    appointmentsStorage
      .getAppointments()
      .filter((appointment) => appointment.appointmentDate === date && blockingStatuses.includes(appointment.status))
      .map((appointment) => appointment.startTime),
  );
  return doctorSlots.filter((slot) => !taken.has(slot));
};

export const createAppointment = (payload: CreateAppointmentPayload, currentUser: AppUser) => {
  if (currentUser.role !== 'patient') throw new Error('Solo pacientes pueden solicitar citas.');

  const appointments = appointmentsStorage.getAppointments();
  const now = new Date().toISOString();
  const priority = payload.priority ?? 'normal';

  const availableSlots = getAvailableSlotsByDate(payload.appointmentDate);
  if (!availableSlots.includes(payload.slotTime)) {
    throw new Error('El horario seleccionado ya no está disponible.');
  }

  const appointment: Appointment = {
    id: crypto.randomUUID(),
    patientId: currentUser.uid,
    patientName: currentUser.displayName || currentUser.email.split('@')[0],
    patientEmail: currentUser.email,
    serviceType: payload.serviceType,
    reason: payload.reason,
    appointmentDate: payload.appointmentDate,
    startTime: payload.slotTime,
    endTime: addMinutesToTime(payload.slotTime, 30),
    status: priority === 'high' ? 'pending_priority_review' : 'requested',
    priority,
    priorityReason: payload.priorityReason,
    notesPatient: payload.notesPatient,
    notesAdmin: '',
    createdBy: currentUser.uid,
    createdAt: now,
    updatedAt: now,
    assignedTo: undefined,
    reminderStatus: 'pending',
    treatmentSessionId: null,
  };

  appointmentsStorage.saveAppointments([...appointments, appointment]);
  return appointment;
};

export const updateAppointmentStatus = (
  appointmentId: string,
  status: AppointmentStatus,
  actor: AppUser,
  notesAdmin?: string,
) => {
  if (actor.role !== 'admin') throw new Error('Solo administración puede cambiar este estado.');

  const appointments = appointmentsStorage.getAppointments();
  const found = appointments.find((appointment) => appointment.id === appointmentId);
  if (!found) throw new Error('Cita no encontrada.');

  if (closedStatuses.includes(found.status)) throw new Error('No se puede modificar una cita cerrada.');

  const updated = appointments.map((appointment) =>
    appointment.id === appointmentId
      ? {
          ...appointment,
          status,
          notesAdmin: notesAdmin ?? appointment.notesAdmin,
          updatedAt: new Date().toISOString(),
          assignedTo: actor.uid,
        }
      : appointment,
  );

  appointmentsStorage.saveAppointments(updated);
};

export const cancelAppointmentByPatient = (appointmentId: string, patientId: string) => {
  const appointments = appointmentsStorage.getAppointments();
  const found = appointments.find((appointment) => appointment.id === appointmentId);

  if (!found) throw new Error('Cita no encontrada.');
  if (found.patientId !== patientId) throw new Error('Solo puedes cancelar tus citas.');
  if (closedStatuses.includes(found.status)) throw new Error('La cita ya está cerrada.');

  const updated = appointments.map((appointment) =>
    appointment.id === appointmentId
      ? {
          ...appointment,
          status: 'cancelled_by_patient' as const,
          updatedAt: new Date().toISOString(),
        }
      : appointment,
  );

  appointmentsStorage.saveAppointments(updated);
};
