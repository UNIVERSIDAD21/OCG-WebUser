# OCG CLÍNICA — ÍNDICE MAESTRO DE BLOQUES DEL AGENTE

> **Para Borlty (OpenClaw):** Lee este archivo primero. Siempre. Es tu mapa de navegación del proyecto.
> **Actualizado:** 2026-03-09

---

## Arquitectura del ecosistema de documentos

```
docs/
├── specs/              ← Especificaciones técnicas detalladas (ya existían)
│   ├── 00_INDICE_GENERAL.md
│   ├── 01_ARQUITECTURA_Y_SETUP.md
│   ├── 02_BASE_DE_DATOS.md
│   ├── 03_AUTENTICACION_Y_ROLES.md
│   ├── 04_GESTION_PACIENTES.md
│   ├── 05_AGENDA_CITAS.md
│   ├── 06_TRATAMIENTO_Y_ETAPAS.md
│   ├── 07_PAGOS.md
│   ├── 08_SIMULADOR_SONRISA.md
│   └── 09_NOTIFICACIONES_FCM.md
│
├── work_orders/        ← Work orders por bloque (ya existían algunos)
│   └── WORK_ORDER_GESTION_PACIENTES.md
│
├── logs/               ← Log técnico diario
│   └── 2026-03-07.md
│
└── bloques/            ← ⬅️ AQUÍ ES DONDE VAS TÚ, BORLTY
    ├── ESTADO_ACTUAL_PROYECTO.md   ← LEE ESTO PRIMERO
    ├── BLOQUE_06_TRATAMIENTO_ETAPAS.md
    ├── BLOQUE_07_PAGOS.md
    ├── BLOQUE_08_SIMULADOR.md
    ├── BLOQUE_09_NOTIFICACIONES_CLOUD.md
    └── BLOQUE_10_DASHBOARD_PULIDO.md
```

---

## Estado actual de los bloques

| Bloque | Módulo | Estado | Archivo de trabajo |
|--------|--------|--------|--------------------|
| 01 | Arquitectura y Setup | ✅ CERRADO | docs/specs/01_ARQUITECTURA_Y_SETUP.md |
| 02 | Base de datos | ✅ CERRADO | docs/specs/02_BASE_DE_DATOS.md |
| 03 | Autenticación y Roles | ✅ CERRADO | docs/specs/03_AUTENTICACION_Y_ROLES.md |
| 04 | Gestión de Pacientes | ✅ CERRADO | docs/work_orders/WORK_ORDER_GESTION_PACIENTES.md |
| 05 | Agenda de Citas | ✅ CERRADO | docs/specs/05_AGENDA_CITAS.md |
| **06** | **Tratamiento y Etapas** | **⬅️ EMPIEZA AQUÍ** | docs/bloques/BLOQUE_06_TRATAMIENTO_ETAPAS.md |
| 07 | Pagos | ⬜ Pendiente | docs/bloques/BLOQUE_07_PAGOS.md |
| 08 | Simulador de Sonrisa | ⬜ Pendiente | docs/bloques/BLOQUE_08_SIMULADOR.md |
| 09 | Notificaciones + Cloud Functions | ⬜ Pendiente | docs/bloques/BLOQUE_09_NOTIFICACIONES_CLOUD.md |
| 10 | Dashboard + Pulido UI | ⬜ Pendiente | docs/bloques/BLOQUE_10_DASHBOARD_PULIDO.md |

---

## Reglas absolutas para Borlty

### Antes de empezar cualquier bloque:
1. Lee `ESTADO_ACTUAL_PROYECTO.md` para saber qué existe
2. Lee el archivo `BLOQUE_XX_...md` del bloque activo completo
3. Lee los `docs/specs/` relevantes para ese bloque
4. Ejecuta `flutter analyze` y `flutter test` para verificar que la base está limpia

### Durante la implementación:
1. **Riverpod para todo el estado** — cero `setState` fuera de widgets 100% locales
2. **Repositorios como única puerta a Firestore** — la UI nunca llama directo a `FirebaseFirestore`
3. **Tema OCG siempre** — cero `Colors.blue` fuera de `ocg_colors.dart`
4. **Errores visibles al usuario** — cero fallos silenciosos, cero `print()` en producción
5. **Batch atómico para operaciones de dos colecciones** — nunca escrituras separadas

### Al cerrar un bloque:
1. Ejecutar `flutter analyze` — debe pasar sin warnings
2. Ejecutar `flutter test` — debe pasar sin fallos
3. Marcar los checkboxes del bloque completados
4. Actualizar `docs/logs/` con el log del día
5. Marcar el bloque como ✅ CERRADO en este índice

### Nunca:
- Tocar bloques ya cerrados sin una razón explícita
- Hardcodear strings de colecciones Firestore (usar `FirestorePaths`)
- Hardcodear colores (usar `OcgColors`)
- Llamar a Firebase directamente desde la UI
- Saltarse un bloque — el orden importa por dependencias

---

## Cómo actualizar este índice

Cuando Borlty cierre un bloque, actualizar la tabla de estado:
- Cambiar `⬅️ EMPIEZA AQUÍ` por `✅ CERRADO`
- Mover `⬅️ EMPIEZA AQUÍ` al siguiente bloque pendiente
- Agregar la fecha de cierre en la columna de notas si se desea

---

## Contexto del negocio (no olvidar)

Este es un sistema clínico real. Hay pacientes reales, datos de salud, pagos reales. La doctora confía en que el sistema funciona. Cada decisión técnica tiene consecuencia real. No es un ejercicio.

**La prioridad siempre es:** correcto > rápido > elegante.
