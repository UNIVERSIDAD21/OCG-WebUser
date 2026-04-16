# ESTADO ACTUAL DEL PROYECTO — OCG Clínica
> Generado: 2026-03-09 | Análisis completo del repositorio `UNIVERSIDAD21/OCG-WebUser`

---

## Resumen ejecutivo

El proyecto tiene una base sólida. Los bloques de infraestructura, autenticación y gestión de pacientes están **completamente implementados**. El agente debe continuar desde el bloque de Tratamiento y Etapas (Bloque 06) hacia adelante.

---

## ✅ LO QUE YA ESTÁ HECHO

### Infraestructura base (Bloque 01) — COMPLETO
- `main.dart` con Firebase init, FCM permission, background handler
- `app.dart` con `MaterialApp.router` y `OcgTheme` aplicado
- `app_router.dart` con `go_router`, guards por rol (admin / patient), anti-race condition auth vs role
- `route_names.dart` con todas las rutas definidas
- `OcgTheme`, `OcgColors`, `OcgTextStyles` — tema visual OCG completo
- Widgets compartidos: `OcgButton`, `OcgCard`, `OcgChip`, `OcgLoadingScreen`
- Constantes: `FirestorePaths`, `StoragePaths`
- Firebase: `cloud_firestore`, `firebase_auth`, `firebase_storage`, `firebase_core` configurados en Android, iOS, Web, Windows

### Base de datos (Bloque 02) — MODELOS COMPLETOS
- `PatientModel` con serialización completa (todos los campos clínicos, financieros, FCM)
- `AppointmentModel` con enums de tipo y estado
- `PaymentModel` + `PaymentTransaction` — fuente de verdad en `payments/{patientId}`
- `FirestorePaths` con acceso directo a subcolecciones

### Autenticación y Roles (Bloque 03) — COMPLETO
- `AuthService` con signIn, signOut, resetPassword, getUserRole, updateFcmToken
- `authStateProvider` (Stream<User?>)
- `userRoleProvider` (lee Custom Claims de Firebase)
- `authNotifierProvider` (login + signOut con Riverpod)
- `LoginScreen` con validación de email/contraseña y manejo de errores Firebase
- `ForgotPasswordScreen` con validación y feedback
- Guards en `go_router`: rutas admin ↔ patient correctamente separadas
- Tests: validaciones de formulario (login + forgot)

### Gestión de Pacientes (Bloque 04) — COMPLETO
- `PatientsRepository`: watchAll, watchById, createPatient, updatePatientBasicData
- `patients_provider`: stream, búsqueda en cliente, filtros por etapa/tipo de tratamiento
- `AdminPatientsScreen`: lista con buscador + chips de filtro + stream reactivo
- `PatientDetailScreen`: 5 tabs (Perfil, Tratamiento, Citas, Pagos, Simulador)
- `PatientFormScreen`: alta y edición de paciente con validación
- `PatientProfileScreen`: vista de paciente propio (solo lectura clínica)

### Agenda de Citas (Bloque 05) — COMPLETO (funcionalidad base)
- `AppointmentsRepository`: watchByDate, watchByPatient, createWithSlotControl (Transaction), updateStatus, rescheduleAppointment
- `appointments_provider`: por fecha (admin) y por paciente
- `AdminAppointmentsScreen`: selección de fecha, listado diario, alta rápida con diálogo
- `PatientAppointmentsScreen`: stream real de citas del paciente autenticado
- Reprogramación sin pérdida de historial

---

## ❌ LO QUE FALTA (en orden de prioridad)

| Bloque | Módulo | Estado |
|--------|--------|--------|
| 06 | Tratamiento y Etapas | ⬜ Pendiente |
| 07 | Pagos | ⬜ Pendiente |
| 08 | Simulador de Sonrisa | ⬜ Pendiente |
| 09 | Notificaciones + Cloud Functions | ⬜ Pendiente |
| 10 | Dashboard Admin (métricas reales) + Pulido UI | ⬜ Pendiente |

---

## Notas técnicas para el agente

1. **El agente no debe tocar los bloques ya cerrados** salvo que un bloque posterior lo requiera explícitamente.
2. Los tabs de `PatientDetailScreen` (`patient_treatment_tab.dart`, `patient_payments_tab.dart`, `patient_simulator_tab.dart`) existen como estructura vacía, pero `patient_treatment_tab.dart` ya recibió una primera evolución compatible con la propuesta de tratamientos múltiples del 2026-04-14.
3. `AdminDashboardScreen` tiene solo un placeholder, se llenará en Bloque 10.
4. `flutter analyze` y `flutter test` deben pasar en ✅ al cierre de cada bloque.
5. Cada bloque tiene su propio archivo `BLOQUE_XX_NOMBRE.md` con el work order detallado.
6. Base nueva en progreso para tratamientos múltiples:
   - `patients/{patientId}/treatments/{treatmentId}`
   - `patients/{patientId}/treatments/{treatmentId}/stageHistory/{entryId}`
   - El tratamiento principal se espeja todavía en los campos legacy del documento `patients/{patientId}` para no romper módulos existentes.
7. Plan técnico consolidado para la propuesta de la doctora (4 bloques del 2026-04-14):
   - `docs/work_orders/PLAN_TECNICO_4_BLOQUES_DOCTORA_2026-04-16.md`
   - Este documento define el orden oficial de ejecución: Bloque 01 → Bloque 02 → Bloque 03 → Bloque 04.
