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

- Documentar cada cambio relevante que se implemente en este roadmap o en un log bajo `docs/`, dejando fecha, alcance, archivos tocados, validaciones y commit para que Borlty tenga contexto recuperable en futuras sesiones.
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

Plan detallado creado: [`docs/PLAN_REFACTOR_ARCHIVOS_GIGANTES_OCG.md`](PLAN_REFACTOR_ARCHIVOS_GIGANTES_OCG.md)

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

---

## Registro de implementación — 2026-05-08 — Tratamientos móvil admin / primera mejora

Alcance implementado:

- Se inició el bloque P1 de Tratamientos móvil admin desde el hub embebido del detalle de paciente.
- Se reemplazó el resumen plano de `section=tratamientos` por un hero clínico premium con gradiente OCG, chips de estado y métricas rápidas.
- Se agregaron alertas contextuales del tratamiento principal/activo:
  - saldo pendiente,
  - tratamiento finalizado/cancelado,
  - falta de fecha estimada de finalización,
  - falta de notas clínicas.
- Se agregó una línea de progreso horizontal de etapas clínicas para visualizar la etapa actual sin abrir diálogos.
- Se mantuvo la arquitectura móvil admin existente: sin `Scaffold` nuevo, sin bottom nav duplicada y sin scroll vertical anidado en el detalle.

Archivos tocados:

- `lib/features/patients/presentation/patient_detail_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/patients/presentation/patient_detail_screen.dart`
- `flutter analyze`
- `flutter test test/features/patients/patient_detail_workspace_test.dart test/features/patients/patient_treatment_tab_multitreatment_test.dart test/features/patients/patient_payments_tab_effective_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de pacientes/tratamientos/pagos: verde.
- Suite completa `flutter test`: verde.

Commit:

- `mejorar tratamientos movil admin con hero y progreso clinico`.

---

## Registro de implementación — 2026-05-08 — Tratamientos móvil admin / acciones contextuales

Alcance implementado:

- Se continuó el bloque P1 de Tratamientos móvil admin con acciones contextuales reales dentro del hub de Tratamientos.
- Se agregó un panel de acciones del tratamiento activo con:
  - actualizar etapa mediante `UpdateStageDialog`,
  - editar tratamiento mediante `ManagePatientTreatmentDialog`,
  - crear nuevo tratamiento,
  - abrir pagos,
  - abrir documentos clínicos.
- Se agregó un CTA para crear el primer tratamiento cuando el hub no tenga tratamiento activo/principal.
- Se agregó alerta clínica de “sin próxima cita” cuando el paciente no tiene seguimiento futuro dentro del detalle móvil admin.
- Se corrigió el modo móvil de `PatientTreatmentTab` para respetar `scrollable: false`; así, cuando se use embebido, no crea un `SingleChildScrollView` vertical propio.
- Se mantuvo la navegación dentro del módulo, sin duplicar `Scaffold`, sin duplicar bottom nav y sin separar pagos/documentos del contexto de Tratamientos.

Archivos tocados:

- `lib/features/patients/presentation/patient_detail_screen.dart`
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/patients/presentation/patient_detail_screen.dart lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `flutter analyze`
- `flutter test test/features/patients/patient_detail_workspace_test.dart test/features/patients/patient_treatment_tab_multitreatment_test.dart test/features/patients/patient_payments_tab_effective_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de pacientes/tratamientos/pagos: verde.
- Suite completa `flutter test`: verde.

Commit:

- `agregar acciones contextuales a tratamientos movil admin`.

---

## Registro de implementación — 2026-05-08 — Tratamientos móvil admin / cards secundarias

Alcance implementado:

- Se continuó el bloque P1 de Tratamientos móvil admin refinando las cards de tratamientos principal/secundarios.
- Se reemplazó la card plana de cada tratamiento por una card clínica más clara con:
  - icono y color de estado,
  - chips de principal/secundario, estado y etapa,
  - barra de progreso clínico por etapa,
  - métricas compactas de inicio, valor, saldo pendiente y próxima fecha de control,
  - bloque visual de notas clínicas cuando existan,
  - acciones rápidas por tratamiento: etapa, editar, pagos y notas.
