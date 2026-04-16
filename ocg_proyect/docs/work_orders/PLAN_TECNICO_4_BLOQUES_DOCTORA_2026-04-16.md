# PLAN TÉCNICO DE IMPLEMENTACIÓN — 4 BLOQUES DOCTORA

> Fecha: 2026-04-16  
> Repo: `ocg_proyect`  
> Fuente funcional: propuesta 2026-04-14 (bloques 01, 02, 03, 04)  
> Propósito: dejar una hoja de ruta técnica estable para implementar sin perder foco ni reinterpretar requisitos en cada sesión.

---

## 1. Objetivo general

Convertir OCG Flutter de un flujo básico de pacientes, citas y pagos a un modelo clínico-administrativo más completo con cuatro capacidades nuevas:

1. tratamientos múltiples por paciente,
2. pagos dinámicos por tratamiento,
3. historial clínico documental por archivos,
4. recordatorios automáticos de citas por app y WhatsApp.

---

## 2. Orden oficial de ejecución

Este orden queda definido como el orden de trabajo por defecto:

### Fase 1
**Bloque 01. Tratamientos múltiples y etapas por tratamiento**

### Fase 2
**Bloque 02. Constructor dinámico de pagos por tratamiento**

### Fase 3
**Bloque 03. Historial clínico por archivos**

### Fase 4
**Bloque 04. Recordatorios automáticos de citas**

### Regla de dependencia
- Bloque 02 depende de Bloque 01.
- Bloque 03 debe montarse sobre paciente y opcionalmente sobre tratamiento definido en Bloque 01.
- Bloque 04 depende del módulo de citas existente y de backend/functions.
- No cerrar Bloque 02 sin que el tratamiento ya sea la unidad principal de contexto financiero.

---

## 3. Principio de arquitectura que manda

La nueva unidad principal de trabajo ya no es solo `patients/{patientId}`.

La unidad principal pasa a ser:

- `patients/{patientId}` como raíz del paciente,
- `patients/{patientId}/treatments/{treatmentId}` como raíz clínica y financiera del tratamiento.

Todo lo nuevo debe diseñarse con esta regla:

- la clínica trabaja sobre un paciente,
- pero las operaciones clínicas y económicas viven por tratamiento.

Los campos legacy en `patients/{patientId}` se conservan solo como espejo temporal para no romper módulos ya hechos.

---

## 4. Impacto de datos en Firestore

## 4.1 Estructura objetivo

```text
patients/{patientId}
patients/{patientId}/treatments/{treatmentId}
patients/{patientId}/treatments/{treatmentId}/stageHistory/{entryId}
patients/{patientId}/clinicalFiles/{fileId}
appointments/{appointmentId}
payments/{patientId}
payments/{patientId}/transactions/{transactionId}
scheduled_notifications/{notificationId}
treatment_catalog/{catalogId}   (nuevo, recomendado)
```

## 4.2 Documento patient

`patients/{patientId}` queda como:
- identidad y datos base del paciente,
- cache/mirores de estado principal,
- acceso rápido para listas admin,
- compatibilidad con pantallas ya existentes.

Campos espejo que pueden seguir existiendo temporalmente:
- `tipoTratamiento`
- `etapaActual`
- `fechaInicio`
- `saldoPendiente`
- `totalTratamiento`
- `notasClinicas`
- `primaryTreatmentId` (nuevo, recomendado)
- `activeTreatmentIds` (nuevo, recomendado si se necesita resumen rápido)

## 4.3 Documento treatment

`patients/{patientId}/treatments/{treatmentId}` debe consolidar:
- identidad del tratamiento,
- configuración clínica,
- etapa actual,
- configuración de seguimiento,
- estructura financiera,
- estado operativo.

Campos base:
- `id`
- `nombre`
- `categoria`
- `tipoBase`
- `subtipo`
- `estado`
- `etapaActual`
- `fechaInicio`
- `isPrimary`
- `suggestedCleaningEveryMonths`
- `suggestedControlEveryMonths`
- `financialItems` o subcolección equivalente
- `totalTratamiento`
- `saldoPendiente`
- `currency`
- `notes`
- `createdAt`
- `updatedAt`

## 4.4 Historial de etapas

`patients/{patientId}/treatments/{treatmentId}/stageHistory/{entryId}`

Campos mínimos:
- `id`
- `fromStage`
- `toStage`
- `notes`
- `changedBy`
- `changedAt`
- `attachmentsCount` opcional

## 4.5 Historial clínico documental

Nivel mínimo:
- `patients/{patientId}/clinicalFiles/{fileId}`

