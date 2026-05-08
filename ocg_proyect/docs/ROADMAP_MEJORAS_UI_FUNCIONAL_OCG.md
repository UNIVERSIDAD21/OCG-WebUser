# Roadmap de mejoras UI y funcionales — OCG-WebUser

> Documento de contexto para Borlty/OpenClaw.  
> Última actualización: 2026-05-08  
> Repo: `OCG-WebUser/ocg_proyect`  
> Alcance: mejoras de UI/UX, funcionamiento y mantenibilidad.  
> Fuera de alcance temporal: pruebas reales de Simulador IA y PayU mientras no existan keys/credenciales reales.

---

## 1. Estado actual resumido

OCG-WebUser ya tiene una base funcional fuerte:

- Auth y roles operativos.
- Admin móvil con shell propio y bottom nav.
- Detalle móvil admin de paciente integrado en `AdminMobileShell`.
- Tratamientos, pagos y documentos agrupados dentro del contexto clínico del paciente.
- Notificaciones con routing corregido para tabs/secciones relevantes.
- PayU y Simulador IA implementados a nivel código, pero pendientes de credenciales reales para validación end-to-end.
- Suite Flutter actual reportada verde en las últimas validaciones (`flutter analyze`, `flutter test`).

Cambios recientes importantes que deben preservarse:

- El detalle de paciente en móvil admin mantiene la bottom nav admin visible.
- El detalle móvil admin usa un scroll principal sin nested scrolls incómodos para Citas, Simulador y Documentos.
- Editar/Eliminar paciente viven dentro del módulo/card `Paciente`, no en el AppBar móvil.
- Perfil y Simulador dentro del detalle móvil admin tienen rediseño premium clínico.
- Notificaciones de tratamiento del paciente rutean a `/patient/treatment`, no a Inicio.

---

## 2. Restricciones permanentes para futuras tareas

Antes de tocar UI o navegación, respetar:

- No romper `AdminMobileShell` ni la bottom nav admin.
- No duplicar bottom nav ni Scaffold visual.
- No reintroducir scrolls anidados en detalle móvil admin.
- No tocar app paciente cuando el pedido sea explícitamente admin móvil.
- No tocar FCM, Cloud Functions, Firebase rules, PayU o lógica IA salvo pedido explícito.
- Preservar `section=pagos`, `section=citas`, `section=simulador`, `section=tratamientos`, `section=documentos/docs`.
- Desktop admin debe mantenerse estable salvo que el pedido sea desktop.
- Para cambios de código: validar con `flutter analyze` y, cuando aplique, `flutter test`.

---

## 3. Prioridad recomendada de próximos bloques

### P1 — Rediseñar Tratamientos móvil admin

Motivo: es el corazón clínico del producto y conecta pagos, documentos, citas e historial.

Mejoras sugeridas:

- Timeline visual de etapas por tratamiento.
- Cards más claras para tratamiento principal/secundarios.
- Alertas clínicas visibles:
  - sin próxima cita,
  - etapa sin actualizar,
  - tratamiento finalizado,
  - saldo pendiente,
  - documentos faltantes.
- Mejor jerarquía entre:
  - estado clínico,
  - etapa actual,
  - pagos asociados,
  - documentos clínicos,
  - historial.
- Acciones contextuales más limpias:
  - actualizar etapa,
  - agregar tratamiento,
  - ir a pagos,
  - ir a documentos.

Cuidado:

- No separar pagos/documentos fuera de Tratamientos.
- No reintroducir scroll interno en tabs embebidos.
- No cambiar lógica financiera ni de tratamientos sin pedido explícito.

---

### P2 — Rediseñar Agenda móvil admin

Motivo: módulo de operación diaria; impacto alto para la clínica.

Mejoras sugeridas:

- Header del día más premium.
- Filtros rápidos:
  - Hoy,
  - Mañana,
  - Pendientes,
  - Vencidas,
  - Canceladas/Históricas.
- Cards de cita con estados visuales fuertes.
- Mejor empty state por día.
- Flujo de crear/reprogramar más guiado.
- Conflictos horarios y reglas de negocio más visibles para el admin.
- Acciones rápidas desde cada cita:
  - confirmar,
  - completar,
  - reprogramar,
  - cancelar,
  - abrir paciente.

Cuidado:

- No relajar reglas de negocio.
- No romper `AppointmentsBusinessRules`.
- Mantener tests de agenda.

---

### P3 — Rediseñar Documentos clínicos

Motivo: actualmente funcional, pero puede sentirse más administrativo que clínico.

Mejoras sugeridas:

- Cards por archivo con:
  - icono/preview según tipo,
  - categoría,
  - tratamiento asociado,
  - fecha,
  - visibilidad paciente/admin,
  - acciones abrir/descargar/eliminar.
- Empty state premium con CTA de subir documento.
- Flujo de subida más guiado:
  - seleccionar tratamiento,
  - categoría,
  - visibilidad,
  - validación clara.
- Filtros compactos por tratamiento y categoría.

Cuidado:

- No tocar Firebase Storage/rules sin pedido.
- No cambiar estructura de datos sin justificar migración.

---

### P4 — Rediseñar Notificaciones

Motivo: el routing ya se corrigió; falta que el inbox se sienta útil y claro.

Mejoras sugeridas:

- Agrupar/filtrar por tipo:
  - citas,
  - pagos,
  - tratamientos,
  - documentos,
  - simulaciones.
- Estado leído/no leído más visible.
- Acciones rápidas en cada notificación.
- Empty state premium.
- Mejor copy de errores y fallback.