- Las acciones siguen dentro del hub móvil de Tratamientos y reutilizan los diálogos existentes sin alterar lógica financiera ni backend.
- Se mantuvo el scroll principal único del detalle móvil admin.

Archivos tocados:

- `lib/features/patients/presentation/patient_detail_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/patients/presentation/patient_detail_screen.dart`
- `flutter analyze`
- `flutter test test/features/patients/patient_detail_workspace_test.dart test/features/patients/patient_treatment_tab_multitreatment_test.dart test/features/patients/patient_payments_tab_effective_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de pacientes/tratamientos/pagos: verde.
- Suite completa `flutter test`: verde.

Commit:

- `mejorar cards de tratamientos movil admin`.

---

## Registro de implementación — 2026-05-08 — Agenda móvil admin / header operativo

Alcance implementado:

- Se inició el bloque P2 de Agenda móvil admin con un cambio agrupado, siguiendo la regla de menos commits y más avance por bloque funcional.
- Se agregó un header operativo premium exclusivo para móvil/admin con:
  - fecha seleccionada,
  - próxima cita activa,
  - métricas rápidas de total del día, pendientes, incidencias, completadas y próximas,
  - accesos rápidos a Hoy, Mañana, Historial y Nueva cita.
- El botón Nueva cita reutiliza `AdminAppointmentsScreen.showCreateDialog` y respeta las reglas de negocio existentes.
- Los accesos Hoy/Mañana actualizan `selectedAppointmentsDateProvider` y devuelven al tab Hoy sin cambiar arquitectura.
- No se tocó desktop admin, `AppointmentsBusinessRules`, providers, Firebase, FCM ni lógica de agenda.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `flutter analyze`
- `flutter test test/appointments_business_rules_test.dart test/features/admin/admin_desktop_validation_matrix_test.dart test/features/admin/admin_modules_responsive_base_test.dart test/features/admin/admin_modules_tiers_smoke_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de agenda/admin: verde.
- Suite completa `flutter test`: verde.

Commit:

- `mejorar header operativo de agenda movil admin`.

---

## Registro de implementación — 2026-05-08 — Simulador móvil admin / botón Nueva funcional

Alcance implementado:

- Se corrigió el botón `+ Nueva` del encabezado de `Última simulación` dentro del detalle móvil admin del paciente.
- El botón ahora abre realmente el flujo embebido de nueva simulación, limpia cualquier simulación histórica abierta y enfoca el bloque activo para iniciar con `Paso 1: subir foto original`.
- Las acciones principales de cámara/galería también marcan explícitamente que se está creando una nueva simulación para mantener consistente el estado visual.
- Al abrir una simulación del historial se desactiva el modo de creación nueva, evitando mezclar una simulación existente con el flujo nuevo.
- Se agregó test widget específico para impedir regresión del botón `Nueva`.

Archivos tocados:

- `lib/features/patients/presentation/tabs/patient_simulator_tab.dart`
- `test/features/simulator/simulator_mobile_flow_test.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/patients/presentation/tabs/patient_simulator_tab.dart test/features/simulator/simulator_mobile_flow_test.dart`
- `flutter test test/features/simulator/simulator_mobile_flow_test.dart`
- `flutter analyze`
- `flutter test`

Resultado:

- Test focalizado de simulador móvil: verde.
- `flutter analyze`: verde, sin issues.
- Suite completa `flutter test`: verde.

Commit:

- `hacer funcional nueva simulacion en detalle paciente`.

---

## Registro de implementación — 2026-05-08 — Agenda móvil admin / cards operativas y acciones rápidas

Alcance implementado:

- Se hizo un avance amplio del bloque P2 de Agenda móvil admin sobre la vista diaria, mensual e historial.
- Se reemplazaron las cards planas de citas por cards operativas premium reutilizadas en Hoy, detalle mensual e historial:
  - icono por estado,
  - chip de estado fuerte,
  - hora/tipo/duración visibles,
  - hint operativo según estado,
  - indicador de incidencia,
  - chip de auto-agendado cuando aplique,
  - bloque visual para notas clínicas.
- Se agregaron acciones rápidas más completas en cada cita activa/confirmada:
  - abrir Perfil,
  - confirmar,
  - completar,
  - reprogramar,
  - marcar `No asistió`,
  - cancelar.
