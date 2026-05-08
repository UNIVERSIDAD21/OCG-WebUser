# Plan de refactor seguro — archivos grandes OCG-WebUser

> Fecha: 2026-05-08  
> Repo: `OCG-WebUser/ocg_proyect`  
> Objetivo: reducir archivos gigantes sin romper flujos clínicos, navegación, Firebase, pagos, citas, simulador ni UI móvil/admin ya estabilizada.

---

## 1. Principios obligatorios de refactor

Este refactor debe ser **gradual, verificable y reversible**. No se debe hacer una extracción masiva en un solo commit.

Reglas:

1. **Un commit por bloque funcional estable**, no por microcambio, pero tampoco mega-commits mezclando módulos.
2. **No mover lógica con efectos externos** al principio:
   - `ref.read/watch`,
   - `context.go/pop/showDialog`,
   - writes a repositorios,
   - Firebase/Functions/Storage,
   - navegación,
   - pagos,
   - FCM.
3. Primero extraer:
   - enums,
   - helpers puros,
   - formatters,
   - view models simples,
   - widgets stateless sin estado externo.
4. Después extraer widgets con callbacks inyectados.
5. Solo al final considerar separar controllers/notifiers si hay tests suficientes.
6. Cada bloque debe pasar:
   - `dart format <archivos>`
   - `flutter analyze`
   - tests focalizados del módulo
   - `flutter test` completo antes de push.
7. Si falla una prueba no relacionada, revisar antes de asumir flaky.
8. No usar `push --force`.
9. No cambiar comportamiento visual/funcional salvo que el bloque lo declare explícitamente.

---

## 2. Inventario actual de archivos grandes

Medición tomada con `wc -l` sobre `lib/**/*.dart`.

| Prioridad | Archivo | Líneas aprox. | Riesgo | Motivo |
|---|---:|---:|---|---|
| 1 | `lib/features/dashboard/presentation/admin_appointments_screen.dart` | 3834 | Alto | Agenda admin: citas, diálogos, acciones, calendario, historial. Ya inició P6. |
| 2 | `lib/features/dashboard/presentation/admin_modules_screens.dart` | 3154 | Alto | Agrega muchos módulos admin; riesgo por layout desktop/móvil. |
| 3 | `lib/features/patients/presentation/patient_detail_screen.dart` | 2753 | Alto | Detalle clínico admin móvil/web; shell, tabs, acciones críticas. |
| 4 | `lib/features/dashboard/presentation/patient_home_screen.dart` | 2531 | Alto | Home paciente y navegación interna; sensible por rutas/notificaciones. |
| 5 | `lib/features/treatment/presentation/widgets/manage_patient_treatment_dialog.dart` | 2322 | Alto | Dialog complejo de tratamiento; validaciones clínicas/financieras. |
| 6 | `lib/features/dashboard/presentation/admin_patients_screen.dart` | 2270 | Medio/Alto | Bandeja de pacientes, filtros, responsive, navegación. |
| 7 | `lib/features/patients/presentation/tabs/patient_treatment_tab.dart` | 2250 | Alto | Tratamientos dentro de detalle; pagos/documentos/etapas. |
| 8 | `lib/features/dashboard/presentation/admin_dashboard_screen.dart` | 2059 | Medio | Dashboard/admin KPIs; riesgo de layout, menor riesgo de datos. |
| 9 | `lib/features/payments/presentation/patient_payments_screen.dart` | 1655 | Alto | Pagos paciente/PayU; sensible por dinero. |
| 10 | `lib/features/dashboard/presentation/patient_appointments_screen.dart` | 1567 | Medio/Alto | Citas paciente; reglas/estados/routing. |
| 11 | `lib/features/auth/presentation/login_screen.dart` | 1548 | Alto | Auth; no romper login/registro/forgot. |
| 12 | `lib/features/patients/presentation/tabs/patient_payments_tab.dart` | 1177 | Alto | Pagos admin/paciente embebido; dinero y permisos. |
| 13 | `lib/features/payments/data/repositories/payments_repository.dart` | 1013 | Muy alto | Repositorio de pagos; refactor solo con tests fuertes. |
| 14 | `lib/features/patients/presentation/tabs/patient_clinical_history_tab.dart` | 958 | Medio/Alto | Documentos clínicos; Storage/visibilidad. |

