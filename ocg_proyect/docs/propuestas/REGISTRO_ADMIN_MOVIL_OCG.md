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
