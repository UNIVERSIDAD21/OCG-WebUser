import { useMemo, useState } from 'react';
import Alert from '../../../components/ui/Alert';
import Button from '../../../components/ui/Button';
import { useAuth } from '../../../hooks/useAuth';
import {
  cancelAppointmentByPatient,
  createAppointment,
  getAppointmentsByPatient,
  getNextAppointmentForPatient,
  seedAppointmentsIfEmpty,
} from '../services/appointments.service';
import type { AppointmentFormInput } from '../schemas/appointment.schema';
import AppointmentForm from '../components/AppointmentForm';
import AppointmentList from '../components/AppointmentList';

export default function PatientAppointmentsPage() {
  const { user } = useAuth();
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [version, setVersion] = useState(0);

  const appointments = useMemo(() => {
    void version;
    if (!user) return [];
    seedAppointmentsIfEmpty();
    return getAppointmentsByPatient(user.uid);
  }, [user, version]);

  const nextAppointment = user ? getNextAppointmentForPatient(user.uid) : null;

  const submit = async (values: AppointmentFormInput) => {
    if (!user) return;
    setMessage('');
    setError('');
    try {
      await createAppointment(
        {
          serviceType: values.serviceType,
          reason: values.reason,
          appointmentDate: values.appointmentDate,
          slotTime: values.slotTime,
          priority: values.isPriority ? 'high' : 'normal',
          priorityReason: values.priorityReason,
          notesPatient: '',
        },
        user,
      );
      setMessage('Cita solicitada correctamente.');
      setVersion((prev) => prev + 1);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo crear la cita.');
    }
  };

  const cancel = (appointmentId: string) => {
    if (!user) return;
    setMessage('');
    setError('');
    try {
      cancelAppointmentByPatient(appointmentId, user.uid);
      setMessage('Cita cancelada.');
      setVersion((prev) => prev + 1);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'No se pudo cancelar la cita.');
    }
  };

  return (
    <div className='space-y-4'>
      {message ? <Alert type='success'>{message}</Alert> : null}
      {error ? <Alert type='error'>{error}</Alert> : null}

      <section className='rounded-2xl border border-slate-800 bg-slate-900 p-5'>
        <h2 className='text-lg font-semibold'>Próxima cita</h2>
        {nextAppointment ? (
          <p className='mt-2 text-sm text-slate-300'>
            {nextAppointment.appointmentDate} · {nextAppointment.startTime} - {nextAppointment.endTime}
          </p>
        ) : (
          <p className='mt-2 text-sm text-slate-300'>No tienes próximas citas confirmadas.</p>
        )}
      </section>

      <div id='agendar-cita'>
        <AppointmentForm onSubmit={submit} />
      </div>

      <section className='space-y-3'>
        <h3 className='text-lg font-semibold'>Mis citas</h3>
        <AppointmentList
          appointments={appointments}
          emptyText='Aún no tienes citas registradas.'
          renderActions={(appointment) => (
            <Button
              className='w-auto px-3 py-1.5 text-sm'
              onClick={() => cancel(appointment.id)}
              disabled={['completed', 'cancelled_by_admin', 'cancelled_by_patient', 'no_show'].includes(appointment.status)}
            >
              Cancelar
            </Button>
          )}
        />
      </section>
    </div>
  );
}