- Se agregó diálogo seguro para marcar inasistencia antes de escribir estado `noAsistio`.
- Se mejoraron empty states móviles de Hoy, Mes e Historial con copy accionable y CTA para crear cita cuando aplica.
- Se mantuvieron `AppointmentsBusinessRules`, providers, Firebase, FCM, desktop shell y reglas de creación/reprogramación intactas.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `flutter analyze`
- `flutter test test/appointments_business_rules_test.dart test/features/admin/admin_desktop_validation_matrix_test.dart test/features/admin/admin_modules_responsive_base_test.dart test/features/admin/admin_modules_tiers_smoke_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de agenda/admin: verde.
- Suite completa `flutter test`: verde.

Commit:

- `mejorar cards y acciones de agenda movil admin`.

---

## Registro de implementación — 2026-05-08 — Agenda móvil admin / flujo guiado de crear y reprogramar

Alcance implementado:

- Se avanzó el bloque P2 de Agenda móvil admin sobre el flujo de creación y reprogramación de citas.
- En `Nueva cita` se agregó una ficha visual del paciente seleccionado con nombre/teléfono y acción clara para cambiarlo.
- Se agregó resumen operativo de disponibilidad del día:
  - cantidad de horarios disponibles,
  - cantidad de horarios bloqueados,
  - horario seleccionado,
  - estado visual “listo para agendar” o “elige un horario disponible”.
- Se agregó leyenda visual para diferenciar seleccionado, disponible y bloqueado/no laborable.
- Los chips de horario ahora muestran icono de disponible/bloqueado y limpian errores al seleccionar un horario válido.
- En `Reprogramar cita` se agregó resumen equivalente de disponibilidad, leyenda visual y chips de horario con iconos, manteniendo exclusión de la cita original para no crear falso conflicto.
- Se mantuvieron intactas las validaciones de `AppointmentsBusinessRules`, los providers, Firebase, FCM y el comportamiento desktop.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `flutter analyze`
- `flutter test test/appointments_business_rules_test.dart test/features/admin/admin_desktop_validation_matrix_test.dart test/features/admin/admin_modules_responsive_base_test.dart test/features/admin/admin_modules_tiers_smoke_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados agenda/admin: verdes.
- Suite completa `flutter test`: verde.

Commit:

- `e6b4d29` — `guiar creacion y reprogramacion en agenda movil admin`

---

## Registro de cierre — 2026-05-08 — P2 Agenda móvil admin cerrada

Alcance implementado para cerrar P2:

- Se completó el rediseño operativo de Agenda móvil admin con filtros rápidos reales dentro de la vista diaria:
  - Día,
  - Mañana,
  - Pendientes,
  - Vencidas,
  - Históricas.
- Los filtros muestran conteo inmediato y permiten revisar operación clínica sin saltar manualmente entre calendario/historial.
- El resumen del día y la lista de cards responden al filtro activo.
- Se conservaron las vistas de Mes e Historial, las cards premium, acciones rápidas, flujo guiado de crear/reprogramar y validaciones de reglas de negocio ya implementadas en commits anteriores.
- Se mantuvieron intactos `AppointmentsBusinessRules`, providers, rutas, FCM, Firebase y comportamiento desktop.

Estado P2:

- P2 queda cerrada funcionalmente para móvil admin según el roadmap actual:
  - header premium,
  - filtros rápidos,
  - cards visuales por estado,
  - empty states,
  - crear/reprogramar guiado,
  - conflictos/reglas visibles,
  - acciones rápidas por cita.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `flutter analyze`

Commit:

- `9cf21a0` — `cerrar agenda movil admin con filtros rapidos`

---

## Registro de implementación — 2026-05-08 — Inicio P3 Documentos clínicos / expediente premium

Alcance implementado:

- Se inició P3 de Documentos clínicos dentro del detalle móvil admin del paciente.
- Se agregó hero/resumen premium de expediente clínico digital con métricas:
  - total de archivos,
  - visibles para paciente,
  - vinculados a tratamiento,
  - conteo imágenes/PDF.
