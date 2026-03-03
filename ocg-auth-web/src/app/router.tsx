import { Navigate, createBrowserRouter } from 'react-router-dom';
import ProtectedRoute from '../components/auth/ProtectedRoute';
import RoleRoute from '../components/auth/RoleRoute';
import { routes } from '../config/routes';
import DashboardPage from '../pages/DashboardPage';
import DashboardRouterPage from '../pages/DashboardRouterPage';
import ForgotPasswordPage from '../pages/ForgotPasswordPage';
import LoginPage from '../pages/LoginPage';
import NotFoundPage from '../pages/NotFoundPage';
import RegisterPage from '../pages/RegisterPage';
import { getCurrentUser } from '../services/auth.service';

export const router = createBrowserRouter([
  {
    path: routes.root,
    element: <Navigate to={getCurrentUser() ? routes.dashboard : routes.login} replace />,
  },
  { path: routes.login, element: <LoginPage /> },
  { path: routes.register, element: <RegisterPage /> },
  { path: routes.forgotPassword, element: <ForgotPasswordPage /> },
  {
    path: routes.dashboard,
    element: (
      <ProtectedRoute>
        <DashboardRouterPage />
      </ProtectedRoute>
    ),
  },
  {
    path: routes.dashboardPatient,
    element: (
      <RoleRoute allowed={['patient']}>
        <DashboardPage />
      </RoleRoute>
    ),
  },
  {
    path: routes.dashboardAdmin,
    element: (
      <RoleRoute allowed={['admin']}>
        <DashboardPage />
      </RoleRoute>
    ),
  },
  {
    path: routes.appointments,
    element: <Navigate to={routes.dashboardPatient} replace />,
  },
  {
    path: routes.adminAppointments,
    element: <Navigate to={routes.dashboardAdmin} replace />,
  },
  { path: '*', element: <NotFoundPage /> },
]);