> Nota: archivos de 500–900 líneas también pueden limpiarse después, pero el primer plan debe atacar estos 14 porque concentran el riesgo y el mantenimiento.

---

## 3. Orden recomendado por seguridad

### Fase A — Seguir con archivos de UI ya estabilizados

Objetivo: bajar tamaño sin tocar reglas de negocio.

1. `admin_appointments_screen.dart`
2. `admin_dashboard_screen.dart`
3. `admin_patients_screen.dart`
4. `patient_clinical_history_tab.dart`

Por qué primero:

- Ya hay patrón iniciado en P6.
- Se pueden extraer helpers/widgets sin tocar backend.
- Tests de admin responsive y agenda ya existen y pasan.

### Fase B — Refactor de pantallas clínicas grandes

5. `patient_detail_screen.dart`
6. `patient_treatment_tab.dart`
7. `patient_home_screen.dart`
8. `patient_appointments_screen.dart`

Por qué después:

- Tienen más interacción entre tabs, rutas y shell móvil.
- Requieren preservar `AdminMobileShell`, `PatientHomeScreen(initialSection: ...)`, bottom nav y scroll principal.

### Fase C — Dialogs complejos y pagos UI

9. `manage_patient_treatment_dialog.dart`
10. `patient_payments_screen.dart`
11. `patient_payments_tab.dart`
12. `login_screen.dart`

Por qué después:

- Tienen formularios, validaciones y flujos sensibles.
- Se debe extraer primero UI pasiva; validadores/submit quedan intactos hasta el final.

### Fase D — Repositorios/datos

13. `payments_repository.dart`

Por qué último:

- Es dinero y persistencia.
- Solo se toca cuando haya tests de cobertura específica y snapshot claro del comportamiento.

### Fase E — Agregador admin grande

14. `admin_modules_screens.dart`

Puede abordarse en paralelo a Fase A/B si se limita a separar módulos visuales, pero no mezclarlo con cambios en pantallas internas.

---

## 4. Plan detallado por archivo

## 4.1 `admin_appointments_screen.dart`

Estado: P6 ya iniciado. Bajó aprox. a 3834 líneas.

Ya extraído:

- `admin_appointments_formatters.dart`
- `admin_appointments_agenda_helpers.dart`
  - enums/predicados,
  - filtros rápidos,
  - estado visual,
  - historial/calendario.

Siguiente extracción segura:

1. Crear `admin_appointments_agenda_widgets.dart`.
2. Mover solo widgets stateless sin `ref/context` crítico:
   - pill de agenda,
   - cards visuales si reciben callbacks,
   - filter chips si reciben `selected/onChanged/counts`,
   - empty states de agenda.
3. Crear `admin_appointments_dialog_helpers.dart` solo para widgets internos de diálogo, no submit.

No mover todavía:

- `_showRescheduleDialog`,
- `_showCancelDialog`,
- `_showNoShowDialog`,
- `_onCompletarCitaConDictamen`,
- `_handleStatusAction`,
- `_visibleSlotsForDay` si depende de reglas/availability.

Meta realista:

- Bajar de 3834 a 2800–3000 líneas sin tocar comportamiento.

Validaciones:

- `flutter analyze`
- `flutter test test/appointments_business_rules_test.dart`
- `flutter test test/features/admin/admin_modules_tiers_smoke_test.dart test/features/admin/admin_modules_responsive_base_test.dart`
- `flutter test`

---

## 4.2 `admin_modules_screens.dart`

Problema:

- Archivo agregador de módulos admin, probablemente mezcla layout, widgets y secciones.

Extracción segura:

