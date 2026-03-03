import { zodResolver } from '@hookform/resolvers/zod';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { Link, useNavigate } from 'react-router-dom';
import { routes } from '../../config/routes';
import { registerSchema, type RegisterInput } from '../../schemas/auth.schema';
import { useAuth } from '../../hooks/useAuth';
import Alert from '../ui/Alert';
import Button from '../ui/Button';
import Input from '../ui/Input';
import PasswordInput from './PasswordInput';

export default function RegisterForm() {
  const { register: registerUser } = useAuth();
  const navigate = useNavigate();
  const [error, setError] = useState('');

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<RegisterInput>({ resolver: zodResolver(registerSchema) });

  const onSubmit = async (values: RegisterInput) => {
    setError('');
    try {
      await registerUser(values.email, values.password);
      navigate(routes.dashboard);
    } catch {
      setError('No fue posible registrar la cuenta. Intenta con otro correo.');
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
        autoComplete='new-password'
        {...register('password')}
        error={errors.password?.message}
      />
      <PasswordInput
        label='Confirmar contraseña'
        placeholder='Repite tu contraseña'
        autoComplete='new-password'
        {...register('confirmPassword')}
        error={errors.confirmPassword?.message}
      />
      <Button type='submit' loading={isSubmitting}>Crear cuenta</Button>
      <p className='text-sm text-slate-300'>
        ¿Ya tienes cuenta? <Link to={routes.login} className='text-sky-300 hover:text-sky-200'>Inicia sesión</Link>
      </p>
    </form>
  );
}
