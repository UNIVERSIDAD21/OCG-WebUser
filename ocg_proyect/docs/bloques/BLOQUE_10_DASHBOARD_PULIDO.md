# BLOQUE_10 — Dashboard Admin + Pulido UI + Cierre de Producto

> **Stack:** Flutter + Riverpod + Firestore
> **Prioridad:** MEDIA — Calidad final y experiencia administrativa
> **Depende de:** Todos los bloques anteriores (06-09) cerrados

---

## Objetivo del bloque

Llenar el `AdminDashboardScreen` con métricas reales. Implementar la galería fotográfica del paciente (fotos clínicas antes/durante/después). Pulir la experiencia de usuario en ambos roles. Documentar el proceso de deploy.

---

## Lo que debes entregar al cerrar este bloque

- [ ] `AdminDashboardScreen` con métricas reales (pacientes, citas, pagos pendientes)
- [ ] Galería fotográfica de pacientes con `BeforeAfterSlider`
- [ ] Navegación bottom bar para el paciente (Home, Citas, Pagos, Simulador, Notificaciones)
- [ ] `OcgEmptyState` validado en todas las pantallas que lo requieren
- [ ] Responsive: AppBar lateral en pantallas anchas (tablet/web)
- [ ] Pantalla de splash/carga mientras Firebase inicializa
- [ ] Guía de deploy (README con instrucciones)
- [ ] `flutter analyze` ✅ y `flutter test` ✅ con cobertura completa

---

## AdminDashboardScreen — Métricas reales

El dashboard actual es un placeholder. Reemplazar con métricas útiles para la doctora.

### Providers de métricas

```dart
// lib/features/dashboard/providers/dashboard_provider.dart

// Total de pacientes activos (etapa != alta)
final activePatientsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(patientsRepositoryProvider).watchActivePatientsCount();
});

// Citas del día de hoy
final todayAppointmentsCountProvider = StreamProvider<int>((ref) {
  final today = DateTime.now();
  return ref.watch(appointmentsRepositoryProvider).watchCountByDate(today);
});

// Pacientes con saldo vencido
final overduePaymentsCountProvider = StreamProvider<int>((ref) {
  return ref.watch(paymentsRepositoryProvider).watchOverdueCount();
});

// Resumen de ingresos del mes actual
final monthlyRevenueProvider = StreamProvider<double>((ref) {
  return ref.watch(paymentsRepositoryProvider).watchMonthlyRevenue();
});
```

### Layout del Dashboard

```
┌─────────────────────────────────────┐
│  Bienvenida, Dra. [nombre]          │
│  [fecha y hora actual]              │
├─────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐        │
│  │Pacientes │  │Citas hoy │        │
│  │  activos │  │          │        │
│  │    24    │  │    5     │        │
│  └──────────┘  └──────────┘        │
│  ┌──────────┐  ┌──────────┐        │
│  │Pagos     │  │Ingresos  │        │
│  │vencidos  │  │del mes   │        │
│  │    3     │  │$2.400.000│        │
│  └──────────┘  └──────────┘        │
├─────────────────────────────────────┤
│  Accesos rápidos:                   │
│  [Pacientes] [Agenda] [Pagos]       │
├─────────────────────────────────────┤
│  Próximas citas hoy:                │
│  Lista de las citas del día         │
└─────────────────────────────────────┘
```

Cada tarjeta de métrica usa `OcgCard` con ícono + número grande + label.

---

## Galería fotográfica del paciente

### Modelo: `lib/features/photos/data/models/patient_photo.dart`

```dart
class PatientPhoto {
  final String id;
  final String patientId;
  final String url;              // URL temporal de Storage (signed)
  final PhotoType tipo;
  final DateTime fechaTomada;
  final String? notas;
}

enum PhotoType {
  antesInicio,      // Foto inicial del tratamiento
  progreso,         // Durante el tratamiento
  resultado,        // Al finalizar
  perfil,           // Foto de perfil del paciente
}
```

### Subcolección: `patients/{patientId}/photos`

Ya está definida en `FirestorePaths.patientPhotos(patientId)`.

### Pantalla: `lib/features/photos/presentation/patient_gallery_screen.dart`

```
Grid de fotos (2 columnas)
  - Cada foto tiene su tipo como badge
  - Tap en foto → PhotoDetailScreen con BeforeAfterSlider si hay 2 fotos comparables

FAB: "Agregar foto" (solo admin)
  → ImagePickerService
  → Subir a Storage en StoragePaths.patientPhoto(id, name)
  → Guardar en Firestore
```

### `BeforeAfterSlider` — Reutilizar desde Bloque 08

En la galería: mostrar el primer `antesInicio` vs el último `resultado` con el slider.

---

## Navegación bottom bar para el paciente

Reemplazar la navegación actual del paciente con un `BottomNavigationBar` o `NavigationBar` (Material 3):

```dart
// lib/features/dashboard/presentation/patient_shell.dart
// Shell con NavigationBar persistente

class PatientShell extends ConsumerWidget {
  final Widget child; // Router shell — go_router ShellRoute
  
  // Tabs:
  // 0 → /patient/home        (Inicio)
  // 1 → /patient/appointments (Citas)
  // 2 → /patient/payments    (Pagos)
  // 3 → /patient/simulator   (Simulador)
  // 4 → /patient/notifications (Notificaciones + badge)
}
```

Migrar las rutas del paciente a `ShellRoute` en `app_router.dart`:

