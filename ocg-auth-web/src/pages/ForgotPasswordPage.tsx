import ForgotPasswordForm from '../components/auth/ForgotPasswordForm';
import Card from '../components/ui/Card';

export default function ForgotPasswordPage() {
  return (
    <div className='flex min-h-screen items-center justify-center bg-slate-950 px-4'>
      <Card title='Recuperar contraseña' subtitle='Te enviaremos un correo para restablecer el acceso.'>
        <ForgotPasswordForm />
      </Card>
    </div>
  );
}
