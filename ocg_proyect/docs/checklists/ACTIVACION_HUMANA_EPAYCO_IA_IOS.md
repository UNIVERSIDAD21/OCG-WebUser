# Activación humana — PayU, Simulador IA e iOS Push

Fecha: 2026-05-04

> Alcance: instructivo operativo para activar credenciales y validar manualmente los bloques que ya quedaron listos a nivel código.
>
> Restricción: este documento **no** contiene secretos reales.

---

## 1) PayU

### Variables / keys necesarias

Configurar en Firebase Functions los valores reales del ambiente correspondiente:

- `PAYU_API_KEY`
- `PAYU_MERCHANT_ID`
- `PAYU_ACCOUNT_ID`
- `PAYU_ENVIRONMENT` (`sandbox` o `production`, según el esquema real del proyecto)
- `PAYU_CHECKOUT_URL` si el ambiente operativo lo requiere distinto al default resuelto por backend

### Dónde configurarlas

Revisar backend en:

- `functions/src/payments/payu_config.ts`
- `functions/src/payments/create_payu_session.ts`
- `functions/src/payments/payu_webhook.ts`

Pasos humanos sugeridos:

1. Abrir Firebase Functions config / params del proyecto correcto.
2. Registrar las variables PayU del ambiente elegido.
3. Confirmar que el backend no esté resolviendo fallback sandbox cuando ya se quiera validar con credenciales reales.
4. Verificar que la app apunte al mismo proyecto Firebase donde vive `payuWebhook`.

### Cómo probar sandbox

1. Confirmar que existe un paciente con al menos un tratamiento real.
2. Confirmar que existe cuenta financiera para ese tratamiento en:
   - `payments/{patientId}/treatments/{treatmentId}`
3. Iniciar sesión como paciente.
4. Ir a la pantalla de pagos del paciente.
5. Seleccionar una cuenta específica de tratamiento.
6. Pulsar el botón de PayU del tratamiento seleccionado.
7. Confirmar que el checkout abre con:
   - referencia nueva,
   - monto correcto,
   - tratamiento correcto.
8. Completar una transacción sandbox aprobada.
9. Repetir al menos un caso rechazado y uno pendiente.

### Cómo validar webhook

1. Confirmar que `payuWebhook` está accesible en el proyecto Firebase correcto.
2. Verificar en logs del backend:
   - recepción del webhook,
   - validación de firma,
   - referencia,
   - `patientId`,
   - `treatmentId`,
   - transición de estado.
3. Validar que la sesión exista en:
   - `payu_sessions/{reference}`
4. Validar que el webhook marque correctamente:
   - `aprobado`,
   - `rechazado`,
   - `pendiente_confirmacion`,
   - o error controlado si la firma/monto/merchant no coincide.
5. Reenviar el mismo webhook y confirmar idempotencia.

### Cómo confirmar que el pago afectó el tratamiento correcto

Validar después de una aprobación:

1. El pago debe impactar **solo**:
   - `payments/{patientId}/treatments/{treatmentId}`
   - `payments/{patientId}/treatments/{treatmentId}/transactions/{txId}`
   - `patients/{patientId}/treatments/{treatmentId}`
2. Confirmar que **no** cambian otras cuentas del mismo paciente.
3. Revisar que la transacción tenga metadata PayU:
   - `metodo = payu`
   - `registradoPor = payu_webhook`
   - `payuOrderId`
   - `payuTransactionId`
4. Si el tratamiento es el principal/legacy espejo, validar también el mirror esperado del paciente sin pisar otros tratamientos.

### Tabla operativa de validación PayU sandbox