```dart
ShellRoute(
  builder: (context, state, child) => PatientShell(child: child),
  routes: [
    GoRoute(path: RouteNames.patientHome, ...),
    GoRoute(path: RouteNames.patientAppointments, ...),
    GoRoute(path: RouteNames.patientPayments, ...),
    GoRoute(path: RouteNames.patientSimulator, ...),
    GoRoute(path: RouteNames.patientNotifications, ...),
  ],
),
```

---

## Responsive Web (Admin)

En pantallas anchas (> 800px), el admin debe tener un `NavigationRail` o `Drawer` lateral en lugar de AppBar con botones de texto.

```dart
// lib/shared/widgets/ocg_adaptive_scaffold.dart
class OcgAdaptiveScaffold extends StatelessWidget {
  // Si MediaQuery.of(context).size.width > 800:
  //   → Row con NavigationRail (izquierda) + Expanded(child)
  // Si < 800:
  //   → Scaffold normal con AppBar
  
  final Widget body;
  final int selectedIndex;
  final void Function(int) onDestinationSelected;
  final List<NavigationRailDestination> destinations;
}
```

Usar `OcgAdaptiveScaffold` en las pantallas admin principales.

---

## Splash screen / Loading state

En `app_router.dart`, el redirect ya maneja el estado de carga devolviendo `null`. Sin embargo, el usuario ve una pantalla en blanco mientras Firebase inicializa.

Mejorar: en `OcgApp`, envolver con un `Consumer` que muestre `OcgLoadingScreen` (ya implementado) mientras `authState.isLoading`:

```dart
// app.dart — ajuste
@override
Widget build(BuildContext context, WidgetRef ref) {
  final router = ref.watch(appRouterProvider);
  final authState = ref.watch(authStateProvider);
  
  if (authState.isLoading) {
    return const MaterialApp(home: OcgLoadingScreen());
  }
  
  return MaterialApp.router(
    title: 'OCG Clínica',
    theme: OcgTheme.light,
    debugShowCheckedModeBanner: false,
    routerConfig: router,
  );
}
```

---

## Métodos adicionales en repositorios

### `PatientsRepository` — agregar:
```dart
Stream<int> watchActivePatientsCount();
// where('etapaActual', isNotEqualTo: 'alta').snapshots().map(s => s.docs.length)
```

### `AppointmentsRepository` — agregar:
```dart
Stream<int> watchCountByDate(DateTime date);
```

### `PaymentsRepository` — agregar:
```dart
Stream<int> watchOverdueCount();
// where('estado', isEqualTo: 'vencido').snapshots().map(s => s.docs.length)

Stream<double> watchMonthlyRevenue();
// Requiere índice compuesto: fecha + tipo en transactions
// Alternativa simple: mantener un campo 'ingresosMes' en un documento de config
```

---

## Pulido de UX — Checklist

- [ ] Todos los formularios tienen `autovalidateMode: AutovalidateMode.onUserInteraction`
- [ ] Todos los botones muestran `CircularProgressIndicator` mientras cargan
- [ ] Todos los errores de Firebase se muestran en español al usuario
- [ ] `OcgEmptyState` presente en: lista de pacientes vacía, sin citas, sin pagos, sin notificaciones, sin simulaciones
- [ ] Fechas en español (`intl` package) en todo el proyecto
- [ ] Animaciones de transición suaves entre pantallas (go_router transitions)
- [ ] Scroll suave en listas largas (sin lag visible)
- [ ] Manejo de conexión offline: mostrar banner si Firestore falla por conectividad

---

## README del proyecto — Guía de deploy

Crear/actualizar `README.md` en la raíz del repositorio:

```markdown
# OCG Clínica — Sistema de Gestión Clínica

## Stack
Flutter 3.x | Firebase | Riverpod | go_router

## Variables de entorno requeridas
- Firebase: google-services.json (Android), GoogleService-Info.plist (iOS), firebase_options.dart (Web)
- Cloud Functions: OPENAI_API_KEY

## Comandos principales
flutter run -d chrome          # Web
flutter run -d android         # Android
flutter build apk --release    # Build Android
flutter build web --release    # Build Web

## Deploy Cloud Functions
cd functions && npm run deploy

## Firestore indexes
firebase deploy --only firestore:indexes

## Firestore rules
firebase deploy --only firestore:rules
```

---

## Criterios de cierre del bloque

- [ ] `AdminDashboardScreen` muestra las 4 métricas reales con stream reactivo
- [ ] Galería fotográfica funcional con subida de fotos y `BeforeAfterSlider`
- [ ] Paciente tiene `BottomNavigationBar` / `NavigationBar` funcional
- [ ] Admin tiene layout adaptable en pantallas anchas
- [ ] `OcgLoadingScreen` mostrado correctamente durante init de Firebase
- [ ] Todos los estados vacíos tienen `OcgEmptyState`
- [ ] Fechas en español en todo el proyecto
- [ ] `README.md` actualizado con guía de deploy
- [ ] `flutter analyze` ✅ — cero warnings
- [ ] `flutter test` ✅ — cobertura de todos los modelos y providers

---

## Orden recomendado de ejecución

1. `dashboard_provider` con las 4 métricas + métodos en repositorios
2. `AdminDashboardScreen` nuevo layout con métricas
3. `PatientPhoto` model + `PhotoRepository` + galería
4. `PatientShell` con `BottomNavigationBar` + ShellRoute en router
5. `OcgAdaptiveScaffold` para admin en web
6. Splash / loading state en `app.dart`
7. Pulido de UX (checklist completo)
8. `README.md`
9. Analyze + tests finales
