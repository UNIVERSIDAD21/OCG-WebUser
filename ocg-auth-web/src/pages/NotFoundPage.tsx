import { Link } from 'react-router-dom';
import { routes } from '../config/routes';

export default function NotFoundPage() {
  return (
    <div className='flex min-h-screen items-center justify-center bg-slate-950 px-4'>
      <div className='rounded-2xl border border-slate-800 bg-slate-950 p-8 text-center'>
        <h1 className='text-3xl font-bold text-white'>404</h1>
        <p className='mt-2 text-slate-300'>La página solicitada no existe.</p>
        <Link to={routes.login} className='mt-4 inline-block text-sky-300 hover:text-sky-200'>Ir a login</Link>
      </div>
    </div>
  );
}
