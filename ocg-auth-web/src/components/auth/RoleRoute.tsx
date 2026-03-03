import type { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { routes } from '../../config/routes';
import { useAuth } from '../../hooks/useAuth';
import type { AppRole } from '../../services/auth.service';

export default function RoleRoute({ allowed, children }: { allowed: AppRole[]; children: ReactNode }) {
  const { user } = useAuth();
  if (!user) return <Navigate to={routes.login} replace />;
  if (!allowed.includes(user.role)) {
    return <Navigate to={user.role === 'admin' ? routes.dashboardAdmin : routes.dashboardPatient} replace />;
  }
  return <>{children}</>;
}
