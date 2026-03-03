import LoginForm from '../components/auth/LoginForm';
import Card from '../components/ui/Card';

export default function LoginPage() {
  return (
    <div className='flex min-h-screen items-center justify-center bg-slate-950 px-4'>
      <Card title='Bienvenido a OCG' subtitle='Inicia sesión para gestionar tu experiencia odontológica.'>
        <LoginForm />
      </Card>
    </div>
  );
}