Cuidado:

- No romper `FcmPayloadRouter`.
- Mantener rutas seguras y normalización de payload.

---

### P5 — Estandarizar componentes OCG reutilizables

Motivo: se está repitiendo mucha UI premium local dentro de pantallas grandes.

Crear o consolidar componentes como:

- `OcgPremiumCard`
- `OcgHeroHeader`
- `OcgInfoTile`
- `OcgStatusChip`
- `OcgActionCard`
- `OcgEmptyState` premium extendido
- `OcgSectionHeader`

Beneficio:

- Menos código duplicado.
- Más consistencia visual.
- Menos riesgo de que cada módulo tenga su propio estilo.

Cuidado:

- Hacer extracción gradual, no refactor masivo de una vez.
- Mantener tests en verde después de cada bloque.

---

### P6 — Refactor gradual de archivos gigantes

Archivos grandes detectados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `lib/features/dashboard/presentation/admin_modules_screens.dart`
- `lib/features/dashboard/presentation/patient_home_screen.dart`
- `lib/features/treatment/presentation/widgets/manage_patient_treatment_dialog.dart`
- `lib/features/dashboard/presentation/admin_patients_screen.dart`
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `lib/features/patients/presentation/patient_detail_screen.dart`

Mejora sugerida:

- Extraer widgets internos por módulo:
  - headers,
  - filtros,
  - cards,
  - dialogs,
  - listas,
  - empty/error states.
- Evitar mezclar lógica de layout con reglas de negocio.
- Mantener nombres claros y módulos pequeños.

Cuidado:

- Refactor sin cambios funcionales primero.
- Commit pequeño por archivo/módulo.
- Validar cada paso.

---

### P7 — Estados de carga, error y vacío

Mejora transversal:

- Skeletons consistentes.
- Botones de reintentar.
- Mensajes humanos.
- Estados sin permisos.
- Estados sin conexión o Firebase lento.
- Evitar `null`, `undefined`, IDs técnicos o mensajes crudos.

Prioridad de aplicación:

1. Admin móvil.
2. Detalle de paciente.
3. Agenda.
4. Tratamientos/documentos.
5. Paciente app.

---

### P8 — Limpieza de logs y trazas

Se detectaron varios `print`/`debugPrint` en servicios y repositorios.

Mejora sugerida:

- Crear logger controlado por debug mode.
- Evitar PII en logs.
- Reducir ruido de consola.
- Mantener logs críticos de diagnóstico, pero sanitizados.

Archivos con trazas a revisar:

- `lib/services/firebase/auth_service.dart`
- `lib/services/notifications/fcm_payload_router.dart`
- `lib/services/notifications/fcm_service.dart`
- `lib/features/profile_photo/services/profile_photo_service.dart`
- `lib/features/simulator/providers/simulation_provider.dart`
- `lib/features/simulator/data/repositories/simulation_repository.dart`
- `lib/features/clinical_files/data/repositories/clinical_files_repository.dart`
- `lib/features/clinical_files/services/clinical_files_storage_service.dart`
- `lib/features/payments/data/repositories/payments_repository.dart`

Cuidado:

- No eliminar logs útiles antes de activar PayU/IA/FCM real.
- Preferir sanitizar y condicionar por entorno.

---

### P9 — Tests widget críticos

Agregar/regenerar tests para UX sensible:

- Admin móvil detalle paciente mantiene bottom nav.
- Perfil móvil admin no muestra UID ni nombre duplicado en Datos básicos.
- Simulador embebido no crea scroll anidado.
- Tratamientos → Pagos → Documentos navega correctamente.
- Notificaciones abren sección correcta por rol.
- Eliminar paciente muestra confirmación.
- Empty states principales renderizan CTA correcta.

---

## 4. Orden de ejecución recomendado

Si Jefe pide “continúa mejorando OCG”, sugerir este orden:

1. Tratamientos móvil admin.
2. Agenda móvil admin.
3. Documentos clínicos.
4. Notificaciones.
5. Componentes OCG reutilizables.
6. Refactor gradual de archivos grandes.
7. Limpieza de logs.
8. Tests widget críticos.

---

## 5. Checklist para cada bloque futuro

Antes de cerrar cualquier bloque:

- [ ] Confirmar alcance exacto: admin móvil / desktop / app paciente.
- [ ] No tocar módulos fuera de alcance.
- [ ] Revisar rutas y deep links relacionados.
- [ ] Revisar scroll/navegación/bottom nav.
- [ ] Revisar estados loading/error/empty.
- [ ] Ejecutar `dart format`.
- [ ] Ejecutar `flutter analyze`.
- [ ] Ejecutar tests puntuales.
- [ ] Ejecutar `flutter test` completo si el cambio es sensible.
- [ ] Revisar `git diff` antes de commit.
- [ ] Commit en español, sin prefijos tipo `feat:`/`fix:`.
- [ ] Push a `main` si la validación está limpia.

---

## 6. Nota sobre PayU y Simulador IA

No priorizar validación real de estos dos bloques hasta tener keys/credenciales reales.

Mientras tanto sí se puede trabajar en:

- UI de estados “pendiente de configuración”.
- Mensajes humanos cuando faltan keys.
- Tests de providers/servicios con mocks.
- Documentación de activación humana.

No hacer:

- Cambiar lógica backend PayU sin credenciales.
- Cambiar generación IA o prompts reales sin validar keys.
- Prometer funcionamiento real end-to-end sin credenciales.
