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

## Corrección puntual — Import PaymentTransaction

### Problema
`patient_detail_screen.dart` usaba `PaymentTransaction` sin importar el modelo real.

### Archivo corregido
`lib/features/patients/presentation/patient_detail_screen.dart`

### Solución
Se agregó el import de `payment_model.dart`.

### Resultado esperado
`flutter analyze` sin errores.

## Corrección UX móvil — Detalle claro y multi-tratamiento

### Problema
La vista móvil del detalle del paciente funcionaba, pero estaba mostrando demasiadas secciones mezcladas y no hacía visible de forma intuitiva el caso de pacientes con múltiples tratamientos.

### Alcance
Solo móvil. Desktop intacto.

### Decisión UX
Móvil usa encabezado + acciones rápidas + selector de secciones + una sección visible a la vez.

### Cambios realizados
- Se eliminó la composición móvil donde se renderizaban varias cards resumen y además un `IndexedStack` con secciones profundas.
- Se dejó un encabezado clínico resumido con nombre, contacto, estado, saldo pendiente y próxima cita.
- Se reorganizaron las acciones rápidas en una cuadrícula 2x2 compacta.
- Se reemplazó la navegación visual duplicada por un selector horizontal de secciones.
- Solo se renderiza el contenido de la sección seleccionada en móvil.

### Cómo se muestra multi-tratamiento
- La sección **Tratamientos** ahora lista todos los tratamientos reales del paciente.
- Cada tratamiento se muestra en una card independiente con nombre visible, badges de principal/secundario, estado, etapa actual, fecha de inicio, valor total, saldo pendiente y nota corta si existe.
- Si el tratamiento proviene de datos legacy, se comunica como tratamiento migrado/principal sin romper la vista.

### Casos cubiertos
- paciente sin tratamientos: mensaje claro de que no hay tratamientos registrados.
- paciente con un tratamiento: se muestra una única card completa.
- paciente con varios tratamientos: se muestra contador resumido y una card por tratamiento.
- paciente legacy: se conserva el caso migrado con card válida.
- paciente con tratamientos finalizados: se muestran igual, usando su estado real.

### Qué se mantuvo intacto en desktop
- Flujo desktop, `AdminWebShell`, `TabBar`, `TabBarView` y layout de escritorio sin cambios.

### Resultado flutter analyze
- Pendiente de validación local por Erik, porque en esta sesión no hay `flutter` disponible en PATH.

## Corrección UX móvil — Pagos multi-tratamiento

### Problema
Al tocar “Ir a pagos” desde el detalle móvil del paciente, la vista podía quedar trabada y no mostraba de forma clara las cuentas/pagos por múltiples tratamientos.

### Alcance
Solo móvil. Desktop intacto.

### Causa encontrada
La sección móvil de pagos estaba intentando renderizar una pantalla embebida más pesada de lo necesario para el detalle del paciente, en lugar de usar una vista móvil directa con la resolución de pagos ya disponible.

### Solución aplicada para “Ir a pagos”
La sección **Pagos** del detalle móvil ahora cambia inmediatamente a una vista local liviana basada en `EffectivePatientDataResolution`, sin abrir una pantalla embebida pesada ni duplicar shells.

### Cómo se muestran ahora las cuentas por tratamiento
Se agregó una sección **Cuentas por tratamiento** con una card por cuenta, mostrando nombre del tratamiento, badge principal/secundario/legacy, estado, total, pagado, saldo pendiente, próximo pago y botón de registrar pago.

### Cómo se muestra historial de pagos
El historial reciente ahora muestra fecha, valor, método, estado y tratamiento asociado cuando puede resolverse; si no, se indica que es legacy o no identificado.

### Casos cubiertos
- paciente sin pagos: mensaje claro de ausencia de pagos.
- paciente con un tratamiento: una cuenta clara con su resumen.
- paciente con varios tratamientos: varias cards separadas por tratamiento.
- paciente legacy: cuenta legacy / migrada visible sin romper.
- paciente con cuentas sin transacciones: mensaje de que ese tratamiento aún no tiene pagos registrados.

### Archivos modificados
- `lib/features/patients/presentation/patient_detail_screen.dart`
- `docs/propuestas/REGISTRO_ADMIN_MOVIL_OCG.md`

### Qué se mantuvo intacto en desktop
- Flujo desktop y vistas de escritorio sin cambios.

### Resultado flutter analyze
- Pendiente de validación local por Erik, porque en esta sesión no hay `flutter` disponible en PATH.

## Corrección UX móvil — Flujo de foto y simulador en detalle de paciente

### Problema
En detalle de paciente móvil, el botón **Tomar foto** enviaba a una sección separada de Fotos y los índices de secciones dejaban el flujo del simulador mezclado o incorrecto.

### Alcance
Solo móvil. Desktop intacto.

### Cambios realizados
- Se eliminó el chip/tab **Fotos** del detalle móvil del paciente.
- Se corrigieron los índices móviles para dejar solo: Resumen, Tratamientos, Pagos, Citas y Simulador.
- Se corrigió el mapeo de `section=simulador` para abrir la sección correcta.
- El botón **Abrir simulador** mantiene apertura directa del tab Simulador.
- El botón **Tomar foto** ahora reutiliza el flujo real de cámara del simulador para ese paciente.
- La sección móvil del simulador ahora usa directamente `PatientSimulatorTab`, que ya muestra simulaciones existentes y acciones de captura/subida.

### Casos cubiertos
- cancelar cámara: no rompe la pantalla.
- abrir simulador desde acciones rápidas: abre el tab correcto.
- tomar foto desde acciones rápidas: abre cámara en móvil y continúa el flujo del simulador.
- simulaciones existentes: visibles dentro del tab Simulador.
- nueva captura desde Simulador: disponible desde las acciones del tab.

### Qué se mantuvo intacto en desktop
- Layout desktop, tabs desktop y flujo de simulador en escritorio sin cambios.

### Resultado flutter analyze
- Pendiente de validación local por Erik, porque en esta sesión no hay `flutter` disponible en PATH.
