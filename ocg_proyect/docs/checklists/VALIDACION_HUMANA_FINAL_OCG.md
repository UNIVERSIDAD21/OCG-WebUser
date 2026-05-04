# Validación humana final OCG

Fecha base: 2026-05-04

> Objetivo: ejecutar una secuencia segura y repetible para validar localmente el estado final del proyecto antes de activar credenciales reales o considerar despliegue.
>
> Alcance: este kit **no** despliega, **no** configura credenciales automáticamente y **no** modifica producción.

---

## 1. Preparación local

### Qué hacer

1. Confirmar que estás en el repo correcto.
2. Confirmar rama y commit a validar.
3. Verificar que el working tree esté limpio o documentar diferencias.
4. Confirmar herramientas instaladas:
   - Flutter
   - Android SDK
   - Node.js / npm
   - Xcode y CocoaPods si vas a validar iOS
5. Preparar archivo de evidencia:
   - `docs/checklists/EVIDENCIA_VALIDACION_HUMANA.md`

### Qué observar

- rama esperada (`main` o la rama aprobada)
- commit exacto
- `git status --short` sin cambios inesperados
- Android SDK visible para Flutter si se validará build Android

### Evidencia a guardar

- salida de:
  - `git branch --show-current`
  - `git rev-parse --short HEAD`
  - `git status --short`
  - `flutter doctor -v`

---

## 2. Validación técnica local

### Qué hacer

Desde `ocg_proyect` ejecutar:

```bash
flutter pub get
flutter analyze
flutter test
```

Desde `ocg_proyect/functions` ejecutar:

```bash
npm ci
npm run build
node --test test/*.test.mjs
```

### Qué observar

- `flutter analyze` debe terminar sin issues
- `flutter test` debe terminar en verde
- `npm run build` debe compilar sin errores
- `node --test` debe quedar completamente verde

### Evidencia a guardar

- resumen final de analyze
- conteo final de tests Flutter
- conteo final de tests Functions
- capturas o logs de cualquier warning relevante

---

## 3. Build Android

### Qué hacer

Desde `ocg_proyect` ejecutar:

```bash
flutter build apk --debug
```

### Qué observar

- si falla por Android SDK, documentarlo como limitación de máquina, no como bug del proyecto
- si compila, anotar la ruta del APK generado
- si aparecen errores de Gradle/SDK/JDK, guardar log completo

### Evidencia a guardar

- salida completa del comando
- ruta del APK, por ejemplo `build/app/outputs/flutter-apk/app-debug.apk`
- captura de instalación en dispositivo Android si se realiza

---

## 4. Validación PayU sandbox

### Qué hacer

1. Configurar credenciales sandbox manualmente.
2. Verificar que la app apunte al proyecto Firebase correcto.
3. Probar mínimo estos casos:
   - pago aprobado
   - pago rechazado
   - pago pendiente
   - webhook duplicado
   - paciente con dos tratamientos
4. Revisar Firestore y logs de Functions.

### Qué observar

- el checkout debe abrir con el monto correcto
- el pago debe afectar solo el tratamiento correcto
- no debe tocar otras cuentas del mismo paciente
- webhook duplicado no debe duplicar saldo ni transacción
- deben existir rastros claros en Firestore y logs

### Evidencia a guardar

- referencia PayU usada
- logs del webhook
- capturas del checkout sandbox
- before/after en Firestore del tratamiento pagado
- confirmación de que tratamientos no relacionados no cambiaron

---

## 5. Validación simulador IA

### Qué hacer

1. Configurar `OPENAI_API_KEY` manualmente.
2. Activar `AI_SIMULATOR_ENABLED`.
3. Entrar como admin al detalle del paciente.
4. Tomar o cargar una foto real.
5. Ejecutar una simulación.
6. Probar compartir y visibilidad paciente.
7. Validar también un caso controlado de error.

### Qué observar

- sin key o sin flag: mensaje claro
- con key y flag: transición `draft/generating -> ready`
- el resultado debe quedar en Storage
- Firestore debe guardar `resultPath` y estado final
- paciente solo ve simulaciones compartidas

