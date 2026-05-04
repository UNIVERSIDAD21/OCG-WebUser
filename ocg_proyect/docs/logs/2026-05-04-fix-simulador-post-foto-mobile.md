# Fix simulador post-foto mobile

Fecha: 2026-05-04

## Problema reportado

En la validación humana Android del simulador se observó un bug real de UX/layout:

- el botón **Tomar foto** abría correctamente la cámara;
- la foto se tomaba y aceptaba correctamente;
- el borrador de simulación sí se creaba;
- la imagen original aparecía parcialmente al hacer scroll;
- pero el flujo quedaba confuso en móvil porque el admin no veía inmediatamente el borrador activo ni el botón **Generar con IA**.

Síntomas visibles:

- el historial aparecía antes que el flujo activo;
- había sensación de scroll anidado o de scroll “peleado”;
- la preview de la imagen original quedaba limitada y poco usable;
- después de tomar foto no había foco visual claro hacia el borrador recién creado.

Logs/hallazgos reportados además:

- cámara OK;
- procesamiento de imagen OK;
- intento de subida a Storage OK;
- ML Kit detectando/procesando imagen OK;
- warnings de App Check:
  - `App attestation failed`
  - `Too many attempts`

## Causa raíz

La causa principal no estaba en la cámara.

La raíz del problema estaba en la composición visual móvil del tab simulador:

1. `PatientSimulatorTab` renderizaba el **historial** antes del flujo activo.
2. `SimulatorScreen` usaba `SingleChildScrollView` incluso cuando estaba embebido dentro de un contenedor ya scrolleable.
3. En móvil, después de crear el borrador, el contenido importante quedaba abajo o fuera del foco visual inmediato.
4. No existía auto-scroll ni confirmación UX clara al terminar la captura.
5. La preview de la foto original tenía una altura corta para móvil y no ofrecía una forma directa de verla completa.

## Cambios hechos

### 1) Un solo dueño del scroll en móvil

Se agregó modo `embedded` en `SimulatorScreen`.

- Si `embedded=true`, **no** usa `SingleChildScrollView`.
- El scroll lo controla el padre (`PatientSimulatorTab` con `ListView`).
- Si el screen se usa como pantalla independiente, puede seguir usando su scroll propio.

### 2) Nueva jerarquía visual del tab simulador

En `PatientSimulatorTab` ahora la prioridad es:

1. header
2. acciones principales
3. flujo activo del simulador si existe borrador/ready/failed/generating
4. historial de simulaciones

Esto evita que un borrador recién creado quede escondido debajo del historial.

### 3) Foco automático después de tomar foto

Se añadió escucha al `simulatorFlowProvider` para detectar cuando el flujo pasa a `draftReady` con imagen original cargada.

Cuando eso ocurre:

- se muestra un `SnackBar`:
  - **“Foto cargada correctamente. Revisa el borrador y continúa con Generar con IA.”**
- se hace `scroll` automático hacia la sección activa del simulador.

### 4) Mejor preview de imagen original

Se mejoró la preview móvil de la imagen original:

- altura responsive mayor en móvil;
- botón **Ver foto completa**;
- apertura en diálogo con `InteractiveViewer` para zoom/pan;
- la imagen deja de sentirse “atrapada” en un bloque pequeño del scroll.

### 5) Mantener mensajes claros del backend IA

No se tocaron credenciales ni backend funcional del simulador.

Se mantuvo el mensaje claro para el caso sin API key:

- **“El simulador IA está instalado, pero falta configurar la API KEY en Firebase Functions.”**

## Cómo se espera que funcione ahora

Después de que el admin toque **Tomar foto** o **Subir desde galería** y se cree el borrador:

1. se crea el draft;
2. el tab hace foco visual en el flujo activo;
3. el admin ve inmediatamente:
   - estado **Borrador**,
   - imagen original,
   - botón **Generar con IA**,
   - mensaje de continuación;
4. el historial queda abajo, como contexto secundario;
5. la imagen original se puede abrir completa.

## Estado de App Check

Durante esta corrección **no** se desactivó App Check ni se tocaron reglas de seguridad.

Conclusión actual:

- por la evidencia del bug reportado, App Check **no parece ser la causa principal** del problema de UX móvil;
- el borrador sí se crea;
- la imagen original sí aparece;
- el problema principal era de layout/jerarquía/scroll.

Recomendación para entorno de pruebas humanas debug:

- revisar en Firebase si el entorno debug Android necesita configuración de App Check apropiada;
- registrar SHA/debug provider si aplica para builds de prueba;
- validar App Check en Firebase antes de la prueba humana final completa.

## Pruebas agregadas/ajustadas

Se agregaron pruebas enfocadas en el fix móvil:

- draft queda en estado `draftReady` después de `pickOriginalFromCamera`;
- `SimulatorScreen` embebido no crea scroll anidado;
- preview ofrece **Ver foto completa**;
- si falta API key se muestra mensaje claro al intentar generar;
- con borrador activo, el flujo activo aparece antes del historial.

## Validación ejecutada

### Validación enfocada del bloque

```bash
flutter analyze lib/features/patients/presentation/tabs/patient_simulator_tab.dart \
  lib/features/simulator/presentation/simulator_screen.dart \
  test/features/simulator/simulator_provider_test.dart \
  test/features/simulator/simulator_mobile_flow_test.dart

flutter test test/features/simulator/simulator_provider_test.dart \
  test/features/simulator/simulator_mobile_flow_test.dart
```

Resultado:

- `flutter analyze` ✅
- tests del bloque simulador ✅

## Pendiente para prueba humana

1. Repetir prueba en Android real con el APK debug actualizado.
2. Confirmar visualmente que después de tomar foto:
   - se ve el borrador arriba del historial,
   - aparece el CTA **Generar con IA**,
   - la imagen original se puede revisar completa.
3. Confirmar si los warnings de App Check en debug solo son warnings o afectan alguna operación real del entorno.
4. Validar que desktop siga cómodo visualmente, aunque esta corrección fue pensada para móvil sin rediseñar todo el módulo.
