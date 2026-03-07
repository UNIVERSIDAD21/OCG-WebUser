# VALIDACION_GESTION_PACIENTES.md

> Fecha de actualización: 2026-03-07 (UTC)

## A) Lista y navegación admin
- [x] Lista de pacientes renderiza desde stream.
- [x] Búsqueda por nombre/correo funciona.
- [x] Filtros básicos en cliente funcionan.
- [x] Navegación a detalle desde tarjeta de paciente funciona.

## B) Detalle de paciente
- [x] `PatientDetailScreen` carga por `patientId`.
- [x] TabBar con 5 tabs (Perfil, Tratamiento, Citas, Pagos, Simulador).
- [x] Chip de etapa/tipo visibles en cabecera.

## C) Formulario crear/editar
- [x] Ruta crear (`/admin/patients/new`) funcional.
- [x] Ruta editar (`/admin/patients/:patientId/edit`) funcional.
- [x] Validaciones de campos obligatorios activas.
- [x] Guardado conectado a repositorio (`createPatient` / `updatePatientBasicData`).

## D) Perfil paciente
- [x] Ruta `/patient/profile` funcional para usuario autenticado.
- [x] Datos clínicos en solo lectura para paciente.
- [x] Navegación desde `PatientHomeScreen` a perfil y citas.

## E) Calidad técnica
- [x] `flutter analyze` sin errores.
- [x] `flutter test` en verde.

## F) Pendientes E2E manuales para cierre total del bloque
- [ ] CRUD completo validado en Firebase real (crear/editar/lectura por rol).
- [ ] Verificar permisos por rol en Firestore rules para edición admin vs lectura paciente.
- [ ] Confirmar comportamiento en web + móvil con datos reales.
