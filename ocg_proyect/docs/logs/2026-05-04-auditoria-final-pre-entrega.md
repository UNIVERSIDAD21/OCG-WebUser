# Auditoría final pre-entrega — candidato a activación / validación humana

Fecha: 2026-05-04
Repositorio auditado: `/home/borlty/OCG-WebUser`
Rama auditada: `main`
Upstream auditado: `origin/main`

---

## 1. Resumen ejecutivo

Estado general del proyecto: **candidato a activación / validación humana, pero no candidato a producción inmediata**.

Conclusión corta:

- Los bloques críticos recientes quedaron **cerrados a nivel código** y sus commits están presentes en `main`.
- `flutter analyze` quedó **verde**.
- El backend de `functions` quedó **compilando** y su suite Node/TS auditada quedó **verde**.
- La suite global `flutter test` **no está verde**: fallaron **12 tests**.
- `flutter build apk --debug` **no pudo ejecutarse** por limitación del entorno OpenClaw: **no hay Android SDK instalado**.
- No se configuraron credenciales PayU, OpenAI ni APNs/Firebase iOS.
- No se desplegó nada.

Recomendación final:

**Corregir antes** de declarar estado de “pre-entrega validada”.

Más preciso:

- **Sí** puede avanzar a fase de **validación humana con credenciales** si Jefe acepta que aún hay deuda en la suite global Flutter.
- **No** debe declararse “lista para activación” con sello técnico completo mientras `flutter test` siga fallando y sin build Android local verificable.

---

## 2. Verificación real del repo

### Estado detectado

Comandos ejecutados:

```bash
cd /home/borlty/OCG-WebUser
git branch --show-current
git rev-parse --abbrev-ref --symbolic-full-name @{u}
git status --short
git log --oneline --decorate -12
```

Resultado:

- Rama actual: `main`
- Upstream: `origin/main`
- HEAD y remoto: `0580f68 (HEAD -> main, origin/main, origin/HEAD)`

### Working tree antes de empezar

**No estaba limpio**.

Se detectó:

```bash
?? OCG-WebUser/
```

Observación:

- El repo principal sí está en `main` y alineado con `origin/main`.
- Pero existe un directorio anidado no trackeado `OCG-WebUser/` dentro del root del repo.
- Eso impide declarar “working tree limpio” al inicio de la auditoría.

### Commits verificados

Se verificó presencia explícita de estos commits:

- `6a752d5` — **Corrige PayU para pagos por tratamiento y cuentas múltiples**
- `e0dcdd9` — **Blindaje backend de PayU con idempotencia y pruebas de webhook**
- `5a0374e` — **Certifica PayU Flutter por tratamiento con pruebas anti regresión**
- `347bac0` — **Corrige recálculo financiero del tratamiento principal**
- `8079c5f` — **Certifica simulador IA listo para API KEY**
- `0580f68` — **Prepara notificaciones iOS para credenciales**

Resultado: **verificados, no asumidos**.

---

## 3. Validaciones ejecutadas

### Flutter / app (`ocg_proyect`)

Comandos ejecutados:

