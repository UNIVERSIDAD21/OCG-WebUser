# Reunión doctora admin — índice de propuesta (2026-04-14)

Este paquete traduce la reunión funcional a 4 bloques de trabajo para revisión antes de implementación.

## Objetivo general

Extender OCG-WebUser para que la web admin maneje mejor el ciclo clínico completo del paciente:

- múltiples tratamientos activos por paciente
- estructura financiera editable por tratamiento
- historial clínico basado en archivos
- recordatorios automáticos de citas por WhatsApp y por la app

## Bloques creados

1. `docs/propuestas/2026-04-14_bloque_01_tratamientos_multiples_y_etapas.md`
   - modelo funcional para múltiples tratamientos activos
   - selector de tratamiento en paciente/admin
   - etapas por tratamiento
   - subtipos obligatorios en convencional/autoligado

2. `docs/propuestas/2026-04-14_bloque_02_constructor_dinamico_de_pagos.md`
   - desglose editable: total, inicial, controles, retenedores/aparatos y extras
   - alta de nuevos tratamientos desde crear paciente
   - reglas visuales del formulario grande de admin

3. `docs/propuestas/2026-04-14_bloque_03_historial_clinico_por_archivos.md`
   - historia clínica por carga de archivos
   - organización por paciente y opcionalmente por tratamiento
   - permisos, vistas y acciones admin

4. `docs/propuestas/2026-04-14_bloque_04_recordatorios_automaticos_citas.md`
   - recordatorios automáticos 1 día antes y 1 hora antes
   - envío por WhatsApp y por aplicación
   - reglas de programación, estados y tolerancia a duplicados

## Principios acordados

- No limitar a un paciente a un solo tratamiento activo.
- Cada tratamiento debe poder distinguirse claramente dentro del perfil del paciente.
- Los tratamientos actuales del sistema pertenecen al dominio de ortodoncia y deben soportar seguimiento periódico de 3 y 6 meses.
- El admin puede crear nuevos tratamientos y el sistema debe pedir confirmación del nombre.
- El total financiero no es un valor plano, sino una suma automática de conceptos editables.
- El historial clínico será documental, con archivos cargados por la doctora/admin.

## Orden recomendado de implementación

1. Bloque 01: tratamientos múltiples y etapas
2. Bloque 02: constructor dinámico de pagos
3. Bloque 03: historial clínico por archivos
4. Bloque 04: recordatorios automáticos

## Motivo del orden

- Bloque 01 define la nueva unidad central del sistema: el tratamiento.
- Bloque 02 depende del tratamiento como contenedor financiero.
- Bloque 03 depende de poder asociar archivos a paciente y, si aplica, a tratamiento.
- Bloque 04 depende de citas y tratamientos ya bien estructurados para sugerencias/seguimientos.

## Preguntas abiertas para retroalimentación

- ¿Los controles de 3 y 6 meses deben autogenerarse al cerrar una etapa, al cerrar el tratamiento o cuando el admin marque “finalizado”?
- ¿Los nuevos tratamientos creados por admin serán globales para toda la clínica o solo disponibles para el paciente actual hasta confirmarlos?
- ¿El historial clínico debe aceptar solo PDF e imágenes o cualquier archivo?
- ¿WhatsApp se enviará por número del paciente, acudiente o ambos?
