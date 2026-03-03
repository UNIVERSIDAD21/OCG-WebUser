import { zodResolver } from '@hookform/resolvers/zod';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { Link } from 'react-router-dom';
import { routes } from '../../config/routes';
import { forgotPasswordSchema, type ForgotPasswordInput } from '../../schemas/auth.schema';
import { useAuth } from '../../hooks/useAuth';
import Alert from '../ui/Alert';
import Button from '../ui/Button';
import Input from '../ui/Input';

export default function ForgotPasswordForm() {
  const { resetPassword } = useAuth();
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<ForgotPasswordInput>({ resolver: zodResolver(forgotPasswordSchema) });

  const onSubmit = async (values: ForgotPasswordInput) => {
    setError('');
    setSuccess('');
    try {
      await resetPassword(values.email);
      setSuccess('Revisa tu correo para restablecer tu contraseña.');
    } catch {
      setError('No se pudo enviar el correo de recuperación.');
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className='space-y-4'>
      {error ? <Alert type='error'>{error}</Alert> : null}
      {success ? <Alert type='success'>{success}</Alert> : null}
      <Input
        label='Correo electrónico'
        placeholder='tu@correo.com'
        autoComplete='email'
        {...register('email')}
        error={errors.email?.message}
      />
      <Button type='submit' loading={isSubmitting}>Enviar recuperación</Button>
      <p className='text-sm text-slate-300'>
        <Link to={routes.login} className='text-sky-300 hover:text-sky-200'>Volver a iniciar sesión</Link>
      </p>
    </form>
  );
}