| Caso | Qué hacer | Qué observar | Evidencia mínima |
|---|---|---|---|
| Aprobado | Ejecutar pago sandbox exitoso | saldo baja solo en el tratamiento correcto | referencia PayU, captura checkout, before/after Firestore |
| Rechazado | Ejecutar pago sandbox rechazado | no cambia saldo ni crea efecto financiero incorrecto | captura resultado, logs webhook |
| Pendiente | Ejecutar flujo pendiente | estado queda `pendiente_confirmacion` y no aplica pago final | sesión PayU + logs |
| Webhook duplicado | Reenviar mismo webhook | no duplica transacción ni saldo | logs duplicados + una sola tx |
| Paciente con dos tratamientos | Pagar uno de dos tratamientos | el segundo tratamiento no cambia | capturas Firestore de ambos tratamientos |
| Confirmar tratamiento correcto | Revisar `treatmentId` y rutas afectadas | solo cambia `payments/{patientId}/treatments/{treatmentId}` | rutas exactas y snapshot antes/después |
| Confirmar notificación paciente/admin | Validar flujo si el entorno ya tiene push operativo | ambos reciben la señal esperada o queda documentado que no aplica aún | captura o nota de excepción |
| Confirmar transacción en Firestore | Abrir documento tx creada | metadata PayU completa y trazable | ruta de transacción + campos clave |

---

## 2) Simulador IA

### Configurar `OPENAI_API_KEY`

Backend auditado en:

- `functions/src/simulator/generate_smile_simulation.ts`
- `functions/src/simulator/generate_smile_simulation_core.ts`

Pasos humanos:

1. Abrir la configuración/params/secret del entorno Functions.
2. Registrar `OPENAI_API_KEY` con una key válida del proyecto operativo.
3. Confirmar que la función pueda leer la variable en runtime.

### Activar `AI_SIMULATOR_ENABLED`

1. Configurar el flag correspondiente del entorno Functions.
2. Marcarlo en `true` solo cuando ya estén:
   - API key,
   - permisos de Storage,
   - validaciones de Firestore,
   - flujo de foto listo.

### Definir modelo

1. Confirmar el modelo esperado por backend.
2. Validar que la configuración coincida con el flujo documentado actual.
3. No dejar mezclas legacy de proveedor/modelo en el flujo principal.

### Probar foto real

1. Ingresar como admin.
2. Abrir detalle de paciente.
3. Ir al tab / flujo Simulador.
4. Tomar o cargar una foto real de prueba.
5. Ejecutar generación.
6. Confirmar estados:
   - loading,
   - éxito,
   - error controlado,
   - reintento si aplica.

### Verificar Storage y Firestore

1. Revisar que la imagen fuente quede en la ruta esperada de Storage.
2. Revisar que el resultado generado quede persistido en Storage.
3. Revisar que Firestore registre:
   - intento,
   - estado,
   - resultado,
   - visibilidad compartida/no compartida.
4. Validar que el paciente vea solo simulaciones compartidas.
5. Validar que el admin vea historial completo.

### Tabla operativa de validación Simulador IA

| Caso | Qué hacer | Qué observar | Evidencia mínima |
|---|---|---|---|
| Sin API key muestra mensaje claro | desactivar/retirar key en entorno de prueba | mensaje explícito, no error críptico | captura UI + log controlado |
| API key configurada | registrar key válida | función puede leerla y ejecutar flujo | nota/config del entorno + resultado |
| Flag activado | habilitar `AI_SIMULATOR_ENABLED` | el módulo deja de bloquear por configuración | captura de flujo habilitado |
| Foto tomada desde móvil | usar foto real desde dispositivo | archivo original se sube correctamente | captura + ruta Storage origen |
| Simulación pasa a `generating` | lanzar proceso | estado intermedio visible | captura UI / Firestore |
| Simulación pasa a `ready` | esperar resultado exitoso | resultado listo y consultable | captura UI / Firestore |
| Resultado queda en Storage | inspeccionar bucket | existe archivo resultado | ruta exacta Storage |
| Firestore registra `resultPath` | abrir documento simulación | `resultPath` y status correctos | captura doc |
| Admin puede compartir | usar acción de compartir | estado/visibilidad cambia | captura antes/después |
| Paciente ve solo compartidas | entrar como paciente | no ve drafts ni privadas | captura vista paciente |
| Error de IA queda como `failed` | provocar caso controlado de error | documento termina en failed con mensaje seguro | captura doc/log |

