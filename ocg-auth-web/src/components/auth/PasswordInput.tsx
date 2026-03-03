import { Eye, EyeOff } from 'lucide-react';
import { useState, type InputHTMLAttributes } from 'react';
import Input from '../ui/Input';

type Props = InputHTMLAttributes<HTMLInputElement> & {
  label: string;
  error?: string;
};

export default function PasswordInput({ error, label, ...props }: Props) {
  const [show, setShow] = useState(false);

  return (
    <div className='relative'>
      <Input label={label} type={show ? 'text' : 'password'} error={error} {...props} />
      <button
        type='button'
        onClick={() => setShow((prev) => !prev)}
        className='absolute right-3 top-9 text-slate-400 hover:text-slate-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-sky-400 rounded'
        aria-label={show ? 'Ocultar contraseña' : 'Mostrar contraseña'}
      >
        {show ? <EyeOff size={18} /> : <Eye size={18} />}
      </button>
    </div>
  );
}