Campos mínimos:
- `id`
- `patientId`
- `treatmentId` opcional
- `name`
- `storagePath`
- `mimeType`
- `sizeBytes`
- `uploadedBy`
- `uploadedAt`
- `category`
- `notes`
- `visibility` opcional

## 4.6 Recordatorios programados

Nueva colección backend:
- `scheduled_notifications/{notificationId}`

Campos mínimos:
- `appointmentId`
- `patientId`
- `channel` (`push`, `whatsapp`)
- `kind` (`day_before`, `hour_before`)
- `scheduledFor`
- `status` (`pending`, `sent`, `cancelled`, `failed`, `obsolete`)
- `payloadSnapshot`
- `lastAttemptAt`
- `providerMessageId` opcional
- `createdAt`
- `updatedAt`

---

## 5. Impacto en Flutter por capa

## 5.1 Modelos

### Ya existen y deben evolucionar
- `lib/features/treatment/data/models/patient_treatment.dart`
- `lib/features/treatment/data/models/stage_history_entry.dart`
- `lib/features/patients/data/models/patient_model.dart`
- `lib/features/appointments/data/models/appointment_model.dart`
- `lib/features/payments/data/models/payment_model.dart`

### Modelos nuevos recomendados
- `lib/features/treatment/data/models/treatment_financial_item.dart`
- `lib/features/patients/data/models/clinical_file_model.dart`
- `lib/features/appointments/data/models/scheduled_notification_model.dart`
- `lib/features/treatment/data/models/treatment_catalog_item.dart` (si se maneja catálogo global)

## 5.2 Repositorios

### Ya existen y deben ampliarse
- `patient_treatments_repository.dart`
- `appointments_repository.dart`
- `payments_repository.dart`
- `patients_repository.dart`
- `storage_service.dart`
- `fcm_service.dart`

### Nuevos repositorios recomendados
- `clinical_files_repository.dart`
- `treatment_catalog_repository.dart`
- `scheduled_notifications_repository.dart` (si se consulta estado desde admin)

## 5.3 Providers Riverpod

### Ya existen y deben ampliarse
- `patient_treatments_provider.dart`
- `patients_provider.dart`
- `appointments_provider.dart`
- `payments_provider.dart`

### Nuevos providers recomendados
- `selected_patient_treatment_provider.dart`
- `treatment_financial_items_provider.dart`
- `clinical_files_provider.dart`
- `scheduled_notifications_status_provider.dart`

## 5.4 Pantallas y widgets

### Ya existen y son puntos de anclaje reales
- `patient_detail_screen.dart`
- `patient_form_screen.dart`
- `patient_treatment_tab.dart`
- `patient_payments_tab.dart`
- `patient_appointments_tab.dart`
- widgets de `features/treatment/presentation/widgets/`

### Nuevos widgets/pantallas recomendados
- `treatment_selector_header.dart`
- `create_edit_treatment_dialog.dart` o evolución de `manage_patient_treatment_dialog.dart`
- `treatment_financial_builder.dart`
- `financial_item_row.dart`
- `clinical_files_tab.dart` o subpanel integrado al detalle del paciente
- `upload_clinical_file_dialog.dart`
- `appointment_reminder_status_badge.dart`

---

## 6. Plan técnico por bloque

# BLOQUE 01 — Tratamientos múltiples y etapas por tratamiento

## Objetivo técnico
Hacer que el tratamiento sea una entidad real por paciente, seleccionable, editable, con etapa propia e historial propio.

## Qué tocar

### Firestore
- consolidar `patients/{patientId}/treatments/{treatmentId}` como fuente de verdad,
- consolidar `patients/{patientId}/treatments/{treatmentId}/stageHistory/{entryId}`,
- mantener espejo legacy mínimo en `patients/{patientId}`.

### Modelos Flutter
- endurecer `PatientTreatment`,
- validar subtipo obligatorio para `convencional` y `autoligado`,
- agregar metadatos para tratamiento principal y seguimiento 3m/6m,
- verificar consistencia con `PatientModel` legacy.

### Repositorios
- ampliar `PatientTreatmentsRepository` para:
  - crear tratamiento,
  - editar tratamiento,
  - finalizar/cancelar tratamiento,
  - cambiar tratamiento principal,
  - persistir historial de etapas,
  - listar activos/finalizados.

### Providers
- provider de lista de tratamientos del paciente,
- provider del tratamiento seleccionado,
- provider del historial de etapas por tratamiento.

### UI
- `patient_form_screen.dart`: selector de tratamiento y alta de nuevo tratamiento,
- `patient_treatment_tab.dart`: selector visible de tratamientos,
- `manage_patient_treatment_dialog.dart`: crear/editar tratamiento,
- `treatment_timeline.dart`, `update_stage_dialog.dart`, `stage_history_list.dart`: atarlos al tratamiento seleccionado, no al paciente global.

