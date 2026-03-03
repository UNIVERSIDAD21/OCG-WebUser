import type { ReactNode } from 'react';

type Props = {
  title: string;
  subtitle?: string;
  children: ReactNode;
};

export default function Card({ title, subtitle, children }: Props) {
  return (
    <section className='w-full max-w-md rounded-2xl border border-slate-800 bg-slate-950/90 p-6 shadow-2xl backdrop-blur'>
      <h1 className='text-2xl font-bold text-white'>{title}</h1>
      {subtitle ? <p className='mt-1 text-sm text-slate-300'>{subtitle}</p> : null}
      <div className='mt-5'>{children}</div>
    </section>
  );
}
