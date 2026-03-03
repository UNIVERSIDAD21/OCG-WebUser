# OCG WebUser - Setup (modo local temporal)

## 1) Instalar dependencias
npm install

## 2) Ejecutar en desarrollo
npm run dev

> Este comando levanta API local + Vite sin depender de `concurrently` global.

## 3) Build de producción
npm run build

## Credenciales admin temporal
- Email: `admin@ocg.local`
- Password: `Admin12345!`

## Módulo de citas (local)
- Dashboard paciente: `/dashboard/patient`
- Dashboard admin: `/dashboard/admin`
- Redirección inteligente: `/dashboard`

### Claves de localStorage usadas
- `ocg_auth_session` (sesión actual)
- `ocg_current_user` (sesión actual, alias)
- `ocg_users` (usuarios locales para módulo)
- `ocg_appointments` (citas)

### Seed automático
Si las claves están vacías, se cargan:
- 1 admin + 2 pacientes (usuarios)
- 3 citas de ejemplo con distintos estados

## Nota
Esta versión evita Firebase temporalmente para avanzar frontend.
La capa `appointments.service.ts` está preparada para migrar a repositorio Firebase luego.
