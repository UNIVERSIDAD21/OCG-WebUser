import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().email('Ingresa un correo válido.'),
  password: z.string().min(8, 'La contraseña debe tener mínimo 8 caracteres.'),
});

export const registerSchema = loginSchema.extend({
  confirmPassword: z.string().min(8, 'Confirma tu contraseña.'),
}).refine((values) => values.password === values.confirmPassword, {
  message: 'Las contraseñas no coinciden.',
  path: ['confirmPassword'],
});

export const forgotPasswordSchema = z.object({
  email: z.string().email('Ingresa un correo válido.'),
});

export type LoginInput = z.infer<typeof loginSchema>;
export type RegisterInput = z.infer<typeof registerSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