- Se rediseñaron las cards de documentos clínicos con:
  - icono y color por tipo/categoría,
  - categoría,
  - tratamiento asociado,
  - fecha,
  - tamaño,
  - visibilidad paciente/admin,
  - notas clínicas destacadas,
  - acciones Abrir, Descargar y Desactivar.
- Se hizo más guiado el modal de subida:
  - ficha de tratamiento base,
  - helper de nombre visible,
  - iconografía en categoría/notas,
  - explicación de asociación a tratamiento,
  - explicación de visibilidad para paciente.
- Se agregó confirmación antes de desactivar un documento para evitar bajas accidentales.
- Se mantuvieron intactos Storage, Firestore, reglas, estructura de datos y providers.

Archivos tocados:

- `lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart`
- `flutter analyze`
- `flutter test test/features/clinical_files/clinical_file_model_test.dart test/features/clinical_files/clinical_files_repository_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de clinical files: verdes.
- Suite completa `flutter test`: verde.

Commit:

- `5abf714` — `iniciar documentos clinicos movil admin premium`


---

## Registro de cierre — 2026-05-08 — P3 Documentos clínicos cerrada

Alcance implementado para cerrar P3:

- Se completó el rediseño de Documentos clínicos en móvil admin con filtros compactos adicionales por visibilidad:
  - Todos,
  - Paciente,
  - Solo admin.
- La lista filtra ahora por tratamiento, categoría y visibilidad, y ordena los documentos por fecha de subida descendente.
- El empty state premium ahora incluye CTA directo para subir documento y acción para limpiar filtros cuando no hay resultados por criterios activos.
- El flujo de subida ahora permite seleccionar explícitamente el tratamiento asociado dentro del modal, además de categoría, visibilidad, nombre visible y notas.
- Se reforzó la claridad clínica sin tocar Storage, Firestore rules, metadata, repositorios ni estructura de datos.

Estado P3:

- P3 queda cerrada funcionalmente según el roadmap actual:
  - cards por archivo con icono/tipo, categoría, tratamiento, fecha, visibilidad y acciones,
  - empty state premium con CTA,
  - flujo de subida guiado con selección de tratamiento/categoría/visibilidad,
  - filtros compactos por tratamiento, categoría y visibilidad.

Archivos tocados:

- `lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart`
- `flutter analyze`
- `flutter test test/features/clinical_files/clinical_file_model_test.dart test/features/clinical_files/clinical_files_repository_test.dart`
- `flutter test`

Resultado:

- `flutter analyze`: verde, sin issues.
- Tests focalizados de clinical files: verdes.
- Suite completa `flutter test`: verde.

Commit:

- aea8e40

---

## Registro de implementación — 2026-05-08 — Inicio P4 Notificaciones / inbox operativo admin

Alcance implementado:

- Se inició P4 de Notificaciones con rediseño del inbox admin.
- Se agregó hero premium de centro de notificaciones con métricas:
  - total,
  - no leídas,
  - recibidas hoy.
- Se agregaron filtros compactos con conteos por tipo:
  - Todas,
  - No leídas,
  - Citas,
  - Pagos,
  - Tratamientos,
  - Docs,
  - Simulador.
- Se rediseñaron las cards con:
  - icono/color por tipo de notificación,
  - chip de leída/nueva,
  - chip de categoría,
  - fecha,
  - destino cuando hay ruta,
  - CTA explícito “Leer y abrir” / “Abrir destino”.
- Se mejoraron empty states para inbox vacío y filtros sin resultados, incluyendo acción de limpiar filtro.
- Se mantuvo intacto `FcmPayloadRouter`, `NotificationNavigationService`, providers, rutas seguras y normalización de payload.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_notifications_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_notifications_screen.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados de notificaciones/routing y suite completa `flutter test`.

Commit:

- aea8e40

---

## Registro de implementación — 2026-05-08 — P4 Notificaciones / paciente premium y cierre funcional

Alcance implementado:

- Se extendió P4 al inbox de paciente para dejar la experiencia consistente con admin.
- Se agregó hero premium del inbox paciente con métricas:
  - total,
  - no leídas,
  - recibidas hoy.
- Se agregaron filtros compactos por tipo y estado:
  - Todas,
  - No leídas,
  - Citas,
  - Pagos,
  - Tratamiento,
  - Docs,
  - Simulador.
- Se rediseñaron cards de paciente con:
  - icono/color por tipo,
  - estado leída/no leída,
  - categoría,
  - fecha,
  - destino de navegación cuando existe,
  - CTA “Leer y abrir” / “Abrir”.
- Se mejoró el copy de error con empty state más claro y fallback visual.
- Se mantuvo intacto `FcmPayloadRouter`, `NotificationNavigationService`, providers, rutas seguras y normalización de payload.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_notifications_screen.dart`
- `lib/features/notifications/presentation/patient_notifications_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_notifications_screen.dart lib/features/notifications/presentation/patient_notifications_screen.dart`
- `flutter analyze`
- `flutter test test/services/notifications/fcm_payload_router_test.dart test/services/notifications/fcm_service_test.dart`
- `flutter test`

