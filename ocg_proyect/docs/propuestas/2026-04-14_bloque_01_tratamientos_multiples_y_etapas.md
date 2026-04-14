# Bloque 01 — Tratamientos múltiples y etapas por tratamiento

## Objetivo

Permitir que un paciente tenga varios tratamientos activos al mismo tiempo, cada uno con su propia identidad, subtipo cuando aplique, etapas, estado, seguimiento clínico y relación futura con pagos, citas, historial clínico y recordatorios.

Este bloque será la nueva base funcional del sistema OCG, porque el tratamiento dejará de ser un dato plano dentro del paciente y pasará a ser una entidad propia.

---

## Qué entendemos del negocio

- Un paciente puede tener varios tratamientos activos simultáneamente.
- El admin debe poder distinguir claramente cada tratamiento.
- Cada tratamiento tiene sus propias etapas.
- Cada tratamiento debe poder tener su propio estado: activo, pausado, finalizado o cancelado.
- Los tratamientos actuales pertenecen principalmente al dominio de ortodoncia.
- Convencional y Autoligado requieren una distinción obligatoria entre estético y metálico.
- También debe existir la posibilidad de crear nuevos tratamientos desde admin.
- El tratamiento visible debe poder cambiarse desde el tab de Tratamiento del paciente.
- El modelo debe quedar preparado para que pagos, archivos clínicos, citas y recordatorios puedan asociarse a un tratamiento específico.

---

## Tratamientos base actuales

- Convencional
- Autoligado
- Alineadores
- Ortopedia
- Interceptivo
- Retenedores
- Brackets estéticos

### Nota sobre Brackets estéticos

Debe revisarse si `Brackets estéticos` seguirá existiendo como tratamiento visible propio o si pasa a ser un subtipo de Convencional/Autoligado.

Mientras no haya decisión final de la doctora, Borlty no debe eliminarlo. Puede mantenerlo como opción visible, pero debe dejar el modelo preparado para convertirlo después en alias o subtipo.

---

## Regla central de modelado

Ya no conviene guardar el tratamiento principal solo como campos sueltos dentro de `PatientModel`.

A partir de este bloque, la estructura recomendada es:

