# Bloque 02 — Constructor dinámico de pagos por tratamiento

## Objetivo

Reemplazar el modelo de “monto total fijo” por una estructura dinámica de conceptos financieros editables asociados a cada tratamiento del paciente.

El total del tratamiento ya no debe ser un campo escrito manualmente como fuente principal. Debe calcularse automáticamente a partir de los conceptos financieros configurados para ese tratamiento.

Este bloque depende directamente del Bloque 01, porque cada estructura financiera debe pertenecer a un tratamiento específico mediante `treatmentId`.

---

## Qué entendemos del negocio

El admin necesita definir y editar libremente los conceptos económicos de un tratamiento, por ejemplo:

- Inicial
- Controles
- Retenedores
- Aparato 1
- Aparato 2
- Extras personalizados
- Procedimientos adicionales
- Ajustes clínicos o de laboratorio

El sistema debe permitir:

- recalcular el total automáticamente,
- renombrar conceptos,
- agregar conceptos nuevos,
- eliminar conceptos permitidos,
- conservar conceptos obligatorios,
- asociar pagos reales al tratamiento correcto,
- mantener trazabilidad de cambios financieros.

---

## Regla central del bloque

Los pagos no deben seguir dependiendo de un monto plano en `PatientModel`.

La estructura financiera debe vivir dentro del tratamiento:

```txt
patients/{patientId}
patients/{patientId}/treatments/{treatmentId}
patients/{patientId}/treatments/{treatmentId}/financialItems/{itemId}
```

También puede usarse una lista embebida si el volumen es pequeño, pero la recomendación más mantenible es subcolección, porque permite auditoría, edición individual e historial.

---

## Relación obligatoria con tratamiento

Todo concepto financiero debe tener:

```txt
patientId
treatmentId
```

Esto es obligatorio para evitar que los pagos de un tratamiento se mezclen con otro.

Ejemplo:

```json
{
  "id": "initial",
  "patientId": "patientId",
  "treatmentId": "treatmentId",
  "name": "Inicial",
  "normalizedName": "inicial",
  "kind": "initial",
  "amount": 300000,
  "currency": "COP",
  "deletable": false,
  "editableName": true,
  "order": 1,
  "active": true,
  "createdByAdmin": true,
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

---

## Conceptos base obligatorios

### Si el tratamiento NO es Ortopedia

Deben aparecer como base:

- Inicial
- Controles
- Retenedores

### Si el tratamiento ES Ortopedia

Deben aparecer como base:

- Inicial
- Controles
- Aparato 1

---

## Reglas de eliminación

### Inicial y Controles

No se pueden eliminar.

Sí se pueden:

- editar nombre,
- editar monto,
- cambiar orden visual si es necesario.

No se pueden:

- borrar,
- desactivar sin trazabilidad,
- dejar con nombre vacío.

### Retenedores, Aparatos y Extras

Sí se pueden:

- editar nombre,
- editar monto,
- eliminar o desactivar,
- agregar nuevos ítems similares.

Recomendación: en vez de borrar físicamente, usar `active: false` cuando ya existan pagos asociados.

---

## Total calculado automáticamente

El tratamiento debe tener un resumen financiero cacheado, pero no como fuente manual principal.

Campos sugeridos en el documento del tratamiento:

```json
{
  "financialSummary": {
    "currency": "COP",
    "subtotalAmount": 1950000,
    "discountAmount": 0,
    "totalAmount": 1950000,
    "paidAmount": 500000,
    "pendingAmount": 1450000,
    "itemsCount": 4,
    "lastPricingUpdateAt": "timestamp"
  }
}
```

### Regla crítica

`totalAmount` debe ser resultado de la suma de los conceptos activos.

No debe ser escrito manualmente sin respaldo de conceptos.

---

## Descuentos y ajustes

Aunque no sea obligatorio para la primera versión, el modelo debe quedar preparado para:

- descuento global,
- descuento por concepto,
- ajuste manual autorizado,
- observación del ajuste,
- usuario que aplicó el ajuste.

Si no se implementa todavía, al menos no bloquear el modelo para agregarlo después.

---

## Pagos reales vs conceptos financieros

Este bloque construye la estructura del valor del tratamiento, pero no debe confundirse con los pagos realizados.

Diferencia:

- `financialItems`: lo que cuesta el tratamiento.
- `payments` o `transactions`: lo que el paciente ha pagado.

Recomendación futura:

```txt
patients/{patientId}/treatments/{treatmentId}/payments/{paymentId}
```

o mantener la colección actual `payments`, pero agregando siempre:

```txt
patientId
treatmentId
```

---

## Migración de datos actuales

Este punto es obligatorio.

Si actualmente existe un monto plano en el paciente, por ejemplo:

```txt
totalAmount
treatmentAmount
initialPayment
monthlyPayment
paymentSummary
```

Borlty debe crear compatibilidad temporal o migración.

### Estrategia recomendada

1. Leer pacientes existentes.
2. Detectar su tratamiento principal creado en Bloque 01.
3. Crear conceptos financieros base.
4. Copiar valores existentes cuando sea posible.
5. Si no hay desglose, crear un concepto temporal llamado `Valor tratamiento anterior`.
6. Marcar el total antiguo como dato legado.
7. No borrar datos anteriores hasta validar.

Ejemplo de concepto legado:

```json
{
  "name": "Valor tratamiento anterior",
  "kind": "legacy",
  "amount": 1800000,
  "deletable": false,
  "editableName": true,
  "active": true
}
```

---

## Flujo propuesto de UI en Crear Paciente

Orden recomendado del formulario:

1. Tipo de tratamiento.
2. Subtipo obligatorio si aplica.
3. Monto de Inicial + lápiz para editar nombre.
4. Controles + lápiz para editar nombre.
5. Tercer bloque condicional:
   - Retenedores, si no es Ortopedia.
   - Aparato 1, si es Ortopedia.
6. Botón `Agregar nuevo concepto`.
7. Lista de conceptos adicionales.
8. Campo visual de `Monto total del tratamiento` autocalculado.
9. Resumen financiero visible antes de guardar.

---

## Flujo propuesto en detalle del paciente

Dentro del tab Tratamiento o Pagos debe poder verse:

- tratamiento seleccionado,
- conceptos financieros del tratamiento,
- total calculado,
- total pagado,
- saldo pendiente,
- historial de pagos si ya existe,
- botón para editar conceptos,
- advertencia si hay cambios que afectan el saldo.

---

## Componentes visuales por fila

Cada fila debe incluir:

- nombre del concepto,
- valor,
- botón lápiz para renombrar,
- botón para editar monto,
- botón basura o desactivar, excepto Inicial y Controles,
- indicador de obligatorio/opcional,
- orden visual.

---

## Reglas de validación

- No permitir montos negativos.
- No permitir nombres vacíos.
- No permitir guardar si Inicial o Controles no existen.
- No permitir eliminar conceptos obligatorios.
- No permitir cambiar de tratamiento y perder cambios sin advertencia.
- Si se cambia a Ortopedia, convertir o confirmar cambio de `Retenedores` a `Aparato 1`.
- Si se cambia desde Ortopedia a otro tratamiento, convertir o confirmar cambio de `Aparato 1` a `Retenedores`.
- Todos los montos deben manejarse en COP por defecto.

---

## Auditoría financiera

Todo cambio financiero importante debe dejar trazabilidad.

Campos mínimos sugeridos:

```txt
createdBy
updatedBy
createdAt
updatedAt
lastPricingUpdateAt
```

Idealmente, crear después una subcolección:

```txt
patients/{patientId}/treatments/{treatmentId}/financialAudit/{auditId}
```

Para registrar:

- concepto creado,
- concepto editado,
- monto anterior,
- monto nuevo,
- usuario admin,
- fecha,
- motivo opcional.

---

## Seguridad y permisos

Este bloque no debe quedar solo en UI.

Reglas mínimas:

- Solo admin puede crear, editar o eliminar conceptos financieros.
- El paciente puede leer su resumen financiero si la app lo muestra.
- Un paciente no puede leer pagos o conceptos de otro paciente.
- Las operaciones críticas deben validarse por rol.
- Si se usan Cloud Functions, deben recalcular el total en backend.

---

## Recomendación técnica

Para evitar manipulación desde cliente, lo ideal es que el cálculo final del total se haga o se valide en backend.

Opciones:

1. Cliente calcula en tiempo real para UX y backend valida al guardar.
2. Cloud Function recalcula `financialSummary` al crear/editar/eliminar conceptos.
3. Repositorio centralizado evita escrituras sueltas desde cualquier pantalla.

La opción más segura es combinar 1 y 2.

---

## Providers / repositorios sugeridos

Borlty debe implementar o ajustar:

- `FinancialItemModel`
- `TreatmentFinancialSummaryModel`
- `TreatmentFinancialRepository`
- provider de conceptos financieros por tratamiento,
- provider de total calculado en tiempo real,
- integración con `TreatmentModel`,
- compatibilidad temporal con pagos existentes.

---

## Entregables de implementación

Borlty debe entregar:

1. Modelo persistente de conceptos financieros por tratamiento.
2. Total calculado automáticamente.
3. UI dinámica en crear paciente.
4. UI de edición en detalle del paciente.
5. Reglas para Inicial y Controles no eliminables.
6. Retenedores/Aparatos/Extras dinámicos.
7. Migración o compatibilidad con montos anteriores.
8. Resumen financiero cacheado en el tratamiento.
9. Seguridad por rol admin.
10. Validación manual con mínimo:
   - tratamiento Convencional,
   - tratamiento Ortopedia,
   - concepto agregado,
   - concepto eliminado,
   - cambio de monto,
   - paciente existente con monto anterior.

---

## Riesgos si no se resuelve bien

- Los pagos no cuadrarán con el tratamiento real.
- La doctora perderá flexibilidad para precios reales.
- Los cobros de varios tratamientos se mezclarán.
- El admin terminará usando notas manuales fuera del sistema.
- El paciente podría ver saldos incorrectos.
- El Bloque 04 podría generar recordatorios o mensajes financieros ambiguos.

---

## Decisiones para validar con Jefe/doctora

- Si el total podrá editarse manualmente en casos excepcionales.
- Si los nombres personalizados quedan solo en ese tratamiento o como plantillas.
- Si los extras deben clasificarse por tipo.
- Si los pagos se asociarán directamente al tratamiento o seguirán en colección global con `treatmentId`.
- Si el paciente verá el desglose completo o solo resumen.
- Si habrá descuentos o ajustes autorizados.

---

## Criterio de aceptación del Bloque 02

El bloque se considera terminado cuando:

- Cada tratamiento tiene sus propios conceptos financieros.
- El total se calcula automáticamente.
- Inicial y Controles no pueden eliminarse.
- Ortopedia usa Aparato 1 como tercer concepto base.
- Otros tratamientos usan Retenedores como tercer concepto base.
- El admin puede agregar, editar y eliminar conceptos permitidos.
- Los pacientes existentes no pierden su información financiera.
- El modelo queda preparado para pagos reales y saldos por tratamiento.

# Bloque 02 — Constructor dinámico de pagos por tratamiento

## 1) Problemática

Borlty, el Bloque 02 tampoco está cumplido. El constructor dinámico de pagos por tratamiento no está funcionando y el sistema sigue comportándose como si dependiera de un modelo viejo de monto plano.

### Hallazgos reales reportados en pruebas

- No funciona el caso de tratamiento Convencional con conceptos base:
  - Inicial
  - Controles
  - Retenedores
- No funciona el caso de tratamiento Ortopedia con conceptos base:
  - Inicial
  - Controles
  - Aparato 1
- El sistema no distingue correctamente cuándo deben aparecer Retenedores y cuándo Aparatos.
- No funciona el total calculado automáticamente.
- No funciona renombrar Inicial.
- No funciona editar el monto de Controles.
- No están materializados los montos por concepto para:
  - Inicial,
  - Controles,
  - Retenedores,
  - Aparatos,
  - Extras.
- Tampoco existe un constructor realmente ligado a `treatmentId` como se pidió.
- Persistencia, resumen financiero, auditoría y seguridad tampoco pueden darse por cumplidos bajo este estado.

### Lo que este bloque debía lograr y no logró

Este bloque debía reemplazar el modelo de “monto total fijo” por una estructura de conceptos financieros editables asociada a cada tratamiento.

Eso implicaba:

- conceptos base automáticos según tipo de tratamiento,
- total autocalculado,
- edición de nombre y monto donde aplique,
- extras dinámicos,
- reglas de eliminación,
- trazabilidad,
- resumen financiero cacheado,
- separación entre costo del tratamiento y pagos reales,
- compatibilidad con datos viejos.

Hoy eso no está ocurriendo.

---

## 2) Análisis Problemática

### A. No cambiaste el paradigma del modelo

El Bloque 02 no era un “formulario para editar un total”. Era cambiar la fuente de verdad del precio del tratamiento. Si el total sigue siendo manual o plano, el bloque no existe realmente.

### B. No existe constructor real por tratamiento

Toda esta lógica dependía de que cada tratamiento tuviera sus propios conceptos financieros. Si no están ligados a `treatmentId`, entonces cualquier intento de editar precios sigue siendo ambiguo y peligroso.

### C. La lógica condicional por tipo de tratamiento no fue implementada

La regla era clara:

#### Si NO es Ortopedia
- Inicial
- Controles
- Retenedores

#### Si SÍ es Ortopedia
- Inicial
- Controles
- Aparato 1

Si eso no ocurre automáticamente, entonces el corazón del bloque no está construido.

### D. El total no nace de los conceptos activos

Si no existe suma de conceptos activos, no existe `financialSummary` confiable. Y si no existe resumen financiero confiable, luego tampoco se podrán calcular bien pagado, pendiente, auditoría ni mensajes futuros.

### E. No existe una UI verdaderamente funcional de edición

Si no puedes:

- renombrar Inicial,
- editar Controles,
- agregar extras,
- desactivar elementos opcionales,
- ver total recalculado,

entonces no hay constructor dinámico; hay una maqueta incompleta.

### F. No hay separación clara entre costo y pagos reales

Debías diferenciar entre:

- `financialItems`: lo que cuesta el tratamiento,
- `payments`: lo que el paciente ha pagado.

Si todo sigue mezclado en un resumen viejo y confuso, el diseño financiero sigue mal.

### G. No quedó preparada migración seria

Los pacientes con información antigua no pueden quedar en el limbo. Si no migras ni mantienes compatibilidad temporal, el sistema queda inconsistente.

---

## 3) Solución Problemática

Vas a implementar correctamente el Bloque 02 sobre una base estable de `treatmentId`.

### A. Mover definitivamente la estructura financiera al tratamiento

La estructura financiera debe vivir dentro del tratamiento:

```txt
patients/{patientId}
patients/{patientId}/treatments/{treatmentId}
patients/{patientId}/treatments/{treatmentId}/financialItems/{itemId}
```

Cada concepto financiero debe tener obligatoriamente:

- `patientId`
- `treatmentId`
- `name`
- `normalizedName`
- `kind`
- `amount`
- `currency`
- `deletable`
- `editableName`
- `order`
- `active`
- `createdAt`
- `updatedAt`
- `createdBy`
- `updatedBy`

### B. Crear conceptos base automáticos por tipo de tratamiento

#### Si el tratamiento NO es Ortopedia
Deben aparecer automáticamente:

- Inicial
- Controles
- Retenedores

#### Si el tratamiento ES Ortopedia
Deben aparecer automáticamente:

- Inicial
- Controles
- Aparato 1

Esto debe hacerse de forma real, no solo visual.

### C. Reglas obligatorias por concepto

#### Inicial y Controles
Sí se pueden:

- renombrar,
- editar monto,
- cambiar orden visual si aplica.

No se pueden:

- eliminar,
- dejar vacíos,
- desactivar sin trazabilidad.

#### Retenedores, Aparatos y Extras
Sí se pueden:

- renombrar,
- editar monto,
- eliminar o desactivar,
- agregar nuevos conceptos similares.

Si ya tienen pagos asociados, preferir:

```txt
active: false
```

en lugar de borrado físico.

### D. Implementar total autocalculado real

El documento del tratamiento debe tener un `financialSummary` cacheado, pero derivado de conceptos activos.

Campos mínimos:

- `currency`
- `subtotalAmount`
- `discountAmount`
- `totalAmount`
- `paidAmount`
- `pendingAmount`
- `itemsCount`
- `lastPricingUpdateAt`

Regla crítica:

`totalAmount` debe ser el resultado de la suma de los conceptos activos. No puede ser un número manual sin respaldo.

### E. Permitir extras y conceptos nuevos

Debe existir flujo real para:

- `Agregar nuevo concepto`,
- escribir nombre,
- definir monto,
- guardar,
- entrar automáticamente al total,
- editarlo después,
- desactivarlo si corresponde.

### F. Manejar correctamente cambio de tipo de tratamiento

Si el tratamiento cambia:

#### De no Ortopedia a Ortopedia
Debes convertir o pedir confirmación para pasar de `Retenedores` a `Aparato 1`.

#### De Ortopedia a otro tipo
Debes convertir o pedir confirmación para pasar de `Aparato 1` a `Retenedores`.

Nunca debe perderse información sin advertencia.

### G. Separar estructura de costos y pagos reales

No mezcles:

- lo que cuesta el tratamiento,
- con lo que el paciente ya pagó.

Recomendación:

```txt
patients/{patientId}/treatments/{treatmentId}/payments/{paymentId}
```

o mantener la colección actual de pagos, pero siempre con:

- `patientId`
- `treatmentId`

### H. Compatibilidad o migración de datos actuales

Si hoy existen campos antiguos como:

- `totalAmount`
- `treatmentAmount`
- `initialPayment`
- `monthlyPayment`
- `paymentSummary`

Debes:

1. leer pacientes existentes,
2. detectar tratamiento principal,
3. crear conceptos base,
4. copiar valores existentes si se pueden mapear,
5. si no hay desglose, crear concepto legado `Valor tratamiento anterior`,
6. marcar el total antiguo como legado,
7. no borrar nada viejo hasta validar.

### I. Corregir la UI en crear paciente y detalle del paciente

#### En crear paciente o flujo equivalente
Debe existir:

1. tipo de tratamiento,
2. subtipo si aplica,
3. monto Inicial,
4. monto Controles,
5. tercer concepto condicional,
6. botón agregar nuevo concepto,
7. lista de conceptos adicionales,
8. monto total autocalculado,
9. resumen financiero visible antes de guardar.

#### En detalle del paciente
Debe mostrarse:

- tratamiento seleccionado,
- conceptos financieros,
- total calculado,
- total pagado,
- saldo pendiente,
- historial de pagos si existe,
- botón para editar conceptos,
- advertencia si cambios afectan el saldo.

### J. Auditoría y seguridad

Debes registrar al menos:

- `createdBy`
- `updatedBy`
- `createdAt`
- `updatedAt`
- `lastPricingUpdateAt`

Y las reglas mínimas son:

- solo admin puede crear, editar o eliminar conceptos,
- el paciente solo ve lo que le corresponda,
- el cliente no define libremente el total final sin validación,
- idealmente el backend recalcula o valida el resumen financiero.

### K. Entregables obligatorios

No cierres este bloque hasta entregar de verdad:

1. Modelo persistente de conceptos financieros por tratamiento.
2. Total calculado automáticamente.
3. UI dinámica funcional.
4. UI de edición en detalle del paciente.
5. Reglas de Inicial y Controles no eliminables.
6. Retenedores / Aparatos / Extras dinámicos.
7. Migración o compatibilidad con montos anteriores.
8. Resumen financiero cacheado por tratamiento.
9. Seguridad por rol admin.
10. Validación manual real con:
   - tratamiento Convencional,
   - tratamiento Ortopedia,
   - concepto agregado,
   - concepto eliminado,
   - cambio de monto,
   - paciente existente con monto anterior.

### L. Criterio de aceptación real

El Bloque 02 solo se considera terminado cuando:

- cada tratamiento tiene sus propios conceptos financieros,
- el total se calcula automáticamente,
- Inicial y Controles no se pueden eliminar,
- Ortopedia usa Aparato 1 como tercer concepto base,
- otros tratamientos usan Retenedores,
- el admin puede agregar, editar y eliminar conceptos permitidos,
- los pacientes existentes no pierden información,
- el modelo queda preparado para pagos reales y saldos por tratamiento.

---

## 4) Regaña al desarrollador

Borlty, aquí entregaste humo financiero. Si no existen los conceptos base funcionando, si el sistema no distingue Ortopedia de los demás, si no hay montos por concepto y si el total no se calcula desde los ítems activos, entonces el constructor dinámico no existe. Punto.

No puedes disfrazar un modelo viejo con una UI nueva y decir que el bloque está listo. Este bloque era crítico porque ordena el cobro real del tratamiento. Si eso queda mal, después todo se contamina: saldo, pagos, historial, reportes y hasta mensajes al paciente.

Deja de cerrar bloques por aproximación. Quiero modelo real por `treatmentId`, conceptos funcionando, total derivado, compatibilidad con datos viejos y seguridad de verdad. Hasta que eso no exista, este bloque sigue incumplido.