---

## 3) iOS push

### Apple Developer

Necesario contar con:

- acceso al Apple Developer account correcto,
- App ID correcto,
- bundle id del proyecto iOS,
- capability de Push Notifications,
- capability/background mode necesaria para remote notifications.

### APNs Auth Key

1. Generar una APNs Auth Key (`.p8`) en Apple Developer.
2. Registrar:
   - Key ID,
   - Team ID,
   - bundle id exacto.
3. Guardar la key de forma segura fuera del repo.

### Firebase iOS app

1. Confirmar que existe la app iOS correcta en Firebase.
2. Subir la APNs Auth Key en Firebase Cloud Messaging.
3. Validar asociación correcta entre:
   - Firebase app iOS,
   - bundle id,
   - APNs key.

### `GoogleService-Info.plist`

1. Descargar el `GoogleService-Info.plist` del proyecto Firebase correcto.
2. Colocarlo en `ios/Runner/`.
3. Confirmar que el archivo corresponda al bundle id real.
4. Verificar que no sea un archivo de otro ambiente o proyecto.

### Prueba en iPhone real

#### Foreground

1. Instalar app en iPhone real.
2. Iniciar sesión.
3. Aceptar permisos de notificaciones.
4. Confirmar que el token FCM se persiste para plataforma `ios`.
5. Enviar notificación de prueba.
6. Verificar banner local/foreground visible.

#### Background

1. Dejar la app en segundo plano.
2. Enviar notificación de prueba.
3. Confirmar recepción del push.
4. Abrir desde la notificación y validar navegación.

#### Terminated

1. Cerrar completamente la app.
2. Enviar notificación de prueba.
3. Abrir tocando la notificación.
4. Validar deep link / routing correcto.

#### Tap navigation

Validar al menos estos destinos según payload:

- citas,
- pagos,
- detalle paciente/admin,
- simulador,
- historial de notificaciones.

### Verificaciones adicionales

1. Confirmar que el token iOS se guarde en `devices/{deviceId}` con `platform = ios`.
2. Confirmar que no quede forzado `platform = android` en cliente.
3. Confirmar que payload iOS incluya bloque `apns`.
4. Confirmar invalidación de tokens iOS inválidos.

### Tabla operativa de validación iOS push

| Caso | Qué hacer | Qué observar | Evidencia mínima |
|---|---|---|---|
| token se guarda con `platform ios` | iniciar sesión y aceptar permisos | doc `devices/{deviceId}` correcto | captura Firestore |
| foreground recibe notificación | enviar push con app abierta | banner/alerta visible | foto/captura del iPhone |
| background recibe notificación | app en segundo plano | push visible y abrible | captura de notificación |
| terminated recibe notificación | cerrar app y enviar push | llega y abre app | video/captura |
| tap navigation funciona | tocar push con payload conocido | abre destino correcto | captura de pantalla destino |
| token inválido se desactiva | invalidar token/caso controlado | backend desactiva token | logs + Firestore |
| payload contiene `apns` | revisar envío/log estructurado | bloque `apns` presente | log del payload |
| Android sigue funcionando después del cambio | enviar push Android luego de iOS | Android sigue recibiendo | captura/log Android |

---

## Cierre humano recomendado

Antes de activar credenciales reales, ejecutar esta secuencia:

1. PayU sandbox validado end-to-end.
2. Simulador IA validado con foto real.
3. iOS push validado en iPhone real.
4. Revisión final de logs de Functions.
5. Revisión visual rápida de pagos, simulador y notificaciones.
6. Solo después considerar despliegue/activación operativa.
