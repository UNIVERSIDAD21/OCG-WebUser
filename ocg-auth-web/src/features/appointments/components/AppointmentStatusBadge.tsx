import { appointmentStatusLabel } from '../utils/appointment.mappers';
import type { AppointmentStatus } from '../types/appointment.types';

const classes: Record<AppointmentStatus, string> = {
  requested: 'bg-sky-500/20 text-sky-200 border-sky-500/40',
  pending_priority_review: 'bg-amber-500/20 text-amber-200 border-amber-500/40',
  confirmed: 'bg-emerald-500/20 text-emerald-200 border-emerald-500/40',
  rescheduled: 'bg-violet-500/20 text-violet-200 border-violet-500/40',
  cancelled_by_patient: 'bg-rose-500/20 text-rose-200 border-rose-500/40',
  cancelled_by_admin: 'bg-rose-500/20 text-rose-200 border-rose-500/40',
  completed: 'bg-teal-500/20 text-teal-200 border-teal-500/40',
  no_show: 'bg-slate-500/20 text-slate-200 border-slate-500/40',
};

export default function AppointmentStatusBadge({ status }: { status: AppointmentStatus }) {
  return (
    <span className={`inline-flex rounded-full border px-2.5 py-1 text-xs font-semibold ${classes[status]}`}>
      {appointmentStatusLabel[status]}
    </span>
  );
}
