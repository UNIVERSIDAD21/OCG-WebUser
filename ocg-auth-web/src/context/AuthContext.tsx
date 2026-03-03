import { useEffect, useMemo, useState, type ReactNode } from 'react';
import type { AppUser } from '../services/auth.service';
import * as authService from '../services/auth.service';
import { AuthContext } from './AuthContextValue';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = authService.onAuthChange((nextUser) => {
      setUser(nextUser);
      setLoading(false);
    });
    return () => unsub();
  }, []);

  const value = useMemo(
    () => ({
      user,
      loading,
      login: authService.login,
      register: authService.register,
      logout: authService.logout,
      resetPassword: authService.resetPassword,
    }),
    [user, loading],
  );

  if (loading) {
    return <div className='flex min-h-screen items-center justify-center bg-slate-950 text-slate-200'>Cargando sesión...</div>;
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