1. Crear carpeta:
   - `lib/features/dashboard/presentation/admin_modules/`
2. Separar por módulo visual:
   - `admin_module_shell.dart`
   - `admin_module_cards.dart`
   - `admin_module_empty_states.dart`
   - `admin_module_metrics.dart`
3. Mantener en el archivo original solo composición/routing principal.

No mover:

- Providers compartidos.
- Navegación global.
- Selección de módulo si está acoplada al shell.

Meta:

- Bajar de 3154 a 1600–2000 líneas.

Validaciones:

- Tests admin desktop/matriz:
  - `admin_desktop_validation_matrix_test.dart`
  - `admin_desktop_modules_alignment_test.dart`
  - `admin_modules_responsive_base_test.dart`
  - `admin_modules_tiers_smoke_test.dart`
- Suite completa.

---

## 4.3 `patient_detail_screen.dart`

Problema:

- Pantalla crítica: detalle paciente, admin móvil, tabs, acciones Editar/Eliminar, scroll principal.

Extracción segura:

1. Crear carpeta:
   - `lib/features/patients/presentation/detail/`
2. Extraer widgets visuales:
   - `patient_detail_header.dart`
   - `patient_detail_mobile_profile_card.dart`
   - `patient_detail_action_buttons.dart`
   - `patient_detail_section_tabs.dart`
   - `patient_detail_summary_cards.dart`
3. Inyectar callbacks desde `patient_detail_screen.dart`:
   - `onEdit`,
   - `onDelete`,
   - `onOpenPayments`,
   - `onOpenAppointments`,
   - `onOpenDocuments`.

No mover:

- `AdminMobileShell` integration.
- Scroll principal.
- `context.go`/routing.
- Delete confirmation.
- Providers.

Meta:

- Bajar de 2753 a 1700–2000 líneas.

Validaciones:

- `patient_detail_workspace_test.dart`
- tests de pacientes/tratamientos/pagos.
- Suite completa.

---

## 4.4 `patient_home_screen.dart`

Problema:

- Home paciente mezcla secciones, navegación interna y contenido por tabs.

Extracción segura:

1. Crear carpeta:
   - `lib/features/dashboard/presentation/patient_home/`
2. Separar secciones:
   - `patient_home_header.dart`
   - `patient_home_treatment_section.dart`
   - `patient_home_appointments_section.dart`
   - `patient_home_payments_section.dart`
   - `patient_home_documents_section.dart`
   - `patient_home_notifications_entry.dart`
3. Mantener `initialSection` y bottom navigation intactos.

No mover:

- Normalización de secciones/rutas.
- Integración con notificaciones.
- Estado de sección activa.

Meta:

- Bajar de 2531 a 1500–1800 líneas.

Validaciones:

- FCM payload/router tests.
- Widget tests de login/home si aplican.
- Suite completa.

---

## 4.5 `manage_patient_treatment_dialog.dart`

Problema:

- Dialog muy grande; sensible por tratamiento, validación, subtipo, etapa, pagos.

Extracción segura:

1. Crear carpeta:
   - `lib/features/treatment/presentation/widgets/manage_treatment/`
2. Extraer UI pasiva:
   - `treatment_type_selector.dart`
   - `treatment_subtype_selector.dart`
   - `treatment_financial_fields.dart`
   - `treatment_stage_selector.dart`
   - `treatment_notes_field.dart`
   - `treatment_dialog_summary.dart`
3. Extraer modelos UI puros si existen:
   - labels,
   - iconos,
   - colors,
   - copy.

No mover inicialmente:

- `_submit`,
- validación final,
- llamadas a repositorios,
- sincronización con payments,
- lógica de tratamiento principal.

Meta:

- Bajar de 2322 a 1300–1600 líneas.

Validaciones:

- `manage_patient_treatment_dialog_test.dart`
- treatment repository/model tests.
- Suite completa.

---

## 4.6 `admin_patients_screen.dart`

Extracción segura:

