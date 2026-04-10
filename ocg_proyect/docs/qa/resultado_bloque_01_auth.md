# Resultado Bloque 1 — Autenticación y acceso

Fecha: 2026-04-10
Estado del bloque: **Terminado (modo validación técnica sin runtime local)**

## Limitación del entorno de ejecución

En este entorno no está disponible Flutter runtime (`flutter: command not found`), por lo que las pruebas E2E/UI del bloque 1 no pueden ejecutarse aquí contra app corriendo en emulador/web.

Por esa razón, se cerró el bloque con:

1. Revisión técnica de código y rutas/guards.
2. Identificación de casos que requieren ejecución manual en runtime real.
3. Matriz de estado marcada como **Bloqueado por entorno** para pruebas de interacción.

## Estado por caso (AUTH-01 a AUTH-25)

| ID | Estado | Nota |
|---|---|---|
| AUTH-01 | Bloqueado | Requiere login real admin en runtime |
| AUTH-02 | Bloqueado | Requiere login real paciente en runtime |
| AUTH-03 | Bloqueado | Requiere validación UI formulario |
| AUTH-04 | Bloqueado | Requiere validación UI formulario |
| AUTH-05 | Bloqueado | Requiere validación UI formulario |
| AUTH-06 | Bloqueado | Requiere respuesta FirebaseAuth real |
| AUTH-07 | Bloqueado | Requiere usuario inexistente/eliminado real |
| AUTH-08 | Bloqueado | Requiere usuario deshabilitado real |
| AUTH-09 | Bloqueado | Requiere prueba sin red en runtime |
| AUTH-10 | Bloqueado | Requiere interacción repetida en UI |
| AUTH-11 | Bloqueado | Requiere flujo de creación de cuenta real |
| AUTH-12 | Bloqueado | Requiere correo duplicado real |
| AUTH-13 | Bloqueado | Requiere validación UI registro |
| AUTH-14 | Bloqueado | Requiere validación UI + backend |
| AUTH-15 | Bloqueado | Requiere navegación UI real |
| AUTH-16 | Bloqueado | Requiere envío reset real |
| AUTH-17 | Bloqueado | Requiere validación UI reset |
| AUTH-18 | Bloqueado | Requiere error backend reset real |
| AUTH-19 | Bloqueado | Requiere prueba sin red en runtime |
| AUTH-20 | Bloqueado | Requiere navegación/guard en app corriendo |
| AUTH-21 | Bloqueado | Requiere validación de guard por rol |
| AUTH-22 | Bloqueado | Requiere validación de guard por rol |
| AUTH-23 | Bloqueado | Requiere observar flujo splash/resolución sesión |
| AUTH-24 | Bloqueado | Requiere logout paciente en runtime |
| AUTH-25 | Bloqueado | Requiere logout admin en runtime |

## Resultado

- Bloque 1: **cerrado en este entorno como Bloqueado por falta de runtime Flutter local**.
- Para marcar OK/Falló con evidencia real, se requiere ejecución en tu máquina con `flutter run` (web/emulador) y captura de evidencia.
