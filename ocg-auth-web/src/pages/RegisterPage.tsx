import RegisterForm from '../components/auth/RegisterForm';
import Card from '../components/ui/Card';

export default function RegisterPage() {
  return (
    <div className='flex min-h-screen items-center justify-center bg-slate-950 px-4'>
      <Card title='Crear cuenta' subtitle='Regístrate para acceder al portal de pacientes OCG.'>
        <RegisterForm />
      </Card>
    </div>
  );
}