```bash
export PATH="/home/borlty/flutter/bin:$PATH"
cd /home/borlty/OCG-WebUser/ocg_proyect
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

#### `flutter pub get`

Resultado: **OK**

Notas:

- dependencias resueltas,
- 22 paquetes con versiones más nuevas incompatibles con constraints actuales.

#### `flutter analyze`

Resultado: **OK**

Salida relevante:

```text
No issues found!
```

#### `flutter test`

Resultado: **FAIL**

Resumen:

- 154 tests ejecutados antes de cortar la suite completa
- 12 fallos reportados
- muchos tests recientes de pagos, PayU, simulador, repositorios y notificaciones sí quedaron verdes

Fallos observados:

1. `test/widget_test.dart`
   - espera texto `Iniciar sesión`
   - la UI actual usa `INICIAR SESIÓN`
   - clasificación: **test viejo / desalineado con copy actual**

2. `test/login_forgot_validation_test.dart`
   - intenta tocar `Iniciar sesión`
   - la UI actual usa `INICIAR SESIÓN`
   - clasificación: **test viejo / desalineado con copy actual**

3. `test/treatment/manage_patient_treatment_dialog_test.dart`
   - espera `Subtipo obligatorio`
   - el mensaje actual en código es `Debes seleccionar el subtipo para este tratamiento.`
   - clasificación: **test viejo / desalineado con mensajes actuales**

4. `test/features/patients/patient_treatment_tab_multitreatment_test.dart`
   - espera `1 tratamiento`
   - el tab actual cambió estructura/copy
   - clasificación: **test viejo / UI assertions desactualizadas**

5. `test/features/patients/patient_payments_tab_effective_test.dart`
   - espera labels antiguos como `Cuenta t1` e `Historial global de pagos`
   - además dispara `[core/no-app] No Firebase App '[DEFAULT]' has been created`
   - el tab actual hace microtasks de `ensureTreatmentPaymentAccountProvider` / `ensureTreatmentFinancialItemsProvider`
   - clasificación: **mezcla de test viejo + setup incompleto de test**

6. `test/features/patients/patient_detail_workspace_test.dart`
   - espera string vieja `Workspace clínico, financiero y operativo del paciente`
   - ese copy fue removido previamente
   - clasificación: **test viejo**

7. `test/features/admin/admin_desktop_modules_alignment_test.dart`
   - espera un `Saldo pendiente` en una posición/layout ya cambiada
   - clasificación: **test de UI/layout desalineado**

Conclusión sobre la suite Flutter:

- **No aparece una regresión directa confirmada** en PayU, simulador IA o iOS push por esta corrida.
- Los fallos encontrados son **consistentes con tests globales envejecidos/desalineados** frente a cambios de UI/copy/layout y setup de widgets.
- Aun así, técnicamente la suite global **no está certificada**.

#### `flutter build apk --debug`

Resultado: **NO EJECUTABLE EN ESTE ENTORNO**

Error real:

```text
[!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
```

Clasificación:

- limitación del entorno OpenClaw / host actual,
- **no** se marca como éxito.

---

### Functions (`ocg_proyect/functions`)

Comandos ejecutados:

```bash
cd /home/borlty/OCG-WebUser/ocg_proyect/functions
npm ci
npm run build
node --test test/*.test.mjs
```

#### `npm ci`

Resultado: **OK**

Notas:

- warning de engine: paquetes esperan Node 20 y el host actual está en Node 22.22.2
- se instalaron dependencias
- `npm audit` reportó 15 vulnerabilidades de dependencias

Clasificación:

- no bloquea build local de Functions en esta auditoría,
- pero debe revisarse antes de activación fuerte.

#### `npm run build`

Resultado: **OK**

#### `node --test test/*.test.mjs`

Resultado: **OK**

Resumen:

- 31 tests
- 31 pass
- 0 fail

Incluye evidencia fuerte sobre:

- FCM Android/iOS payload delivery
- invalidación de tokens
- webhook PayU
- idempotencia PayU
- amount mismatch / currency mismatch / merchant mismatch
- sesión PayU sin `treatmentId`

---

## 4. Correcciones hechas durante esta auditoría

### Cambios de código funcional

- **No se hicieron cambios funcionales de app o backend.**
- No se tocó PayU, IA ni iOS push a nivel funcional.
- No se arreglaron tests “a ciegas”.

### Cambios documentales

Se creó:

- `docs/checklists/ACTIVACION_HUMANA_PAYU_IA_IOS.md`

Se creó este reporte:

- `docs/logs/2026-05-04-auditoria-final-pre-entrega.md`

---

## 5. Auditoría funcional por módulos

| Módulo | Estado | Evidencia | Riesgo | Próxima acción concreta |
|---|---|---|---|---|
| Auth y roles | requiere prueba humana | `lib/features/auth/*`, `functions/src/auth/set_fcm_token.ts`, tests login globales fallando por copy viejo | medio | validar login admin/paciente manual con Firebase real y actualizar tests UI viejos |
| Admin dashboard | listo código | `test/features/admin/admin_desktop_validation_matrix_test.dart` verde | medio | smoke manual desktop/móvil admin |
| Pacientes | listo código | `lib/features/patients/*`, tests de repos y vistas parciales verdes | medio | validar navegación y listados reales con datos Firebase |
| Detalle de paciente | requiere prueba humana | `lib/features/patients/presentation/patient_detail_screen.dart`, commit de fixes previos, test workspace viejo fallando | medio | revisar tabs reales y ajustar tests UI desalineados |
| Tratamientos multi-cuenta | listo código | commits `6a752d5`, `347bac0`, tests `treatment_financial_repository_test.dart`, `payments_repository_test.dart` | bajo | prueba manual con paciente de 2-3 tratamientos |
| Pagos manuales | listo código | `payments_repository_test.dart`, `register_payment_dialog_test.dart` verde | medio | prueba humana de registro manual desde admin |
| PayU | listo con credenciales | commits `6a752d5`, `e0dcdd9`, `5a0374e`; tests Node PayU 31/31 backend; widget test PayU paciente verde | medio | configurar credenciales sandbox y validar end-to-end webhook real |
| Simulador IA | listo con credenciales | commit `8079c5f`, `functions/test/generate_smile_simulation_core*`, `test/features/simulator/simulator_provider_test.dart` | medio | configurar `OPENAI_API_KEY`, activar flag y probar con foto real |
| Notificaciones Android | requiere prueba humana | `fcm_service.dart`, `fcm_delivery.ts`, tests Flutter + Node verdes | medio | probar token real, foreground/background y navegación |
| Notificaciones iOS | listo con credenciales | commit `0580f68`, `fcm_service_test.dart`, `fcm_delivery.test.mjs`, doc iOS ready-for-credentials | medio | subir APNs/Firebase iOS y probar en iPhone real |
| Citas/agenda | requiere prueba humana | `appointment_patient_notifications.ts`, `reminder_scheduler.ts`, tests de reglas de citas verdes | medio | validar agenda real + recordatorios con datos reales |
| Seguridad Firestore | listo código | `test/treatment/firestore_rules_block01_test.dart` verde; endurecimientos previos documentados | medio | correr validación humana de permisos con usuarios reales |
| Storage | requiere prueba humana | flujo simulador/archivos clínicos soportado por código y tests de repositorio | medio | validar subida/lectura/borrado lógico con bucket real |
| Navegación/routing | listo código | `fcm_payload_router_test.dart` verde, router auditado | bajo | smoke manual de deep links clave |
| UI móvil admin | requiere prueba humana | existen tests responsive parciales verdes; otros de alineación desktop fallan por drift | medio | prueba manual visual en anchos móviles reales |
| UI paciente móvil | requiere corrección | varios tests de tabs/pagos/tratamientos están desalineados | medio | actualizar suite widget al estado real de la UI antes de cierre técnico |

---

## 6. Auditoría de flujos críticos sin credenciales

### Flujo paciente

#### 1) Login paciente

- Código existe y flujo está implementado.
- Evidencia:
  - `lib/features/auth/presentation/login_screen.dart`
  - `lib/services/firebase/auth_service.dart`
- Observación:
  - tests viejos esperan copy distinta (`Iniciar sesión` vs `INICIAR SESIÓN`).
- Estado: **requiere prueba humana**

#### 2) Ver tratamientos

- Hay resolución efectiva de tratamientos y UI de tratamiento/paciente.
- Evidencia:
  - `effectivePatientTreatmentsProvider`
  - `patient_treatment_tab.dart`
- Estado: **listo código**

#### 3) Ver pagos por tratamiento

- El flujo por tratamiento está implementado y hay evidencia fuerte en repositorio/tests de negocio.
- Evidencia:
  - `patient_payments_tab.dart`
  - `payments_repository_test.dart`
- Riesgo:
  - tests widget viejos no reflejan la UI actual.
- Estado: **listo código**

#### 4) Iniciar PayU desde cuenta específica

- Flujo activo exige `treatmentId` válido.
- Evidencia:
  - `lib/features/payments/services/payu_service.dart`
  - `functions/src/payments/create_payu_session.ts`
  - `test/features/payments/patient_payments_screen_payu_test.dart`
  - `functions/test/payu_webhook_core.test.mjs`
- Estado: **listo con credenciales**

#### 5) Ver notificaciones

- Historial y routing existen.
- Evidencia:
  - `notifications_provider.dart`
  - `patient_notifications_screen.dart`
  - `fcm_payload_router_test.dart`
- Estado: **requiere prueba humana**

#### 6) Ver simulaciones compartidas

- El código soporta visibilidad paciente/admin separada.
- Evidencia:
  - doc de simulador ready-for-api-key
  - providers/tests simulador
- Estado: **listo con credenciales**

#### 7) Ver citas

- Código y reglas existen.
- Evidencia:
  - `appointments_business_rules_test.dart`
  - módulos de citas y recordatorios
- Estado: **requiere prueba humana**

### Flujo admin

#### 1) Login admin

- Implementado por el mismo bloque auth/roles.
- Estado: **requiere prueba humana**

#### 2) Ver pacientes

- Pantallas/admin screens presentes.
- Tests responsive/admin matrix parcialmente verdes.
- Estado: **listo código**

#### 3) Entrar al detalle

- Navegación y detalle presentes.
- Hay fixes previos relevantes en memoria/contexto.
- Estado: **requiere prueba humana**

#### 4) Crear / editar tratamiento

- Diálogo y repositorios existen.
- Los tests actuales fallan por copy de error desactualizado, no por ausencia del flujo.
- Estado: **listo código**

#### 5) Registrar pago manual

- Repositorio y validaciones verdes.
- Evidencia:
  - `register_payment_dialog_test.dart`
  - `payments_repository_test.dart`
- Estado: **listo código**

#### 6) Ver múltiples cuentas de cobro

- Flujo implementado por tratamiento.
- Evidencia:
  - `patient_payments_tab.dart`
  - tests de negocio en repositorios
- Estado: **listo código**

#### 7) Tomar foto para simulador

- Flujo preparado pero depende de validación humana final y credenciales del simulador si se quiere generación real.
- Estado: **listo con credenciales**

#### 8) Abrir tab Simulador

- Flujo y navegación documentados/implementados.
- Estado: **listo código**

#### 9) Compartir simulación

- El modelo funcional existe según auditoría previa/documentación del bloque.
- Estado: **listo con credenciales**

#### 10) Ver notificaciones

- Flujo implementado, requiere validación manual real con FCM.
- Estado: **requiere prueba humana**

#### 11) Gestionar citas

- Reglas y notificaciones backend implementadas.
- Estado: **requiere prueba humana**

---

## 7. Revisión de caminos legacy peligrosos

### 7.1 PayU sin `treatmentId`

Resultado: **no se detectó flujo funcional activo peligroso**.

Evidencia:

- `lib/features/payments/services/payu_service.dart`
  - exige `treatmentId`
  - error claro: `No se puede iniciar PayU sin un treatmentId válido.`
- `functions/src/payments/create_payu_session.ts`
  - rechaza si faltan `patientId`, `treatmentId` o `monto`
- `functions/src/payments/payu_webhook_core.ts`
  - invalida sesión sin `treatmentId`
- tests Node cubren explícitamente `sesión sin treatmentId no aplica pago`

### 7.2 Tabs viejos de “Fotos” como flujo principal

Resultado: **no se encontró evidencia de que siga siendo el flujo principal**.

Observación:

- sí existe `storage_paths.dart` con ruta `patients/$id/photos/$name`, lo cual no es un problema por sí solo.
- no apareció evidencia de un tab principal legacy de “Fotos” dominando el flujo actual del simulador.

### 7.3 Pagos globales que pisan cuentas por tratamiento

Resultado: **no se encontró evidencia de flujo actual activo que pise cuentas por tratamiento en PayU**.

Evidencia:

- backend PayU amarra `patientId + treatmentId`
- tests de `payments_repository_test.dart` y webhook Node verifican aislamiento entre tratamiento A y B

Nota:

- el sistema mantiene compatibilidad legacy en algunos mirrors para tratamiento principal, lo cual es deliberado y no se observó como bug directo en esta auditoría.

### 7.4 Hardcode `platform: android`

Resultado: **corregido en flujo funcional actual**.

Evidencia:

- `fcm_service.dart` usa `resolveFcmPlatform()`
- `fcm_delivery.ts` resuelve Android/iOS/macOS/web

Lo encontrado con `'android'` hoy está en:

- tests mockeados,
- wrapper de compatibilidad backend (`resolveActiveAndroidTokens`).

### 7.5 Errores crípticos cuando faltan credenciales

Resultado: **mejorado en bloques auditados**.

Evidencia:

- Simulador IA tiene mensajes claros por falta de API key / flag desactivado.
- PayU falla con mensajes explícitos si falta `treatmentId` o datos válidos.

Pendiente:

- validar manualmente UX real ante credenciales faltantes en Firebase/proyecto operativo.

### 7.6 Credenciales reales hardcodeadas

Resultado: **no se detectaron secretos privados evidentes en código de negocio auditado**.

Observación importante:

- sí existe `android/app/google-services.json`
- también aparece `web/firebase-messaging-sw.js` con config Firebase web

Clasificación:

- esto suele ser **config pública de Firebase cliente**, no necesariamente secreto privado.
- **no** se detectó `OPENAI_API_KEY` real ni secrets PayU reales hardcodeados en el código funcional auditado.

### 7.7 API keys hardcodeadas

Resultado:

- no se detectó `OPENAI_API_KEY` real en código de negocio.
- no se detectaron credenciales privadas PayU reales hardcodeadas en `src/` funcional.
- sí hay claves públicas/config cliente Firebase en archivos de app web/android.

### 7.8 Rutas muertas o duplicadas

Hallazgo menor:

- existe stub legacy documentado en:
  - `lib/services/api/payu_service.dart`
- ese archivo contiene advertencia explícita:
  - *“No usar este stub legacy. El flujo activo de PayU vive en features/payments/services/payu_service.dart y siempre exige treatmentId.”*

Clasificación:

- **no es un bug crítico**, pero sí un punto de confusión potencial para futuros cambios.

### 7.9 Imports / stubs legacy que puedan confundir

Hallazgo menor:

- el stub legacy de PayU anterior sigue presente con advertencia explícita.
- hay tests/UI viejos con copy obsoleta.

Recomendación:

- limpieza posterior controlada de tests y stubs legacy para bajar ruido técnico.

---

## 8. Riesgos restantes

### Riesgo alto

- Ninguno confirmado como bloqueo funcional directo del código reciente auditado.

### Riesgo medio

1. Suite Flutter global no verde.
2. Build Android no verificable en este host por falta de Android SDK.
3. Falta validación humana real con Firebase/Storage/FCM/cámaras/credenciales.
4. Tests UI viejos pueden ocultar o mezclar deuda real con ruido histórico.
5. `npm ci` reporta vulnerabilidades de dependencias.

### Riesgo bajo

1. Stub legacy de PayU con advertencia explícita.
2. Directorio anidado no trackeado `OCG-WebUser/` en root del repo.

---

## 9. Pendientes humanos

### PayU

- cargar credenciales sandbox/reales del ambiente correcto,
- validar checkout real,
- validar webhook real,
- validar impacto exclusivo al tratamiento correcto.

### Simulador IA

- configurar `OPENAI_API_KEY`,
- activar flag,
- definir modelo operativo,
- probar con foto real,
- revisar Storage/Firestore.

### iOS push

- Apple Developer,
- APNs Auth Key,
- Firebase iOS app,
- `GoogleService-Info.plist`,
- iPhone real foreground/background/terminated/tap navigation.

### Técnica general

- instalar Android SDK en el host de validación,
- correr `flutter build apk --debug`,
- depurar/actualizar tests widget viejos para reflejar UI real actual,
- decidir si el directorio untracked anidado debe eliminarse o ignorarse.

---

## 10. Recomendación final

### Veredicto

**Corregir antes** de cerrar la pre-entrega técnica como validada al 100%.

### Matiz operativo

Si el objetivo inmediato es pasar a una fase de validación humana con credenciales controladas, el proyecto sí está en un estado razonable de:

- **candidato a activación asistida**,
- **no candidato a producción declarada**,
- **no candidato a cierre QA técnico completo**.

### Orden recomendado

1. Resolver/actualizar la suite Flutter global desalineada.
2. Repetir `flutter test` hasta verde o dejar documentados los tests oficialmente obsoletos.
3. Verificar build Android en máquina con Android SDK.
4. Ejecutar activación humana con el checklist:
   - `docs/checklists/ACTIVACION_HUMANA_PAYU_IA_IOS.md`
5. Solo después evaluar despliegue/activación operativa.
