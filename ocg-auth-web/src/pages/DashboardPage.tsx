import {
  CalendarCheck2,
  CreditCard,
  FileText,
  Smile,
  Stethoscope,
  BellRing,
  ChevronRight,
} from 'lucide-react';
import Button from '../components/ui/Button';
import { useAuth } from '../hooks/useAuth';
import PatientAppointmentsPage from '../features/appointments/pages/PatientAppointmentsPage';
import AdminAppointmentsPage from '../features/appointments/pages/AdminAppointmentsPage';

const clientCards = [
  {
    title: 'Próxima cita',
    text: 'Gestiona tu próxima consulta y recibe recordatorios oportunos para no perder controles.',
    icon: CalendarCheck2,
    accent: 'from-sky-500/20 to-sky-700/10 border-sky-400/30',
  },
  {
    title: 'Seguimiento clínico',
    text: 'Visualiza avances, notas médicas y próximos pasos del tratamiento en un solo lugar.',
    icon: FileText,
    accent: 'from-teal-500/20 to-teal-700/10 border-teal-400/30',
  },
  {
    title: 'Pagos y comprobantes',
    text: 'Consulta estado de pagos, historial y comprobantes pendientes de validación.',
    icon: CreditCard,
    accent: 'from-violet-500/20 to-violet-700/10 border-violet-400/30',
  },
];

export default function DashboardPage() {
  const { user, logout } = useAuth();
  const isAdmin = user?.role === 'admin';

  return (
    <div className='min-h-screen bg-slate-950 px-4 py-10 text-slate-100'>
      <div className='mx-auto w-full max-w-6xl space-y-6'>
        <header className='rounded-3xl border border-slate-800 bg-gradient-to-br from-slate-900 via-slate-950 to-slate-900 p-6 shadow-2xl'>
          <div className='flex flex-wrap items-start justify-between gap-4'>
            <div>
              <p className='text-xs uppercase tracking-[0.2em] text-sky-300'>Portal OCG</p>
              <h1 className='mt-2 text-2xl font-bold sm:text-3xl'>
                {isAdmin ? 'Dashboard de administración' : 'Dashboard de paciente'}
              </h1>
              <p className='mt-2 text-sm text-slate-300'>
                Usuario: {user?.email} · Rol: {user?.role}
              </p>
            </div>
            <div className='w-full sm:w-44'>
              <Button onClick={() => logout()}>Cerrar sesión</Button>
            </div>
          </div>
        </header>

        {isAdmin ? (
          <>
            <section className='grid gap-4 md:grid-cols-2'>
              <article className='rounded-2xl border border-slate-800 bg-slate-900 p-6'>
                <div className='mb-3 inline-flex rounded-lg border border-slate-700 p-2 text-sky-300'>
                  <Stethoscope size={18} />
                </div>
                <h2 className='text-lg font-semibold'>Gestión general</h2>
                <p className='mt-2 text-sm text-slate-300'>
                  Próximamente: administración de usuarios, gestión de citas, recordatorios y reportes.
                </p>
              </article>
              <article className='rounded-2xl border border-slate-800 bg-slate-900 p-6'>
                <div className='mb-3 inline-flex rounded-lg border border-slate-700 p-2 text-teal-300'>
                  <BellRing size={18} />
                </div>
                <h2 className='text-lg font-semibold'>Acciones rápidas</h2>
                <ul className='mt-2 space-y-2 text-sm text-slate-300'>
                  <li className='flex items-center gap-2'>
                    <ChevronRight size={14} className='text-slate-500' /> Revisar nuevos registros
                  </li>
                  <li className='flex items-center gap-2'>
                    <ChevronRight size={14} className='text-slate-500' /> Supervisar agenda del día
                  </li>
                  <li className='flex items-center gap-2'>
                    <ChevronRight size={14} className='text-slate-500' /> Validar pagos pendientes
                  </li>
                </ul>
              </article>
            </section>

            <section className='rounded-2xl border border-slate-800 bg-slate-900/40 p-4'>
              <h2 className='mb-3 text-lg font-semibold'>Agenda de citas</h2>
              <AdminAppointmentsPage />
            </section>
          </>
        ) : (
          <>
            <section className='grid gap-4 md:grid-cols-3'>
              {clientCards.map((card) => {
                const Icon = card.icon;
                return (
                  <article
                    key={card.title}
                    className={`rounded-2xl border bg-gradient-to-br p-5 shadow-lg ${card.accent}`}
                  >
                    <div className='mb-3 inline-flex rounded-lg border border-white/15 bg-slate-950/60 p-2 text-slate-100'>
                      <Icon size={18} />
                    </div>
                    <h2 className='text-lg font-semibold text-white'>{card.title}</h2>
                    <p className='mt-2 text-sm text-slate-200'>{card.text}</p>
                  </article>
                );
              })}
            </section>

            <section className='grid gap-4 lg:grid-cols-[1.2fr_0.8fr]'>
              <article className='rounded-2xl border border-slate-800 bg-slate-900 p-6'>
                <h2 className='text-lg font-semibold'>Resumen de tu progreso</h2>
                <p className='mt-3 text-sm text-slate-300'>
                  Aquí verás el historial de tus controles, evolución por etapas y recomendaciones médicas personalizadas.
                </p>
                <div className='mt-4 h-2 w-full rounded-full bg-slate-800'>
                  <div className='h-2 w-1/3 rounded-full bg-gradient-to-r from-sky-400 to-teal-300' />
                </div>
                <p className='mt-2 text-xs text-slate-400'>Progreso estimado del tratamiento: 33%</p>
              </article>

              <article className='rounded-2xl border border-slate-800 bg-slate-900 p-6'>
                <div className='mb-3 inline-flex rounded-lg border border-slate-700 p-2 text-teal-300'>
                  <Smile size={18} />
                </div>
                <h2 className='text-lg font-semibold'>Agendamiento de citas</h2>
                <p className='mt-2 text-sm text-slate-300'>Solicita tu cita directamente desde el dashboard.</p>
                <a
                  href='#agendar-cita'
                  className='mt-4 inline-flex rounded-lg border border-sky-300 px-4 py-2 text-sm font-semibold text-sky-200 transition hover:bg-sky-500/20'
                >
                  Agendar cita
                </a>
              </article>
            </section>

            <section className='rounded-2xl border border-slate-800 bg-slate-900/40 p-4'>
              <h2 className='mb-3 text-lg font-semibold'>Módulo de citas</h2>
              <PatientAppointmentsPage />
            </section>
          </>
        )}
      </div>
    </div>
  );
}
