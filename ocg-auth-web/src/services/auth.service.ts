export type AppRole = 'admin' | 'patient';

export type AppUser = {
  uid: string;
  email: string;
  displayName: string;
  role: AppRole;
  status: 'active';
  createdAt: string;
};

type Listener = (user: AppUser | null) => void;

type ApiAuthResponse = {
  user: AppUser;
  message?: string;
};

const SESSION_KEY = 'ocg_auth_session';
const CURRENT_USER_KEY = 'ocg_current_user';
const USERS_KEY = 'ocg_users';
const listeners = new Set<Listener>();

const readSession = (): AppUser | null => {
  const raw = localStorage.getItem(SESSION_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AppUser;
  } catch {
    return null;
  }
};

const readUsers = (): AppUser[] => {
  const raw = localStorage.getItem(USERS_KEY);
  if (!raw) return [];
  try {
    return JSON.parse(raw) as AppUser[];
  } catch {
    return [];
  }
};

const writeUsers = (users: AppUser[]) => {
  localStorage.setItem(USERS_KEY, JSON.stringify(users));
};

const upsertUser = (user: AppUser) => {
  const users = readUsers();
  const index = users.findIndex((item) => item.uid === user.uid || item.email.toLowerCase() === user.email.toLowerCase());
  if (index >= 0) users[index] = user;
  else users.push(user);
  writeUsers(users);
};

const writeSession = (user: AppUser | null) => {
  if (!user) {
    localStorage.removeItem(SESSION_KEY);
    localStorage.removeItem(CURRENT_USER_KEY);
    return;
  }
  localStorage.setItem(SESSION_KEY, JSON.stringify(user));
  localStorage.setItem(CURRENT_USER_KEY, JSON.stringify(user));
  upsertUser(user);
};

const notify = () => {
  const current = readSession();
  listeners.forEach((listener) => listener(current));
};

const apiRequest = async <T>(path: string, body: Record<string, unknown>): Promise<T> => {
  let response: Response;
  try {
    response = await fetch(path, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch {
    throw new Error('No hay conexión con la API local. Ejecuta npm run dev para levantar web + servidor.');
  }

  const data = (await response.json().catch(() => ({}))) as { message?: string } & T;

  if (!response.ok) {
    throw new Error(data?.message || 'Error en autenticación local.');
  }

  return data as T;
};

export const register = async (email: string, password: string): Promise<AppUser> => {
  const data = await apiRequest<ApiAuthResponse>('/api/auth/register', { email, password });
  writeSession(data.user);
  notify();
  return data.user;
};

export const login = async (email: string, password: string): Promise<AppUser> => {
  const data = await apiRequest<ApiAuthResponse>('/api/auth/login', { email, password });
  writeSession(data.user);
  notify();
  return data.user;
};

export const logout = async (): Promise<void> => {
  writeSession(null);
  notify();
};

export const resetPassword = async (email: string): Promise<void> => {
  await apiRequest<{ message: string }>('/api/auth/reset-password', { email });
};

export const onAuthChange = (callback: Listener) => {
  listeners.add(callback);
  callback(readSession());
  return () => {
    listeners.delete(callback);
  };
};

export const getCurrentUser = (): AppUser | null => readSession();
