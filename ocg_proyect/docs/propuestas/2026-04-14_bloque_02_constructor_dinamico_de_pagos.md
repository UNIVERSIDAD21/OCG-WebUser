# Bloque 02 — Constructor dinámico de pagos por tratamiento

## Objetivo

Reemplazar el modelo de “monto total fijo” por una estructura dinámica de conceptos financieros editables que se suman automáticamente al total del tratamiento.

## Qué entendemos del negocio

El admin necesita definir y editar libremente conceptos económicos del tratamiento, por ejemplo:

- Inicial
- Controles
- Retenedores
- Aparato 1
- Aparato 2
- Extras personalizados

Y el sistema debe:
- recalcular el total automáticamente
- permitir renombrar conceptos
- permitir agregar conceptos nuevos
- permitir eliminar algunos conceptos
- conservar ciertos conceptos obligatorios

## Reglas funcionales principales

### 1. Siempre mostrar estos componentes base

#### Si el tratamiento NO es Ortopedia
- Inicial
- Controles
- Retenedores

#### Si el tratamiento ES Ortopedia
- Inicial
- Controles
- Aparato 1

### 2. Inicial y Controles no se pueden eliminar

Sí se pueden:
- editar nombre
- editar monto

Pero no se pueden borrar.

### 3. Retenedores / Aparatos sí pueden crecer dinámicamente

El admin debe poder:
- editar nombre
- editar monto
- eliminar el ítem
- agregar uno nuevo

Ejemplos:
- Retenedor 2
- Retenedor superior
- Aparato 2
- Aparato de recambio
- Extra laboratorio

### 4. Total calculado automáticamente

El campo `Monto total del tratamiento` no debe llenarse manualmente como fuente primaria.

Debe ser la suma de:
- Inicial
- Controles
- Retenedores/Aparatos
- Extras

Puede seguir mostrándose visualmente, pero calculado desde arriba.

### 5. El admin puede renombrar etiquetas

Cada concepto debe tener:
- nombre editable por lápiz
- monto editable

Esto permite usar nombres reales del consultorio.

## Flujo propuesto de UI en Crear Paciente

Orden recomendado del formulario:

1. Tipo de tratamiento
2. Subtipo obligatorio si aplica
3. Monto de Inicial + lápiz editar nombre
4. Controles + lápiz editar nombre
5. Tercer bloque condicional:
   - Retenedores, si no es Ortopedia
   - Aparato 1, si es Ortopedia
6. Botón `Agregar nuevo`
7. Lista de conceptos adicionales creados
8. Campo visual de `Monto total del tratamiento` autocalculado

## Componentes visuales por fila

Cada fila de concepto debe incluir:
- nombre
- valor
- botón lápiz para renombrar
- botón basura para eliminar, excepto Inicial y Controles

## Ejemplo de comportamiento

### Caso 1: Convencional
- Inicial: 300.000
- Controles: 1.200.000
- Retenedores: 350.000
- Extra laboratorio: 100.000

Total = 1.950.000

### Caso 2: Ortopedia
- Inicial: 250.000
- Controles: 600.000
- Aparato 1: 400.000
- Aparato 2: 350.000

Total = 1.600.000

## Nuevo tratamiento desde Crear Paciente

Desde el mismo selector de tratamiento se debe poder:
- abrir flujo de `Agregar nuevo tratamiento`
- confirmar el nombre ingresado
- dejarlo disponible inmediatamente en la lista

Esto afecta el formulario porque el tipo de tratamiento ya no será completamente estático.

## Modelo sugerido

Dentro de cada tratamiento del paciente, guardar una colección o lista de conceptos:

```json
[
  {
    "id": "initial",
    "name": "Inicial",
    "kind": "required",
    "amount": 300000,
    "deletable": false,
    "editableName": true,
    "order": 1
  }
]
```

Campos sugeridos por concepto:
- `id`
- `name`
- `amount`
- `kind` (`initial`, `controls`, `retainers`, `device`, `extra`, etc.)
- `deletable`
- `editableName`
- `order`
- `createdByAdmin`

Y a nivel de tratamiento:
- `financialItems`
- `totalAmount`
- `currency`
- `lastPricingUpdateAt`

## Reglas de UX

- recalcular total en tiempo real
- no perder cambios al cambiar de tipo de tratamiento sin advertencia
- si se cambia a Ortopedia, convertir la tercera fila base a `Aparato 1`
- si se cambia desde Ortopedia a otro tratamiento, convertir la estructura a `Retenedores` o pedir confirmación

## Riesgos si no se resuelve bien

- los pagos no cuadrarán con el tratamiento real
- la doctora perderá flexibilidad para precios reales
- el admin terminará usando notas manuales fuera del sistema

## Entregables sugeridos

- widget/form builder dinámico de conceptos financieros
- modelo persistente de conceptos por tratamiento
- cálculo automático del total
- edición de nombres y eliminación controlada
- integración en crear paciente y en tab Tratamiento

## Decisiones para validar

- si el total debe poder ser excepcionalmente editado manualmente o siempre calculado
- si los nombres custom quedan guardados solo para ese tratamiento o también como plantillas reutilizables
- si los extras deben clasificarse por tipo (laboratorio, retenedor extra, aparato extra, procedimiento, etc.)
