# REGISTRO_ADMIN_MOVIL_OCG

## Corrección navegación móvil admin

- **Problema:** la navegación móvil del admin mostraba un módulo “Más” con accesos globales a Pagos, Tratamientos, Configuración y Cerrar sesión; además había acciones visuales de menú/sidebar en móvil y notificaciones decorativas sin acceso funcional.
- **Decisión UX:** en móvil el admin debe navegar solo por Inicio, Pacientes, Agenda, Simulador y Perfil. Pagos y Tratamientos dejan de existir como módulos globales visibles en móvil y Cerrar sesión pasa al Perfil. Notificaciones quedan con acceso real y visible.
- **Navegación anterior:** Inicio, Pacientes, Agenda, Simulador, Más.
- **Navegación nueva:** Inicio, Pacientes, Agenda, Simulador, Perfil.
- **Qué se eliminó de móvil:** módulo “Más”, acceso global móvil a Pagos, acceso global móvil a Tratamientos, acceso global móvil a Configuración y acciones de menú/sidebar sin uso real en headers móviles.
- **Dónde quedó cerrar sesión:** dentro de la pantalla Perfil del administrador.
- **Dónde quedaron notificaciones:** ruta propia `adminNotifications`, acceso desde el icono de campana en móvil y desde la sección Perfil.
- **Archivos modificados:**
  - `lib/shared/widgets/ocg_adaptive_scaffold.dart`
  - `lib/app/router/route_names.dart`
  - `lib/app/router/app_router.dart`
  - `lib/features/dashboard/presentation/admin_dashboard_screen.dart`
  - `lib/features/dashboard/presentation/admin_patients_screen.dart`
  - `lib/features/dashboard/presentation/admin_modules_screens.dart`
  - `lib/features/dashboard/presentation/admin_profile_screen.dart`
  - `lib/features/dashboard/presentation/admin_notifications_screen.dart`
- **Estado:** aplicado en código y pendiente de validación visual/analyze en entorno con Flutter disponible.

## Validación esperada

En móvil debe verse:

- Inicio
- Pacientes
- Agenda
- Simulador
- Perfil

No debe verse:

- Más
- Pagos como módulo global móvil
- Tratamientos como módulo global móvil
- Configuración como módulo global móvil
- menú de tres puntos del sidebar

## Corrección puntual — Overflow Tratamientos móvil

- **Archivo:** `lib/features/dashboard/presentation/admin_modules_screens.dart`
- **Línea aproximada:** 2131
- **Causa:** un `Row` en la tarjeta móvil de tratamientos usaba texto de sesiones + `Spacer()` + porcentaje dentro de un ancho disponible muy pequeño, provocando overflow horizontal.
- **Solución aplicada:** se reemplazó la estructura por `Expanded` en el texto izquierdo, se eliminó el `Spacer()` y se agregó `TextOverflow.ellipsis` para mantener el layout estable en anchos estrechos.
- **Prueba esperada:** al abrir Tratamientos en móvil ya no aparece `RenderFlex overflowed`, incluso en tarjetas con poco ancho disponible.
- **Estado:** corregido en código y pendiente de validación visual/analyze en entorno con Flutter disponible.

## Corrección puntual — Import y tipado PatientTreatment

### Problema
`patient_detail_screen.dart` usaba `PatientTreatment` sin importar el modelo real y Dart lo interpretaba como tipo indefinido/Object.

### Archivo corregido
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `lib/features/dashboard/presentation/admin_dashboard_screen.dart`

### Import agregado
- `import '../../treatment/data/models/patient_treatment.dart';`

### Tipado corregido
- `treatments` se sigue consumiendo como lista tipada del provider.
- `activeTreatment` quedó como `PatientTreatment?`.
- La selección se hace con un loop seguro sin `dynamic`, sin `Object` y sin dependencias nuevas.

### Warnings limpiados
- Se eliminó `_seedAvailability`.
- Se eliminó `_initializeAllPayments`.

### Resultado esperado
`flutter analyze` sin errores por `PatientTreatment`.

## Corrección puntual — TypeError fold double en card de pagos

### Problema
Al construir `_buildPaymentsCard`, Dart lanzaba `type 'int' is not a subtype of type 'double' of 'initialValue'`.

### Archivo
`lib/features/patients/presentation/patient_detail_screen.dart`

### Causa
Uso de `fold<double>(0, ...)` con valor inicial entero.

### Solución
Cambiar valores iniciales de acumuladores double a `0.0`.

### Alcance
Solo corrección de runtime en card móvil de pagos dentro del detalle del paciente.

### Estado
Pendiente de validación local por Erik.

## Corrección puntual — Tipado fuerte en card móvil de pagos

### Problema
La card de pagos del detalle del paciente seguía fallando porque el cálculo de acumulados usaba inferencia dinámica en una operación que esperaba `(double, EffectivePatientPaymentAccount) => double`.

### Archivo
`lib/features/patients/presentation/patient_detail_screen.dart`

### Causa
Uso de `dynamic` y/o `fold` con closure inferido dinámicamente.

### Solución
Tipar `paymentsResolution` como `EffectivePatientDataResolution` y reemplazar el cálculo por acumuladores explícitos fuertemente tipados.

### Alcance
Solo corrección de runtime en la card de pagos del detalle móvil del paciente.

### Estado
Pendiente de validación local por Erik.
