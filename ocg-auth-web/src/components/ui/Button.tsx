import type { ButtonHTMLAttributes } from 'react';
import { cn } from '../../utils/cn';

type Props = ButtonHTMLAttributes<HTMLButtonElement> & {
  loading?: boolean;
};

export default function Button({ className, loading, children, disabled, ...props }: Props) {
  return (
    <button
      className={cn(
        'inline-flex w-full items-center justify-center rounded-xl bg-sky-600 px-4 py-2.5 font-semibold text-white transition hover:bg-sky-500',
        'disabled:cursor-not-allowed disabled:opacity-60 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400',
        className,
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? 'Procesando...' : children}
    </button>
  );
}
