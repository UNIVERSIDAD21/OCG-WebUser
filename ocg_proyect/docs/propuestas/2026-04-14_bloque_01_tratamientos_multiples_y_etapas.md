# Bloque 01 — Tratamientos múltiples y etapas por tratamiento

## Objetivo

Permitir que un paciente tenga varios tratamientos activos al mismo tiempo, cada uno con su propia identidad, subtipo cuando aplique, etapas, estado y seguimiento clínico.

## Qué entendemos del negocio

- Un paciente puede tener varios tratamientos activos simultáneamente.
- El admin debe poder distinguirlos y elegir sobre cuál trabajar.
- Cada tratamiento tiene sus propias etapas.
- Los tratamientos actuales del sistema se entienden dentro del dominio de ortodoncia.
- Convencional y Autoligado requieren una distinción obligatoria entre estético y metálico.
- También debe existir la posibilidad de crear nuevos tratamientos desde admin.
- Debe poder cambiarse el tratamiento desde el tab de Tratamiento del paciente.

## Tratamientos base actuales

- Convencional
- Autoligado
- Alineadores
- Ortopedia
- Interceptivo
- Retenedores
- Brackets estéticos (si hoy existe como tipo separado, debe revisarse si pasa a subtipo o queda como alias visual)
- Nuevos tratamientos creados por admin, por ejemplo: Obturación

## Regla importante de modelado

Ya no conviene guardar el tratamiento principal solo como campos sueltos dentro de `PatientModel`.

Se recomienda pasar a una estructura tipo:

- `patients/{patientId}`
- `patients/{patientId}/treatments/{treatmentId}`

Cada tratamiento debería tener como mínimo:

- `id`
- `nombre`
- `categoria` (por ejemplo `ortodoncia`)
- `tipoBase` (convencional, autoligado, alineadores, etc.)
- `subtipo` (estético/metálico cuando aplique)
- `estado` (activo, pausado, finalizado, cancelado)
- `etapaActual`
- `createdAt`
- `updatedAt`
- `isPrimary` opcional para resaltar uno por defecto

## Reglas funcionales

### 1. Listado de tratamientos dentro del paciente

En el perfil del paciente debe existir un selector/listado claro con:

- tratamientos activos
- tratamientos finalizados
- tratamiento actualmente seleccionado para ver detalle
- acción `Nuevo tratamiento`
- acción `Editar tratamiento`
- acción `Cambiar tratamiento actual visible`

### 2. Subtipo obligatorio para Convencional y Autoligado

Si el admin elige:
- Convencional
- Autoligado

entonces el formulario debe exigir:
- Estético
- Metálico

No debe permitir guardar sin ese dato.

### 3. Etapas por tratamiento

Cada tratamiento debe tener su propia línea de tiempo o flujo de etapas.

Esto evita que cambiar la etapa de un tratamiento afecte a los demás tratamientos activos del paciente.

### 4. Cambio de tratamiento dentro del tab Tratamiento

Dentro del tab de Tratamiento del paciente, el admin debe poder:

- cambiar el tratamiento visible
- crear uno nuevo
- editar nombre/tipo/subtipo
- marcar uno como finalizado
- mantener historial de tratamientos anteriores

### 5. Crear tratamientos nuevos desde admin

Debe existir acción para escribir un nombre nuevo de tratamiento.

Flujo esperado:
1. admin escribe el nombre
2. sistema normaliza/trimmea
3. sistema pide confirmación: “¿Confirmas crear este tratamiento con este nombre?”
4. si confirma, el tratamiento queda disponible en el selector

## Reglas de ortodoncia y seguimiento periódico

Todos los tratamientos actuales del dominio ortodóntico deben soportar:

- limpieza cada 3 meses
- control cada 6 meses

Esto debe quedar como parte de la ficha del tratamiento, no como una nota aislada.

Se recomienda manejarlo con dos cosas:

1. configuración de seguimiento sugerido del tratamiento
2. generación/sugerencia de citas asociadas al tratamiento

## UI propuesta

### En crear paciente

- selector de tratamientos existentes
- opción `Agregar nuevo tratamiento`
- si elige Convencional/Autoligado, mostrar subtipo obligatorio
- mostrar vista más ancha, porque el formulario crecerá con componentes financieros

### En detalle del paciente

- header con selector de tratamiento
- chip o tabs con tratamientos activos
- bloque visual con:
  - nombre del tratamiento
  - subtipo si aplica
  - etapa actual
  - estado
  - fecha de inicio
  - acciones rápidas

## Riesgos si no se hace así

- se mezcla la historia de varios tratamientos en un solo estado
- no se podrá saber sobre qué tratamiento se aplicó una cita o un cobro
- el tab de tratamiento se volverá ambiguo y difícil de usar

## Entregables de implementación sugeridos

- modelo de tratamiento por paciente
- provider/stream por tratamientos del paciente
- selector de tratamiento activo en UI admin
- formulario de creación/edición de tratamiento
- soporte para subtipo obligatorio
- soporte para marcar seguimiento 3m/6m

## Decisiones para validar con Jefe/doctora

- si `Brackets estéticos` seguirá existiendo como tratamiento visible propio o si debe convertirse en subtipo de Convencional/Autoligado
- si puede existir más de un tratamiento principal o solo uno marcado como principal
- si los tratamientos nuevos creados por admin quedan disponibles globalmente para toda la clínica