Estado P4:

- Cerrado funcionalmente para rediseño UI/UX de inbox admin/paciente, filtros, estados leído/no leído, acciones y empty/error states.

Commit:

- 3081ac0

---

## Registro de implementación — 2026-05-08 — Inicio P5 Componentes OCG reutilizables

Alcance implementado:

- Se inició P5 con extracción gradual de UI premium repetida, sin refactor masivo.
- Se creó `OcgHeroHeader` para headers premium con:
  - icono principal,
  - título,
  - subtítulo,
  - gradiente configurable,
  - métricas reutilizables.
- Se creó `OcgHeroMetric` para métricas compactas dentro de headers premium.
- Se creó `OcgStatusPill` para chips reutilizables de estado/categoría/fecha/destino.
- Se creó `OcgPremiumEmptyState` como empty state premium extendido con CTA opcional.
- Se aplicaron los componentes nuevos en:
  - inbox admin de notificaciones,
  - inbox paciente de notificaciones.
- Se eliminaron widgets locales duplicados de P4, manteniendo la misma experiencia visual.

Cuidado aplicado:

- Extracción gradual únicamente sobre Notificaciones para reducir riesgo.
- No se tocaron providers, routing, `FcmPayloadRouter`, `NotificationNavigationService`, Firebase ni estructura de datos.
- No se hizo refactor masivo de módulos grandes.

Archivos tocados:

- `lib/shared/widgets/ocg_premium.dart`
- `lib/features/dashboard/presentation/admin_notifications_screen.dart`
- `lib/features/notifications/presentation/patient_notifications_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/shared/widgets/ocg_premium.dart lib/features/dashboard/presentation/admin_notifications_screen.dart lib/features/notifications/presentation/patient_notifications_screen.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados de notificaciones y suite completa `flutter test`.

Commit:

- a79517b

---

## Registro de implementación — 2026-05-08 — Cierre P5 e inicio P6

Alcance P5 implementado:

- Se amplió `lib/shared/widgets/ocg_premium.dart` con componentes reutilizables adicionales:
  - `OcgPremiumCard`,
  - `OcgSectionHeader`,
  - `OcgInfoTile`,
  - `OcgActionCard`,
  - `OcgStatusPill` con defaults reutilizables,
  - `OcgPremiumEmptyState` con acción primaria/secundaria opcional.
- Se aplicaron componentes P5 fuera de Notificaciones, específicamente en Documentos clínicos admin:
  - hero/resumen del expediente,
  - métricas compactas,
  - empty state premium con limpiar filtros/subir documento,
  - chips de archivo,
  - card premium de documento.
- Con esto P5 queda cerrado funcionalmente como extracción gradual: componentes creados, aplicados en dos módulos reales y sin refactor masivo.

Alcance P6 iniciado:

- Se inició refactor gradual de archivo gigante `admin_appointments_screen.dart`.
- Se extrajeron helpers puros de formato/labels de agenda a:
  - `lib/features/dashboard/presentation/admin_appointments_formatters.dart`
- Helpers extraídos:
  - formato de fecha,
  - formato de fecha/hora,
  - dayKey para disponibilidad,
  - label de tipo de cita,
  - labels/colores de citas automáticas.
- Se mantuvieron enums y reglas internas de agenda dentro del archivo original para minimizar riesgo.

Cuidado aplicado:

- No se cambiaron reglas de negocio de agenda.
- No se tocó `AppointmentsBusinessRules`.
- No se modificaron providers, Firebase, FCM, PayU ni routing.
- P6 quedó iniciado como refactor sin cambios funcionales.

Archivos tocados:

- `lib/shared/widgets/ocg_premium.dart`
- `lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart`
- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `lib/features/dashboard/presentation/admin_appointments_formatters.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format` en archivos tocados
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados de agenda/documentos/notificaciones y suite completa `flutter test`.

Commit:

- 239cea4

---

## Registro de implementación — 2026-05-08 — P6 Agenda / helpers de filtros y reglas visuales

Alcance implementado:

- Se continuó P6 con refactor gradual y seguro del archivo gigante `admin_appointments_screen.dart`.
- Se extrajeron enums y predicados puros de agenda a:
  - `lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- Elementos extraídos:
  - `AgendaFilter`,
  - `AgendaInnerTab`,
  - `AgendaDayQuickFilter`,
  - `isLostAppointment`,
  - `isAgendaIncident`,
  - `isAgendaHistoryCandidate`.