1. Crear carpeta:
   - `lib/features/dashboard/presentation/admin_patients/`
2. Extraer:
   - filtros,
   - cards paciente,
   - hero/header,
   - empty states,
   - métricas.
3. Mantener navegación al detalle en el screen principal o inyectar callback.

No mover:

- Providers.
- Búsqueda/filtros si dependen de estado local, hasta extraer view model puro.

Meta:

- Bajar de 2270 a 1300–1600 líneas.

Validaciones:

- tests admin/pacientes.
- admin responsive tests.
- Suite completa.

---

## 4.7 `patient_treatment_tab.dart`

Extracción segura:

1. Crear carpeta:
   - `lib/features/patients/presentation/tabs/treatment/`
2. Extraer:
   - hero de tratamiento,
   - cards de tratamiento,
   - timeline de etapas,
   - chips/metrics,
   - empty states,
   - action panels.
3. Mantener callbacks y providers arriba.

No mover:

- selección de tratamiento activo,
- apertura de dialogs,
- integración pagos/documentos,
- scrollable/embedded behavior.

Meta:

- Bajar de 2250 a 1300–1600 líneas.

Validaciones:

- `patient_treatment_tab_multitreatment_test.dart`
- treatment tests.
- payments effective tests.
- Suite completa.

---

## 4.8 `admin_dashboard_screen.dart`

Extracción segura:

1. Crear carpeta:
   - `lib/features/dashboard/presentation/admin_dashboard/`
2. Extraer:
   - KPI cards,
   - summary sections,
   - charts/list placeholders,
   - empty states.

No mover:

- Providers de dashboard.
- Cálculos si no están cubiertos por tests; primero mover a helpers puros.

Meta:

- Bajar de 2059 a 1200–1500 líneas.

Validaciones:

- dashboard KPI layout tests.
- admin modules responsive tests.
- Suite completa.

---

## 4.9 `patient_payments_screen.dart`

Riesgo: alto por dinero y PayU.

Extracción segura:

1. Extraer solo UI pasiva:
   - payment hero,
   - transaction list,
   - payu CTA card,
   - empty states,
   - status chips.
2. Mantener flujos PayU y submit intactos.

No mover:

- inicio de sesión PayU,
- validación de saldo,
- tratamiento seleccionado,
- callbacks de pago.

Validaciones:

- `patient_payments_screen_payu_test.dart`
- payments model/repository/provider tests.
- Suite completa.

---

## 4.10 `patient_appointments_screen.dart`

Extracción segura:

1. Separar:
   - appointment cards,
   - status chips,
   - empty states,
   - filters,
   - date headers.
2. Mantener reglas de cita y provider usage en screen.

No mover:

- cancel/reprogram logic,
- appointment business rules,
- provider writes.

Validaciones:

- appointments business rules.
- FCM route tests si hay navegación desde notificaciones.
- Suite completa.

---

## 4.11 `login_screen.dart`

Riesgo: alto porque bloquea entrada al sistema.

Extracción segura:

1. Extraer UI:
   - login form,
   - register form,
   - forgot password form,
   - auth hero/branding,
   - error banner.
2. Mantener AuthService calls y estado principal inicialmente.

No mover:

- submit login/register,
- manejo de errores,
- navegación post-login,
- validadores centrales.

Validaciones:

- `login_forgot_validation_test.dart`
- `widget_test.dart`
- validators tests.
- Suite completa.

---

## 4.12 `patient_payments_tab.dart`

Extracción segura:

1. Extraer widgets de cuenta/tratamiento/transacciones.
2. Mantener selección de tratamiento y registros de pago en contenedor.

No mover:

- `registerManualPayment`,
- integración con payments repository,
- tratamiento seleccionado.

Validaciones:

- `patient_payments_tab_effective_test.dart`
- payments tests.
- Suite completa.

---

## 4.13 `payments_repository.dart`

Riesgo: muy alto. Debe ir al final.

Plan seguro:

