import { zodResolver } from '@hookform/resolvers/zod';
import { useMemo } from 'react';
import { useForm } from 'react-hook-form';
import type { AppointmentFormInput } from '../schemas/appointment.schema';
import { appointmentFormSchema } from '../schemas/appointment.schema';
import Button from '../../../components/ui/Button';
import Input from '../../../components/ui/Input';
import { getAvailableSlotsByDate } from '../services/appointments.service';

type Props = {
  onSubmit: (values: AppointmentFormInput) => Promise<void> | void;
};

export default function AppointmentForm({ onSubmit }: Props) {
  const {
    register,
    watch,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting },
  } = useForm({
    resolver: zodResolver(appointmentFormSchema),
    defaultValues: {
      serviceType: 'brackets',
      isPriority: false,
      priorityReason: '',
      slotTime: '',
    },
  });

  const isPriority = watch('isPriority');
  const appointmentDate = watch('appointmentDate');

  const availableSlots = useMemo(() => getAvailableSlotsByDate(appointmentDate || ''), [appointmentDate]);

  const submit = async (values: unknown) => {
    await onSubmit(values as AppointmentFormInput);
    reset({
      serviceType: 'brackets',
      appointmentDate: '',
      slotTime: '',
      reason: '',
      isPriority: false,
      priorityReason: '',
    });
  };

  return (
    <form onSubmit={handleSubmit(submit)} className='grid gap-3 rounded-2xl border border-slate-800 bg-slate-900 p-5'>
      <h3 className='text-lg font-semibold'>Solicitar nueva cita</h3>

      <div className='space-y-1.5'>
        <label className='text-sm font-medium text-slate-200'>Servicio</label>
        <select
          {...register('serviceType')}
          className='w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2.5 text-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400'
        >
          <option value='brackets'>Brackets</option>
          <option value='diseno_sonrisa'>Diseño de sonrisa</option>
          <option value='ortodoncia'>Ortodoncia / corrección dental</option>
        </select>
        {errors.serviceType ? <p className='text-sm text-rose-400'>{errors.serviceType.message}</p> : null}
      </div>

      <div className='grid gap-3 md:grid-cols-2'>
        <Input type='date' label='Fecha deseada' {...register('appointmentDate')} error={errors.appointmentDate?.message} />

        <div className='space-y-1.5'>
          <label className='text-sm font-medium text-slate-200'>Horario disponible</label>
          <select
            {...register('slotTime')}
            className='w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2.5 text-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400'
            disabled={!appointmentDate}
          >
            <option value=''>{appointmentDate ? 'Selecciona horario' : 'Selecciona fecha primero'}</option>
            {availableSlots.map((slot) => (
              <option key={slot} value={slot}>
                {slot}
              </option>
            ))}
          </select>
          {errors.slotTime ? <p className='text-sm text-rose-400'>{errors.slotTime.message}</p> : null}
          {appointmentDate && !availableSlots.length ? (
            <p className='text-sm text-amber-300'>No hay horarios disponibles para ese día.</p>
          ) : null}
        </div>
      </div>

      <div className='space-y-1.5'>
        <label className='text-sm font-medium text-slate-200'>Motivo</label>
        <textarea
          {...register('reason')}
          className='min-h-24 w-full rounded-xl border border-slate-700 bg-slate-950 px-3 py-2.5 text-slate-100 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400'
          placeholder='Describe el motivo de la cita'
        />
        {errors.reason ? <p className='text-sm text-rose-400'>{errors.reason.message}</p> : null}
      </div>

      <label className='flex items-center gap-2 text-sm text-slate-200'>
        <input type='checkbox' {...register('isPriority')} className='h-4 w-4 rounded border-slate-600 bg-slate-950' />
        Marcar como caso prioritario
      </label>

      {isPriority ? (
        <Input
          label='Motivo de prioridad'
          placeholder='Ej: dolor intenso, urgencia funcional'
          {...register('priorityReason')}
          error={errors.priorityReason?.message}
        />
      ) : null}

      <Button type='submit' loading={isSubmitting}>Enviar solicitud</Button>
    </form>
  );
}