- Se mantuvo en `admin_appointments_screen.dart` la composición visual, diálogos y lógica con estado para evitar una extracción riesgosa.

Cuidado aplicado:

- Refactor sin cambios funcionales.
- No se tocó `AppointmentsBusinessRules`.
- No se cambiaron providers, Firestore, disponibilidad, notificaciones ni creación/reprogramación de citas.
- Los helpers quedan con nombres públicos y claros para permitir futuras extracciones por widgets/módulos.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados de agenda y suite completa `flutter test`.

Commit:

- 6abfac3

---

## Registro de implementación — 2026-05-08 — P6 Agenda / filtros rápidos extraídos

Alcance implementado:

- Se continuó P6 con otro corte pequeño y seguro en agenda admin.
- Se movieron helpers puros de filtros rápidos desde `admin_appointments_screen.dart` a `admin_appointments_agenda_helpers.dart`:
  - `appointmentsForDay`,
  - `quickFilterLabel`,
  - `quickFilterIcon`,
  - `quickFilterCount`,
  - `quickFilteredItems`.
- La pantalla conserva estado, UI, providers y acciones; solo consume helpers externos.
- Se redujo el tamaño del archivo principal sin alterar comportamiento.

Cuidado aplicado:

- Sin mover diálogos, callbacks ni lógica con `ref/context`.
- Sin cambiar creación, reprogramación, disponibilidad, filtros visuales ni acciones.
- Sin tocar `AppointmentsBusinessRules`.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados de agenda/admin y suite completa `flutter test`.

Commit:

- 3d8a4f7

---

## Registro de implementación — 2026-05-08 — P6 Agenda / helpers visuales de estado

Alcance implementado:

- Se continuó P6 con un corte pequeño adicional sobre agenda admin.
- Se movieron helpers visuales/puros de estado a `admin_appointments_agenda_helpers.dart`:
  - `appointmentStatusUi`,
  - `agendaStatusIcon`,
  - `agendaOperationalHint`.
- `admin_appointments_screen.dart` conserva widgets, callbacks, navegación y acciones con `context/ref`.
- Se evita mezclar refactor visual con reglas de negocio o efectos externos.

Cuidado aplicado:

- Sin tocar creación, edición, reprogramación, cancelación ni acciones de estado.
- Sin cambios en providers ni repositorios.
- Sin tocar `AppointmentsBusinessRules`.
- El cambio es import/uso de helpers puros ya validados por analyzer.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados y suite completa.

Commit:

- 94ae863

---

## Registro de implementación — 2026-05-08 — P6 Agenda / helpers de historial y calendario

Alcance implementado:

- Se continuó P6 con extracción pura y reversible en agenda admin.
- Se movieron helpers de calendario/historial a `admin_appointments_agenda_helpers.dart`:
  - `agendaMonthLabel`,
  - `historyItemsForAgenda`,
  - `historyCountByFilter`,
  - `filterHistoryItems`.
- Se eliminó duplicación de labels mensuales usada por vista Mes e Historial.
- `admin_appointments_screen.dart` conserva el estado local (`_historyFilter`, `_historyPage`, `_monthCursor`) y solo delega cálculo puro.

