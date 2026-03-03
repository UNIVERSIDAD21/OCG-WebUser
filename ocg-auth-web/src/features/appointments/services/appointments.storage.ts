import { localStorageService } from '../../../shared/storage/localStorage.service';
import type { AppUser } from '../../../services/auth.service';
import type { Appointment } from '../types/appointment.types';

export const APPOINTMENTS_KEY = 'ocg_appointments';
export const USERS_KEY = 'ocg_users';

const defaultUsers: AppUser[] = [
  {
    uid: 'admin-seed-1',
    email: 'admin@ocg.com',
    displayName: 'Admin OCG',
    role: 'admin',
    status: 'active',
    createdAt: new Date().toISOString(),
  },
  {
    uid: 'patient-seed-1',
    email: 'paciente1@ocg.com',
    displayName: 'Paciente Uno',
    role: 'patient',
    status: 'active',
    createdAt: new Date().toISOString(),
  },
  {
    uid: 'patient-seed-2',
    email: 'paciente2@ocg.com',
    displayName: 'Paciente Dos',
    role: 'patient',
    status: 'active',
    createdAt: new Date().toISOString(),
  },
];

const seedAppointments: Appointment[] = [
  {
    id: 'apt-seed-1',
    patientId: 'patient-seed-1',
    patientName: 'Paciente Uno',
    patientEmail: 'paciente1@ocg.com',
    serviceType: 'brackets',
    reason: 'Control inicial de brackets y ajuste de arco.',
    appointmentDate: '2026-03-01',
    startTime: '09:00',
    endTime: '09:30',
    status: 'requested',
    priority: 'normal',
    createdBy: 'patient-seed-1',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    reminderStatus: 'pending',
    treatmentSessionId: null,
  },
  {
    id: 'apt-seed-2',
    patientId: 'patient-seed-2',
    patientName: 'Paciente Dos',
    patientEmail: 'paciente2@ocg.com',
    serviceType: 'ortodoncia',
    reason: 'Dolor en pieza dental y revisión prioritaria.',
    appointmentDate: '2026-03-02',
    startTime: '11:00',
    endTime: '11:40',
    status: 'pending_priority_review',
    priority: 'high',
    priorityReason: 'Dolor intenso desde anoche',
    createdBy: 'patient-seed-2',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    reminderStatus: 'pending',
    treatmentSessionId: null,
  },
  {
    id: 'apt-seed-3',
    patientId: 'patient-seed-1',
    patientName: 'Paciente Uno',
    patientEmail: 'paciente1@ocg.com',
    serviceType: 'diseno_sonrisa',
    reason: 'Seguimiento de diseño de sonrisa y revisión fotográfica.',
    appointmentDate: '2026-02-20',
    startTime: '15:00',
    endTime: '15:30',
    status: 'completed',
    priority: 'normal',
    createdBy: 'patient-seed-1',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    reminderStatus: 'sent',
    treatmentSessionId: 'trt-seed-001',
  },
];

export const appointmentsStorage = {
  getUsers() {
    return localStorageService.get<AppUser[]>(USERS_KEY, []);
  },
  saveUsers(users: AppUser[]) {
    localStorageService.set(USERS_KEY, users);
  },
  getAppointments() {
    return localStorageService.get<Appointment[]>(APPOINTMENTS_KEY, []);
  },
  saveAppointments(appointments: Appointment[]) {
    localStorageService.set(APPOINTMENTS_KEY, appointments);
  },
  seedIfEmpty() {
    const users = this.getUsers();
    const userMap = new Map(users.map((u) => [u.email.toLowerCase(), u]));
    for (const seedUser of defaultUsers) {
      if (!userMap.has(seedUser.email.toLowerCase())) {
        users.push(seedUser);
      }
    }
    this.saveUsers(users);

    const appointments = this.getAppointments();
    if (!appointments.length) this.saveAppointments(seedAppointments);
  },
};