### Backend / rules
- ajustar `firestore.rules` para subcolección `treatments` y `stageHistory`,
- revisar índices si hay filtros por `estado`, `isPrimary`, `updatedAt`.

## Resultado esperado al cerrar Bloque 01
- un paciente puede tener varios tratamientos,
- el admin puede cambiar entre ellos,
- cada tratamiento conserva su etapa e historial sin contaminar otro,
- el sistema sigue funcionando con compatibilidad hacia los módulos legacy.

## Riesgo principal
Romper módulos existentes que todavía leen campos planos del paciente. Por eso el espejo legacy no se elimina en este bloque.

---

# BLOQUE 02 — Constructor dinámico de pagos por tratamiento

## Objetivo técnico
Mover la lógica económica del tratamiento desde un total fijo a un builder de conceptos persistentes y recalculables.

## Qué tocar

### Firestore
Dentro de cada tratamiento guardar:
- `financialItems: []` como arreglo ordenado, o
- subcolección `financialItems` si luego se necesita auditoría fina.

**Recomendación para esta etapa:** usar arreglo `financialItems` dentro del tratamiento para reducir complejidad inicial.

Cada item debe tener:
- `id`
- `name`
- `kind`
- `amount`
- `deletable`
- `editableName`
- `order`
- `createdByAdmin`

### Modelos Flutter
- crear `TreatmentFinancialItem`,
- ampliar `PatientTreatment` con `financialItems`, `totalTratamiento`, `saldoPendiente`, `currency`,
- mantener compatibilidad con `PaymentModel` existente.

### Repositorios
- ampliar `PatientTreatmentsRepository` para persistir estructura financiera,
- ampliar `PaymentsRepository` para tomar como base el `treatmentId` activo cuando corresponda,
- definir estrategia de convivencia entre `payments/{patientId}` y pagos por tratamiento.

## Decisión técnica recomendada
En esta fase:
- `payments/{patientId}` sigue siendo la vista financiera agregada del paciente,
- pero el **presupuesto** nace en `treatment.financialItems`,
- `payments/{patientId}` se recalcula o sincroniza desde el tratamiento principal/activo definido por negocio.

## Punto que debe quedar explícito
Antes de desarrollar cobros avanzados, definir si:
1. un paciente tendrá una sola bolsa de deuda global,
2. o deuda separada por tratamiento.

**Recomendación inicial:** deuda global visible al paciente, con composición interna por tratamiento.

### UI
- `patient_form_screen.dart`: constructor inicial al crear paciente si aplica,
- `patient_treatment_tab.dart`: editor del presupuesto del tratamiento seleccionado,
- `patient_payments_tab.dart`: mostrar resumen del tratamiento activo y resumen global.

### Backend / rules
- validaciones para que `Inicial` y `Controles` no se eliminen,
- total autocalculado,
- sincronización con saldo pendiente sin dejar valores negativos.

## Resultado esperado al cerrar Bloque 02
- el admin arma el tratamiento con conceptos dinámicos,
- el total se calcula solo,
- el tratamiento guarda su estructura financiera real,
- el módulo de pagos puede seguir operando sin doble fuente de verdad caótica.

---

# BLOQUE 03 — Historial clínico por archivos

## Objetivo técnico
Agregar expediente documental clínico por paciente con asociación opcional a tratamiento.

## Qué tocar

### Firestore + Storage
- metadata en `patients/{patientId}/clinicalFiles/{fileId}`,
- binario en Storage,
- asociación opcional a `treatmentId`.

### Modelos Flutter
- crear `ClinicalFileModel`.

### Repositorios
- crear `ClinicalFilesRepository` para:
  - upload,
  - list,
  - delete,
  - resolver descarga,
  - filtrar por tratamiento.

### Servicios
- usar `storage_service.dart` como base,
- agregar validaciones de mime type y tamaño.

### UI
- nuevo bloque/tab en detalle del paciente,
- upload con categoría y notas,
- preview/listado,
- filtro por tratamiento actual,
- acciones ver/descargar/eliminar.

### Backend / rules
- reforzar `firestore.rules` y `storage.rules`,
- no exponer URLs públicas permanentes,
- acceso admin/doctora solamente al inicio.

## Resultado esperado al cerrar Bloque 03
- el expediente clínico documental queda integrado al paciente,
- opcionalmente ligado al tratamiento,
- con orden, metadatos y seguridad razonable.

---

# BLOQUE 04 — Recordatorios automáticos de citas