### Evidencia a guardar

- captura del estado `generating`
- captura del estado `ready`
- ruta en Storage
- documento Firestore con `resultPath`
- evidencia de compartido / visible para paciente

---

## 6. Validación push Android

### Qué hacer

1. Instalar el APK debug en un Android real.
2. Iniciar sesión y aceptar permisos.
3. Confirmar que el token se guarda como `platform = android`.
4. Enviar push de prueba.
5. Probar:
   - foreground
   - background
   - tap navigation
6. Forzar un caso de token inválido si el entorno lo permite.

### Qué observar

- token persistido correctamente en Firestore
- notificación visible en foreground y background
- navegación correcta al tocarla
- token inválido se desactiva y no queda activo indefinidamente

### Evidencia a guardar

- doc `devices/{deviceId}`
- captura de push foreground
- captura de push background
- captura de pantalla destino tras tap
- logs de envío FCM

---

## 7. Validación push iOS

### Qué hacer

1. Configurar manualmente Apple Developer + APNs + Firebase iOS.
2. Instalar la app en iPhone real.
3. Iniciar sesión y aceptar permisos.
4. Confirmar token `platform = ios`.
5. Probar:
   - foreground
   - background
   - terminated
   - tap navigation
6. Validar que Android siga funcionando después del cambio.

### Qué observar

- token iOS persistido correctamente
- payload iOS con `apns`
- navegación correcta al tocar la push
- tokens inválidos iOS se desactivan
- Android no se rompe por el soporte iOS

### Evidencia a guardar

- doc `devices/{deviceId}` iOS
- capturas de recepción foreground/background/terminated
- evidencia del destino de navegación
- logs de envío con payload iOS

---

## 8. Smoke test admin

### Qué hacer

Ingresar como admin y recorrer mínimo:

1. login
2. dashboard
3. pacientes
4. detalle de paciente
5. tratamientos
6. pagos manuales
7. múltiples cuentas de cobro
8. citas
9. simulador
10. notificaciones

### Qué observar

- sin errores visuales graves
- sin pantallas vacías inesperadas
- navegación consistente
- datos correctos por módulo

### Evidencia a guardar

- checklist marcado módulo por módulo
- capturas de pantallas clave
- lista de bugs encontrados, si aparecen

---

## 9. Smoke test paciente

### Qué hacer

Ingresar como paciente y recorrer mínimo:

1. login
2. tratamientos
3. pagos por tratamiento
4. inicio de PayU desde cuenta específica
5. notificaciones
6. simulaciones compartidas
7. citas

### Qué observar

- solo ve información permitida
- pagos filtrados por tratamiento correcto
- no ve simulaciones no compartidas
- navegación estable

### Evidencia a guardar

- capturas del flujo paciente
- referencia del tratamiento usado en PayU
- evidencia de simulación compartida visible
- evidencia de citas visibles

---

## 10. Criterios de cierre

## Aprobado

Se puede marcar **aprobado** solo si:

- `flutter analyze` verde
- `flutter test` verde
- `functions` build/test verde
- build Android validado o limitación de entorno documentada en máquina no final
- PayU sandbox validado end-to-end
- simulador IA validado con foto real y credencial real
- push Android validado
- push iOS validado en iPhone real
- smoke test admin y paciente sin bugs bloqueantes

## Aprobado con observaciones

Aplicable si:

- todo lo crítico funciona,
- hay observaciones menores no bloqueantes,
- existe evidencia clara y plan corto de corrección.

## Rechazado

Aplicable si ocurre cualquiera de estos:

- falla validación técnica base
- build Android falla por problema del proyecto
- PayU toca el tratamiento equivocado
- simulador IA no genera o no persiste resultado correctamente
- push no navega o no llega de forma confiable
- existen bugs bloqueantes en admin o paciente

---

## Secuencia recomendada exacta

1. Preparación local
2. Validación técnica local
3. Build Android
4. PayU sandbox
5. Simulador IA
6. Push Android
7. Push iOS
8. Smoke test admin
9. Smoke test paciente
10. Consolidar evidencia y tomar decisión final
