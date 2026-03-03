import type { AppointmentFilters, AppointmentPriority, AppointmentStatus } from '../types/appointment.types';

type Props = {
  filters: AppointmentFilters;
  onChange: (filters: AppointmentFilters) => void;
};

export default function AdminAppointmentFilters({ filters, onChange }: Props) {
  const set = (key: keyof AppointmentFilters, value?: string) => {
    onChange({ ...filters, [key]: value || undefined });
  };

  return (
    <div className='grid gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-4 md:grid-cols-3'>
      <div>
        <label className='text-sm text-slate-300'>Estado</label>
        <select
          value={filters.status ?? 'all'}
          onChange={(event) => set('status', event.target.value as AppointmentStatus | 'all')}
          className='mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm'
        >
          <option value='all'>Todos</option>
          <option value='requested'>Solicitada</option>
          <option value='pending_priority_review'>Revisión prioritaria</option>
          <option value='confirmed'>Confirmada</option>
          <option value='rescheduled'>Reprogramada</option>
          <option value='cancelled_by_patient'>Cancelada paciente</option>
          <option value='cancelled_by_admin'>Cancelada admin</option>
          <option value='completed'>Completada</option>
          <option value='no_show'>No asistió</option>
        </select>
      </div>

      <div>
        <label className='text-sm text-slate-300'>Prioridad</label>
        <select
          value={filters.priority ?? 'all'}
          onChange={(event) => set('priority', event.target.value as AppointmentPriority | 'all')}
          className='mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm'
        >
          <option value='all'>Todas</option>
          <option value='normal'>Normal</option>
          <option value='high'>Alta</option>
        </select>
      </div>

      <div>
        <label className='text-sm text-slate-300'>Fecha</label>
        <input
          type='date'
          value={filters.date ?? ''}
          onChange={(event) => set('date', event.target.value || undefined)}
          className='mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm'
        />
      </div>
    </div>
  );
}
