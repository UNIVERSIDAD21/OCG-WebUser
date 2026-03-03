import type { ReactNode } from 'react';
import type { Appointment } from '../types/appointment.types';
import AppointmentStatusBadge from './AppointmentStatusBadge';
import { serviceTypeLabel } from '../utils/appointment.mappers';

type Props = {
  appointment: Appointment;
  actions?: ReactNode;
};

export default function AppointmentCard({ appointment, actions }: Props) {
  return (
    <article className='rounded-2xl border border-slate-800 bg-slate-900 p-4'>
      <div className='flex flex-wrap items-start justify-between gap-2'>
        <div>
          <p className='text-sm text-slate-300'>{serviceTypeLabel[appointment.serviceType]}</p>
          <h3 className='text-base font-semibold'>{appointment.patientName}</h3>
        </div>
        <AppointmentStatusBadge status={appointment.status} />
      </div>
      <p className='mt-2 text-sm text-slate-300'>
        {appointment.appointmentDate} · {appointment.startTime} - {appointment.endTime}
      </p>
      <p className='mt-2 text-sm text-slate-300'>{appointment.reason}</p>
      {appointment.priority === 'high' ? (
        <p className='mt-2 text-xs text-amber-300'>Prioritaria: {appointment.priorityReason || 'Sin detalle'}</p>
      ) : null}
      {actions ? <div className='mt-3 flex flex-wrap gap-2'>{actions}</div> : null}
    </article>
  );
}
