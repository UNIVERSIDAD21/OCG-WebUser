import type { ReactNode } from 'react';
import { cn } from '../../utils/cn';

type Props = {
  children: ReactNode;
  type?: 'error' | 'success' | 'info';
};

export default function Alert({ children, type = 'info' }: Props) {
  return (
    <div
      className={cn('rounded-lg px-3 py-2 text-sm', {
        'bg-rose-500/15 text-rose-200 border border-rose-500/30': type === 'error',
        'bg-emerald-500/15 text-emerald-200 border border-emerald-500/30': type === 'success',
        'bg-sky-500/15 text-sky-200 border border-sky-500/30': type === 'info',
      })}
    >
      {children}
    </div>
  );
}
