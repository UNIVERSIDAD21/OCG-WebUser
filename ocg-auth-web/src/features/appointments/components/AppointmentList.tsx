import type { ReactNode } from 'react';
import type { Appointment } from '../types/appointment.types';
import AppointmentCard from './AppointmentCard';

type Props = {
  appointments: Appointment[];
  renderActions?: (appointment: Appointment) => ReactNode;
  emptyText?: string;
};

export default function AppointmentList({ appointments, renderActions, emptyText = 'No hay citas.' }: Props) {
  if (!appointments.length) {
    return <div className='rounded-2xl border border-slate-800 bg-slate-900 p-5 text-sm text-slate-300'>{emptyText}</div>;
  }

  return (
    <div className='grid gap-3'>
      {appointments.map((appointment) => (
        <AppointmentCard
          key={appointment.id}
          appointment={appointment}
          actions={renderActions ? renderActions(appointment) : undefined}
        />
      ))}
    </div>
  );
}
