import type { InputHTMLAttributes } from 'react';
import { cn } from '../../utils/cn';

type Props = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: string;
};

export default function Input({ className, error, id, label, ...props }: Props) {
  const inputId = id ?? props.name;

  return (
    <div className='space-y-1.5'>
      <label htmlFor={inputId} className='text-sm font-medium text-slate-200'>
        {label}
      </label>
      <input
        id={inputId}
        aria-invalid={Boolean(error)}
        className={cn(
          'w-full rounded-xl border border-slate-700 bg-slate-900 px-3 py-2.5 text-slate-100 placeholder:text-slate-500',
          'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400',
          error && 'border-rose-500',
          className,
        )}
        {...props}
      />
      {error ? <p className='text-sm text-rose-400'>{error}</p> : null}
    </div>
  );
}
