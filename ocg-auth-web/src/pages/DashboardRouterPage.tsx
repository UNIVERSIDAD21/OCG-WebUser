import { Navigate } from 'react-router-dom';
import { routes } from '../config/routes';
import { useAuth } from '../hooks/useAuth';

export default function DashboardRouterPage() {
  const { user } = useAuth();
  if (!user) return <Navigate to={routes.login} replace />;
  return <Navigate to={user.role === 'admin' ? routes.dashboardAdmin : routes.dashboardPatient} replace />;
}
