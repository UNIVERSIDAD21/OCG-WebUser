import { useMemo, useState } from 'react';
import Alert from '../../../components/ui/Alert';
import Button from '../../../components/ui/Button';
import {
  getAllAppointments,
  seedAppointmentsIfEmpty,
  updateAppointmentStatus,
} from '../services/appointments.service';
import type { Appointment, AppointmentFilters, AppointmentStatus } from '../types/appointment.types';
import AdminAppointmentFilters from '../components/AdminAppointmentFilters';
import { useAuth } from '../../../hooks/useAuth';
import AppointmentStatusBadge from '../components/AppointmentStatusBadge';
import { serviceTypeLabel } from '../utils/appointment.mappers';

export default function AdminAppointmentsPage() {
  const { user } = useAuth();
  const [filters, setFilters] = useState<AppointmentFilters>({ status: 'all', priority: 'all' });
  const [error, setError] = useState('');
  const [version, setVersion] = useState(0);

  const appointments = useMemo(() => {
    void version;
    seedAppointmentsIfEmpty();
    return getAllAppointments(filters);
  }, [filters, version]);

  const priorityCount = appointments.filter((item) => item.priority === 'high').length;
  const pendingCount = appointments.filter((item) => ['requested', 'pending_priority_review'].includes(item.status)).length;

  const changeStatus = (appointmentId: string, status: AppointmentStatus) => {
    if (!user) return;
    setError('');
    try {
      updateAppointmentStatus(appointmentId, status, user);
      setVersion((prev) => prev + 1);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo actualizar estado.');
    }
  };

  const renderActions = (appointment: Appointment) => {
    const blocked = ['completed', 'cancelled_by_admin', 'cancelled_by_patient', 'no_show'].includes(appointment.status);
    return (
      <div className='flex flex-wrap gap-2'>
        <Button className='w-auto px-3 py-1.5 text-xs' onClick={() => changeStatus(appointment.id, 'confirmed')} disabled={blocked}>
          Confirmar
        </Button>
        <Button className='w-auto px-3 py-1.5 text-xs' onClick={() => changeStatus(appointment.id, 'cancelled_by_admin')} disabled={blocked}>
          Cancelar
        </Button>
        <Button className='w-auto px-3 py-1.5 text-xs' onClick={() => changeStatus(appointment.id, 'completed')} disabled={blocked}>
          Completar
        </Button>
        <Button className='w-auto px-3 py-1.5 text-xs' onClick={() => changeStatus(appointment.id, 'no_show')} disabled={blocked}>
          No asistió
        </Button>
      </div>
    );
  };

  return (
    <div className='space-y-4'>
      {error ? <Alert type='error'>{error}</Alert> : null}

      <div className='grid gap-3 md:grid-cols-3'>
        <div className='rounded-xl border border-slate-800 bg-slate-900 p-4'>
          <p className='text-xs text-slate-400'>Citas filtradas</p>
          <p className='text-2xl font-bold'>{appointments.length}</p>
        </div>
        <div className='rounded-xl border border-amber-600/30 bg-amber-500/10 p-4'>
          <p className='text-xs text-amber-200'>Prioritarias</p>
          <p className='text-2xl font-bold text-amber-100'>{priorityCount}</p>
        </div>
        <div className='rounded-xl border border-sky-600/30 bg-sky-500/10 p-4'>
          <p className='text-xs text-sky-200'>Pendientes de atención</p>
          <p className='text-2xl font-bold text-sky-100'>{pendingCount}</p>
        </div>
      </div>

      <AdminAppointmentFilters filters={filters} onChange={setFilters} />

      <div className='overflow-hidden rounded-2xl border border-slate-800 bg-slate-900'>
        <div className='hidden grid-cols-12 gap-3 border-b border-slate-800 bg-slate-950/70 px-4 py-3 text-xs font-semibold text-slate-300 md:grid'>
          <div className='col-span-2'>Paciente</div>
          <div className='col-span-2'>Servicio</div>
          <div className='col-span-2'>Fecha / Hora</div>
          <div className='col-span-2'>Estado</div>
          <div className='col-span-1'>Prioridad</div>
          <div className='col-span-3'>Acciones</div>
        </div>

        {!appointments.length ? (
          <div className='p-4 text-sm text-slate-300'>No hay citas para los filtros seleccionados.</div>
        ) : (
          appointments.map((appointment) => (
            <div
              key={appointment.id}
              className={`grid gap-3 border-b border-slate-800 px-4 py-4 md:grid-cols-12 ${
                appointment.priority === 'high' ? 'bg-amber-500/5' : ''
              }`}
            >
              <div className='md:col-span-2'>
                <p className='text-sm font-semibold'>{appointment.patientName}</p>
                <p className='text-xs text-slate-400'>{appointment.patientEmail}</p>
              </div>
              <div className='md:col-span-2 text-sm text-slate-300'>{serviceTypeLabel[appointment.serviceType]}</div>
              <div className='md:col-span-2 text-sm text-slate-300'>
                {appointment.appointmentDate}
                <br />
                {appointment.startTime} - {appointment.endTime}
              </div>
              <div className='md:col-span-2'>
                <AppointmentStatusBadge status={appointment.status} />
              </div>
              <div className='md:col-span-1 text-sm'>
                <span className={appointment.priority === 'high' ? 'text-amber-300' : 'text-slate-300'}>
                  {appointment.priority === 'high' ? 'Alta' : 'Normal'}
                </span>
              </div>
              <div className='md:col-span-3'>{renderActions(appointment)}</div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