Cuidado aplicado:

- Sin tocar callbacks de UI ni navegación.
- Sin mover `setState`, `ref`, `context` ni diálogos.
- Sin cambiar reglas de negocio, providers ni repositorios.
- Paginación de historial mantiene `pageSize = 12`.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart lib/features/dashboard/presentation/admin_appointments_agenda_helpers.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados y suite completa.

Commit:

- 35c7b3b

---

## Registro de implementación — 2026-05-08 — Corrección overflow móvil Agenda admin / Tab Hoy

Problema corregido:

- En móvil, el tab `AgendaInnerTab.hoy` podía producir `RenderFlex overflowed by 48 pixels on the bottom`.
- El overflow ocurría dentro de `_buildTodayAgenda`, en la rama móvil, porque el cuerpo del tab era una `Column` con filtros + resumen + `Expanded` para timeline dentro de un alto muy limitado por el header premium, tabs y `AnimatedSwitcher`.
- En pantallas pequeñas el bloque de filtros/resumen consumía más alto del disponible antes del `Expanded`, dejando el `Column` sin espacio suficiente.

Solución aplicada:

- La rama móvil de `_buildTodayAgenda` ahora usa un `ListView` vertical como scroll real del contenido del tab Hoy.
- Se mantienen filtros rápidos horizontales, resumen y cards dentro de un único scroll natural del tab.
- Las cards se renderizan como hijos normales dentro de una `Column` interna no scrollable, evitando lista vertical anidada.
- La rama desktop permanece con su layout original `Column` + `Row` + `Expanded` para no alterar desktop.

Cuidado aplicado:

- No se agregaron alturas arbitrarias.
- No se usó `ClipRect` ni ocultamiento visual.
- No se ocultó contenido.
- No se redujeron fuentes de forma artificial.
- No se tocaron providers, reglas de negocio, `AppointmentsBusinessRules`, diálogos, tabs, navegación, `AdminMobileShell` ni bottom nav.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados y suite completa.

Commit:

- Pendiente de hash al confirmar cambios.

---

## Registro de implementación — 2026-05-08 — Agenda móvil completamente scrolleable / Historial sin overflow

Problema corregido:

- Tras corregir el tab Hoy, Flutter reportó otro `RenderFlex overflowed` en móvil dentro de `AgendaInnerTab.historial`.
- La causa era equivalente: la sección móvil de Agenda seguía usando una estructura raíz `Column` con header + tabs + `Expanded` para el tab activo. En pantallas pequeñas, el header premium dejaba un alto muy reducido para el tab (`h<=243.4`).
- En Historial, la rama móvil de `_buildHistoryAgenda` era otra `Column` con panel de filtros + `Expanded` para la lista, y el panel de filtros ya podía superar el alto disponible.

Solución aplicada:

- La sección móvil completa de Agenda clínica ahora es un `ListView` vertical único: header premium, tabs y contenido del tab participan en el mismo scroll natural.
- La rama móvil de `Historial` ya no usa `Expanded` ni lista vertical propia; renderiza el panel de filtros y las cards como contenido normal dentro del scroll principal.
- La rama móvil de `Hoy` también queda como contenido no-scrollable interno, para evitar scroll vertical anidado.
- La tarjeta/header marrón de Agenda clínica elimina el margen superior interno anterior para que el diseño arranque desde arriba del área móvil disponible.
- Desktop conserva su estructura original con `Expanded` y listas internas dentro del panel de 720px.

Cuidado aplicado:

- Sin `SizedBox(height: 1000)` ni alturas arbitrarias.
- Sin `ClipRect` ni ocultar overflow.
- Sin esconder contenido.
- Sin tocar providers, diálogos, navegación, `AdminMobileShell`, bottom nav, `AppointmentsBusinessRules`, Firebase ni FCM.

Archivos tocados:

- `lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `docs/ROADMAP_MEJORAS_UI_FUNCIONAL_OCG.md`

Validaciones ejecutadas:

- `dart format lib/features/dashboard/presentation/admin_appointments_screen.dart`
- `flutter analyze`

Pendiente antes de commit:

- Tests focalizados y suite completa.

Commit:

- Pendiente de hash al confirmar cambios.