```txt
patients/{patientId}
patients/{patientId}/treatments/{treatmentId}
patients/{patientId}/treatments/{treatmentId}/stageHistory/{stageId}

Cada tratamiento debe ser una entidad independiente.

Modelo sugerido de tratamiento

Cada documento en:

patients/{patientId}/treatments/{treatmentId}

debe tener como mínimo:

{
  "id": "treatmentId",
  "patientId": "patientId",
  "name": "Convencional",
  "category": "ortodoncia",
  "baseType": "convencional",
  "subtype": "metalico",
  "status": "activo",
  "currentStageId": "stageId",
  "currentStageName": "Instalación de brackets",
  "isPrimary": true,
  "startDate": "timestamp",
  "endDate": null,
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "createdBy": "adminUid",
  "updatedBy": "adminUid"
}
Estados permitidos del tratamiento

Los estados iniciales serán:

activo
pausado
finalizado
cancelado
Reglas
Un tratamiento activo aparece en la lista principal.
Un tratamiento pausado sigue visible, pero debe diferenciarse visualmente.
Un tratamiento finalizado pasa al historial.
Un tratamiento cancelado no debe borrarse, solo marcarse como cancelado.
No se deben eliminar tratamientos con historial clínico, pagos o citas asociadas.
Subtipo obligatorio

Si el admin elige:

Convencional
Autoligado

entonces el formulario debe exigir:

Estético
Metálico

No debe permitir guardar sin ese dato.

Para otros tratamientos, el subtipo puede ser opcional o nulo.

Etapas por tratamiento

Cada tratamiento debe tener su propia línea de tiempo.

No se debe manejar una sola etapa global en el paciente.

Estructura recomendada:

patients/{patientId}/treatments/{treatmentId}/stageHistory/{stageId}

Cada etapa debe guardar:

{
  "id": "stageId",
  "treatmentId": "treatmentId",
  "patientId": "patientId",
  "stageName": "Diagnóstico",
  "notes": "Observación clínica opcional",
  "status": "completada",
  "startedAt": "timestamp",
  "completedAt": "timestamp",
  "createdAt": "timestamp",
  "createdBy": "adminUid"
}
Reglas de etapas
Cambiar la etapa de un tratamiento no debe afectar otros tratamientos del mismo paciente.
El historial de etapas no debe borrarse.
Si se cambia la etapa actual, debe quedar registro en stageHistory.
La UI debe mostrar la etapa actual y permitir consultar etapas anteriores.
El sistema debe evitar estados ambiguos como tener varios tratamientos con la misma etapa global.
Relación futura con pagos, citas y archivos

Desde este bloque, todo debe quedar preparado para usar treatmentId.

Pagos

El Bloque 02 dependerá de esta estructura. Cada tratamiento tendrá su propia estructura financiera.

Por eso, el tratamiento debe poder almacenar después:

financialItems
totalAmount
currency
lastPricingUpdateAt

No es necesario implementar todo el Bloque 02 aquí, pero sí dejar el modelo preparado.

Citas

Las citas deben quedar preparadas para asociarse opcionalmente a un tratamiento:

{
  "appointmentId": "id",
  "patientId": "patientId",
  "treatmentId": "treatmentId"
}

En este bloque no se necesita rehacer todo el módulo de citas, pero Borlty debe evitar diseñar el tratamiento como algo aislado.

Historial clínico

El Bloque 03 podrá asociar archivos al paciente y opcionalmente al tratamiento.

Por eso, el tratamiento debe tener un id estable y consultable.

Recordatorios

El Bloque 04 podrá usar el tratamiento para mensajes o seguimientos relacionados con citas.

Catálogo global de tratamientos

Además de los tratamientos guardados dentro del paciente, debe existir o prepararse un catálogo global de tratamientos disponibles.

Estructura sugerida:

treatmentCatalog/{catalogTreatmentId}

Campos sugeridos:

{
  "id": "catalogTreatmentId",
  "name": "Convencional",
  "normalizedName": "convencional",
  "category": "ortodoncia",
  "baseType": "convencional",
  "requiresSubtype": true,
  "allowedSubtypes": ["estetico", "metalico"],
  "isSystemDefault": true,
  "active": true,
  "createdAt": "timestamp",
  "createdBy": "adminUid"
}
Regla temporal recomendada

Los tratamientos nuevos creados por admin quedarán disponibles globalmente para toda la clínica, no solo para el paciente actual.

Esto evita que cada paciente tenga tratamientos duplicados con nombres parecidos.

Crear tratamientos nuevos desde admin

Debe existir acción para escribir un nombre nuevo de tratamiento.

Flujo esperado:

Admin escribe el nombre.
Sistema limpia espacios innecesarios.
Sistema normaliza el nombre para evitar duplicados.
Sistema valida si ya existe un tratamiento parecido.
Sistema pide confirmación:
“¿Confirmas crear este tratamiento con este nombre?”
Si confirma, el tratamiento queda disponible en el catálogo global.
Luego puede seleccionarse para el paciente actual.
Reglas
No permitir nombres vacíos.
No permitir nombres duplicados por normalización.
No guardar nombres con espacios al inicio o final.
No crear tratamientos globales sin confirmación.
No eliminar tratamientos base del sistema.
Migración de datos actuales

Este punto es obligatorio.

Borlty no debe romper pacientes existentes.

Si actualmente PatientModel tiene campos planos como:

treatmentType
treatmentStage
treatmentStatus
treatmentAmount

o equivalentes, se debe crear una estrategia de compatibilidad.

Estrategia recomendada
Detectar pacientes existentes con tratamiento plano.
Crear un tratamiento inicial en:
patients/{patientId}/treatments/{treatmentId}
Copiar los datos actuales al nuevo documento.
Marcar ese tratamiento como isPrimary: true.
Mantener temporalmente lectura compatible para evitar pantallas rotas.
Después de validar, limpiar referencias antiguas.
Regla crítica

No borrar campos antiguos hasta confirmar que:

la UI nueva funciona,
los pacientes existentes cargan correctamente,
el tab Tratamiento usa la nueva subcolección,
no se pierde información clínica ni financiera.
Reglas funcionales
1. Listado de tratamientos dentro del paciente

En el perfil del paciente debe existir un selector/listado claro con:

tratamientos activos
tratamientos pausados
tratamientos finalizados
tratamiento actualmente seleccionado
acción Nuevo tratamiento
acción Editar tratamiento
acción Cambiar tratamiento visible
acción Marcar como finalizado
2. Tratamiento principal

Puede existir un campo isPrimary.

Regla recomendada:

Solo un tratamiento puede estar marcado como principal por paciente.
Si se marca otro como principal, el anterior debe pasar a isPrimary: false.
El tratamiento principal será el que se muestre por defecto al abrir el paciente.
3. Cambio de tratamiento dentro del tab Tratamiento

Dentro del tab de Tratamiento del paciente, el admin debe poder:

cambiar el tratamiento visible,
crear uno nuevo,
editar nombre/tipo/subtipo,
marcar uno como pausado,
marcar uno como finalizado,
mantener historial de tratamientos anteriores.
4. Seguimiento periódico

Todos los tratamientos actuales del dominio ortodóntico deben soportar:

limpieza cada 3 meses,
control cada 6 meses.

Esto debe quedar como parte de la ficha del tratamiento.

Campos sugeridos:

{
  "followUpConfig": {
    "cleaningEveryMonths": 3,
    "controlEveryMonths": 6,
    "enabled": true
  }
}

En este bloque no es obligatorio autogenerar citas, pero sí dejar la configuración lista.

UI propuesta
En crear paciente

El formulario debe incluir:

selector de tratamiento desde catálogo,
opción Agregar nuevo tratamiento,
subtipo obligatorio si aplica,
vista más ancha para soportar después los componentes financieros,
tratamiento inicial marcado como principal.
En detalle del paciente

Debe existir:

header con selector de tratamiento,
chips o tabs con tratamientos activos,
bloque visual del tratamiento seleccionado,
acceso a historial de tratamientos finalizados.

El bloque visual debe mostrar:

nombre del tratamiento,
subtipo si aplica,
etapa actual,
estado,
fecha de inicio,
si es tratamiento principal,
acciones rápidas.
Seguridad y permisos

Este bloque no debe quedarse solo en UI.

Borlty debe revisar:

modelos,
repositorios,
providers,
reglas de Firestore,
consultas,
validaciones de rol.
Reglas mínimas
Solo admin puede crear, editar, pausar, finalizar o cancelar tratamientos.
El paciente puede leer sus tratamientos si la app del paciente lo requiere.
Un paciente no puede leer tratamientos de otro paciente.
No debe permitirse escritura directa insegura desde cliente si la operación requiere lógica de negocio.
Si se usan Cloud Functions para operaciones críticas, deben validar rol admin.
Índices y consultas

Deben quedar preparadas consultas para:

tratamientos activos de un paciente,
tratamientos finalizados de un paciente,
tratamiento principal del paciente,
tratamientos ordenados por fecha de creación,
catálogo global de tratamientos activos.

Índices sugeridos:

patients/{patientId}/treatments
- status
- isPrimary
- createdAt
- updatedAt

treatmentCatalog
- active
- normalizedName
- category
Providers / repositorios sugeridos

Borlty debe implementar o ajustar:

TreatmentModel
TreatmentStageModel
TreatmentCatalogModel
TreatmentsRepository
TreatmentCatalogRepository
provider/stream de tratamientos por paciente
provider de tratamiento seleccionado
provider de catálogo de tratamientos
Entregables de implementación

Borlty debe entregar:

Modelo nuevo de tratamiento por paciente.
Modelo de historial de etapas por tratamiento.
Catálogo global de tratamientos.
Migración o compatibilidad con pacientes existentes.
Selector de tratamiento activo en UI admin.
Formulario de creación/edición de tratamiento.
Validación de subtipo obligatorio.
Soporte para tratamiento principal.
Configuración de seguimiento 3m/6m.
Reglas de Firestore revisadas.
Providers/repositorios actualizados.
Validación manual con mínimo:
paciente nuevo,
paciente existente,
paciente con más de un tratamiento,
tratamiento Convencional con subtipo,
tratamiento Autoligado con subtipo,
tratamiento nuevo creado por admin.
Riesgos si no se hace así
Se mezcla la historia de varios tratamientos en un solo estado.
No se podrá saber sobre qué tratamiento se aplicó una cita.
No se podrá saber qué tratamiento originó un cobro.
El historial clínico quedará desordenado.
El tab de tratamiento se volverá ambiguo.
Los pacientes existentes podrían romperse si no hay migración.
El Bloque 02 de pagos quedará mal construido si el tratamiento no queda estable.
Decisiones para validar con Jefe/doctora

Antes o durante la implementación, validar:

Si Brackets estéticos seguirá como tratamiento propio o será subtipo.
Si solo puede existir un tratamiento principal por paciente.
Si los tratamientos nuevos creados por admin quedan globales para toda la clínica.
Si el paciente podrá ver todos sus tratamientos desde su app.
Si los seguimientos de 3 y 6 meses solo serán informativos o generarán sugerencias de citas.
Si un tratamiento finalizado puede reactivarse o debe crearse uno nuevo.
Criterio de aceptación del Bloque 01

El bloque se considera terminado cuando:

Un paciente puede tener más de un tratamiento.
Cada tratamiento tiene su propia etapa actual.
Cada tratamiento tiene su propio historial de etapas.
Convencional y Autoligado obligan a elegir subtipo.
El admin puede crear un tratamiento nuevo desde el sistema.
Los tratamientos nuevos quedan disponibles en el catálogo.
El admin puede cambiar el tratamiento visible en el tab Tratamiento.
Los pacientes existentes no se rompen.
El modelo queda preparado para pagos, archivos clínicos, citas y recordatorios.