## Objetivo técnico
Automatizar recordatorios de citas en dos tiempos y dos canales, con control de estado, deduplicación y reprogramación segura.

## Qué tocar

### Appointment model
Ampliar `AppointmentModel` con señales mínimas necesarias, por ejemplo:
- `remindersEnabled`
- `lastReminderSyncAt`
- `status` ya existente como fuente para invalidación

### Backend Functions
Trabajar en `functions/src`:
- trigger al crear cita,
- trigger al reprogramar,
- trigger al cancelar,
- scheduler que procese `scheduled_notifications`,
- integración FCM,
- integración WhatsApp desacoplada por adapter/service.

### Colección backend
- `scheduled_notifications` como fuente de verdad del scheduler.

### Flutter
- mostrar estado de recordatorios en admin,
- consumir historial de notificaciones si aplica,
- no programar lógica de negocio crítica de recordatorios solo desde Flutter.

### Canales
- push: vía FCM,
- WhatsApp: dejar adapter con provider configurable.

## Recomendación fuerte
La programación e invalidación debe vivir en backend, no en cliente Flutter. Flutter solo crea o actualiza cita. Backend decide recordatorios vigentes.

## Resultado esperado al cerrar Bloque 04
- al crear o reprogramar cita se programan recordatorios válidos,
- al cancelar se invalidan,
- no se duplican,
- se puede inspeccionar su estado desde admin.

---

## 7. Cambios concretos esperados por archivo o zona

## Flutter
- `lib/features/patients/data/models/patient_model.dart`
- `lib/features/patients/data/repositories/patients_repository.dart`
- `lib/features/patients/presentation/patient_form_screen.dart`
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `lib/features/patients/presentation/tabs/patient_treatment_tab.dart`
- `lib/features/patients/presentation/tabs/patient_payments_tab.dart`
- `lib/features/appointments/data/models/appointment_model.dart`
- `lib/features/appointments/data/repositories/appointments_repository.dart`
- `lib/features/treatment/data/models/patient_treatment.dart`
- `lib/features/treatment/data/repositories/patient_treatments_repository.dart`
- `lib/features/treatment/providers/patient_treatments_provider.dart`
- `lib/features/treatment/presentation/widgets/*`
- `lib/services/firebase/storage_service.dart`
- `lib/services/notifications/fcm_service.dart`
- `lib/shared/constants/firestore_paths.dart`

## Backend / Firebase
- `functions/src/**`
- `firestore.rules`
- `firestore.indexes.json`
- `storage.rules` si existe o debe agregarse según setup

---

## 8. Definiciones de terminado por bloque

## DOD Bloque 01
- múltiples tratamientos funcionales por paciente,
- selector de tratamiento en detalle,
- subtipo obligatorio donde aplique,
- historial de etapas por tratamiento,
- análisis y tests verdes.

## DOD Bloque 02
- builder financiero operativo,
- total autocalculado,
- validaciones de conceptos base,
- persistencia por tratamiento,
- integración consistente con pagos.

## DOD Bloque 03
- subir, listar, descargar y eliminar archivos,
- asociación opcional a tratamiento,
- reglas y permisos revisados,
- validación de tipo/tamaño.

## DOD Bloque 04
- scheduler backend operativo,
- alta/reprogramación/cancelación sincronizan recordatorios,
- push funcional,
- integración WhatsApp con adapter definido,
- estados visibles en admin.

---

## 9. Reglas para no perder el hilo en sesiones futuras

Cuando se retome este plan, asumir lo siguiente como verdad operativa:

1. El siguiente bloque a ejecutar es el **Bloque 01**.
2. No preguntar otra vez cuál es el orden salvo que Jefe lo cambie explícitamente.
3. No rediseñar desde cero el modelo: el eje es `patients/{patientId}/treatments/{treatmentId}`.
4. El Bloque 02 no se empieza sin dejar estable el tratamiento múltiple.
5. El Bloque 04 se implementa con lógica central en backend/functions, no en Flutter cliente.
6. Mantener compatibilidad con módulos legacy mientras se migra.
7. Al cerrar cada bloque, actualizar documentación de estado y dejar commit en español específico.

---

## 10. Próxima acción esperada

La siguiente acción esperada, después de que Jefe confirme, es:

**Iniciar implementación del Bloque 01: tratamientos múltiples y etapas por tratamiento.**

Eso implica arrancar por:
- revisión de modelos actuales,
- endurecimiento de `PatientTreatment`,
- ajuste de repositorio/provider,
- integración real en `patient_treatment_tab.dart` y `patient_form_screen.dart`,
- compatibilidad legacy en `patients/{patientId}`.
