import { z } from 'zod';

export const appointmentFormSchema = z
  .object({
    serviceType: z.enum(['brackets', 'diseno_sonrisa', 'ortodoncia'], {
      message: 'Selecciona un servicio.',
    }),
    appointmentDate: z.string().min(1, 'La fecha es obligatoria.'),
    slotTime: z.string().min(1, 'Selecciona un horario disponible.'),
    reason: z.string().min(10, 'Describe el motivo con al menos 10 caracteres.'),
    isPriority: z.boolean().default(false),
    priorityReason: z.string().optional(),
  })
  .refine((data) => (!data.isPriority ? true : Boolean(data.priorityReason && data.priorityReason.trim().length > 4)), {
    message: 'Explica el motivo de prioridad (mínimo 5 caracteres).',
    path: ['priorityReason'],
  });

export type AppointmentFormInput = z.infer<typeof appointmentFormSchema>;
