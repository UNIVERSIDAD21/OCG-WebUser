import { zodResolver } from '@hookform/resolvers/zod';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { Link, useNavigate } from 'react-router-dom';
import { routes } from '../../config/routes';
import { loginSchema, type LoginInput } from '../../schemas/auth.schema';
import { useAuth } from '../../hooks/useAuth';
import Alert from '../ui/Alert';
import Button from '../ui/Button';
import Input from '../ui/Input';
import PasswordInput from './PasswordInput';

export default function LoginForm() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [error, setError] = useState('');

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginInput>({ resolver: zodResolver(loginSchema) });

  const onSubmit = async (values: LoginInput) => {
    setError('');
    try {
      await login(values.email, values.password);
      navigate(routes.dashboard);
    } catch {
      setError('Credenciales inválidas. Verifica correo y contraseña.');
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className='space-y-4'>
      {error ? <Alert type='error'>{error}</Alert> : null}
      <Input
        label='Correo electrónico'
        placeholder='tu@correo.com'
        autoComplete='email'
        {...register('email')}
        error={errors.email?.message}
      />
      <PasswordInput
        label='Contraseña'
        placeholder='Mínimo 8 caracteres'
        autoComplete='current-password'
        {...register('password')}
        error={errors.password?.message}
      />
      <Button type='submit' loading={isSubmitting}>Iniciar sesión</Button>
      <div className='flex items-center justify-between text-sm text-slate-300'>
        <Link to={routes.forgotPassword} className='hover:text-sky-300'>¿Olvidaste tu contraseña?</Link>
        <Link to={routes.register} className='hover:text-sky-300'>Crear cuenta</Link>
      </div>
    </form>
  );
}
