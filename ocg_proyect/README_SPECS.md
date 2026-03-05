# README_SPECS.md

## Fuente de verdad del sistema

La carpeta `docs/specs/` es la **fuente de verdad permanente** para el diseño funcional y técnico de OCG.
Toda decisión de producto, arquitectura e implementación debe alinearse con estos documentos.

## Orden obligatorio de lectura

Antes de implementar cambios, el orden base de lectura es:

1. `docs/specs/00_INDICE_GENERAL.md`
2. `docs/specs/01_ARQUITECTURA_Y_SETUP.md`
3. `docs/specs/02_BASE_DE_DATOS.md`
4. `docs/specs/03_AUTENTICACION_Y_ROLES.md`
5. `docs/specs/09_NOTIFICACIONES_FCM.md`

Luego revisar para contexto:

6. `docs/specs/04_GESTION_PACIENTES.md`
7. `docs/specs/05_AGENDA_CITAS.md`
8. `docs/specs/06_TRATAMIENTO_Y_ETAPAS.md`
9. `docs/specs/07_PAGOS.md`
10. `docs/specs/08_SIMULADOR_SONRISA.md`

## Regla de desarrollo

Todo desarrollo nuevo debe respetar explícitamente estas especificaciones.
Si hay conflicto entre código existente y specs, se documenta el gap y se corrige por bloque aprobado.

## Bloque activo

El bloque activo de trabajo se define en:

- `docs/work_orders/`

El archivo de work order vigente es el contrato operativo del bloque actual.