1. No cambiar comportamiento.
2. Primero crear tests adicionales si falta cobertura para:
   - pago manual,
   - PayU gateway payment,
   - legacy mirror,
   - tratamientos múltiples,
   - saldo pendiente,
   - transaction paths.
3. Extraer helpers privados a archivos internos solo si son puros:
   - path builders,
   - transaction payload builders,
   - summary calculators.
4. Mantener API pública igual.

No hacer:

- cambiar rutas Firestore,
- cambiar nombres de campos,
- alterar batches,
- alterar mirror legacy sin migración y tests.

Validaciones:

- toda la suite de payments.
- suite completa.

---

## 4.14 `patient_clinical_history_tab.dart`

Extracción segura:

1. Extraer:
   - document card,
   - visibility filters,
   - upload form UI,
   - empty state,
   - metadata chips.
2. Mantener repositorio/Storage/provider calls en contenedor.

No mover:

- upload/delete/visibility writes,
- Firestore/Storage paths,
- treatment association logic.

Validaciones:

- clinical files repository/model tests.
- Suite completa.

---

## 5. Patrón estándar de extracción

Para cada archivo:

1. **Snapshot inicial**
   - `git status --short`
   - `wc -l <archivo>`
   - identificar tests relevantes.

2. **Extraer helpers puros**
   - `*_helpers.dart`
   - `*_formatters.dart`
   - sin Flutter si no hace falta.

3. **Extraer widgets stateless**
   - `*_widgets.dart` o carpeta por módulo.
   - callbacks inyectados.
   - no leer providers dentro del widget extraído, salvo que ya sea un widget claramente especializado.

4. **Extraer view models simples**
   - solo datos derivados de modelos.
   - sin side effects.

5. **Validar**
   - format,
   - analyze,
   - tests focalizados,
   - suite completa.

6. **Documentar**
   - actualizar este plan o roadmap con:
     - fecha,
     - alcance,
     - archivos,
     - validaciones,
     - commit.

7. **Commit/push**
   - mensaje en español, específico, sin prefijos tipo `feat:`.

---

## 6. Límites para no romper nada

Detenerse y no pushear si ocurre cualquiera de estos casos:

- Cambia una ruta o nombre de campo Firestore sin intención explícita.
- Cambia una ruta de GoRouter usada por FCM/notificaciones.
- Reaparece nested scroll incómodo en detalle móvil admin.
- Se duplica Scaffold o bottom nav.
- Falla cualquier test de pagos, auth, appointments o admin responsive.
- `flutter analyze` muestra warnings nuevos.
- El diff mezcla más de un dominio sensible, por ejemplo pagos + auth, agenda + Firebase rules, tratamiento + PayU.

---

## 7. Definición de terminado

El refactor de archivos grandes se considera terminado cuando:

- Ningún archivo de presentación principal supera ~1800 líneas, salvo excepciones justificadas.
- Repositorios sensibles quedan por debajo de ~700 líneas o documentados como excepción.
- Cada módulo grande tiene helpers/widgets separados con nombres claros.
- La suite completa sigue verde.
- El roadmap/documentación registra cada bloque.
- No hay cambios funcionales ocultos dentro de commits de refactor.

---

## 8. Próximo paso recomendado

Continuar con P6 sobre `admin_appointments_screen.dart`, pero ya no extraer lógica sensible.

Bloque recomendado:

1. Crear `admin_appointments_agenda_widgets.dart`.
2. Extraer `AgendaPill` y `AgendaAppointmentCard` como widgets stateless con callbacks:
   - `onOpenProfile`,
   - `onConfirm`,
   - `onComplete`,
   - `onReschedule`,
   - `onNoShow`,
   - `onCancel`,
   - `onReopen`.
3. Mantener `_handleStatusAction`, dialogs y navegación en `admin_appointments_screen.dart`.
4. Validar con agenda/admin tests y suite completa.

Este bloque es el más seguro porque reduce UI repetida sin mover efectos externos.
