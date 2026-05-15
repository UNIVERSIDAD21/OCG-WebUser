# 01 — Arquitectura y Setup Inicial

> **Tu objetivo en este bloque:** dejar el proyecto corriendo en web, Android e iOS con el tema OCG aplicado, la navegación base funcionando y los widgets reutilizables creados. Sin datos reales todavía — eso viene en el bloque 02 y 03.

---

## Lo que debes entregar al terminar este bloque

- [ ] El proyecto corre en Flutter Web sin errores
- [ ] El proyecto corre en Android sin errores
- [ ] El proyecto corre en iOS sin errores
- [ ] El tema OCG (colores, tipografía) está aplicado globalmente
- [ ] La estructura de carpetas está creada y vacía lista para llenar
- [ ] Los widgets base de la marca están implementados
- [ ] main.dart inicializa Firebase correctamente

---

## Estructura de directorios — créala exactamente así

```
lib/
├── main.dart
├── app/
│   ├── app.dart
│   └── router/
│       ├── app_router.dart
│       └── route_names.dart
├── features/
│   ├── auth/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   ├── dashboard/
│   │   ├── presentation/
│   │   └── providers/
│   ├── patients/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   ├── appointments/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   ├── treatment/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   ├── payments/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   ├── photos/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   ├── simulator/
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── repositories/
│   └── notifications/
│       ├── presentation/
│       └── providers/
├── services/
│   ├── firebase/
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   └── storage_service.dart
│   ├── api/
│   │   ├── api_client.dart
│   │   ├── openai_service.dart
│   │   └── epayco_service.dart
│   └── notifications/
│       └── fcm_service.dart
└── shared/
    ├── models/
    ├── widgets/
    ├── theme/
    │   ├── ocg_colors.dart
    │   ├── ocg_text_styles.dart
    │   └── ocg_theme.dart
    ├── utils/
    └── constants/
        ├── firestore_paths.dart
        └── storage_paths.dart
```

---

## main.dart — Hazlo bien desde el principio

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
  );
  FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);
  runApp(const ProviderScope(child: OcgApp()));
}

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // procesar notificación en background
}
```

---

## ocg_theme.dart — El tema que se aplica a MaterialApp

El ThemeData debe incluir:
- colorScheme basado en los tokens OCG (primary = espresso, secondary = bronze)
- textTheme con Cormorant Garamond para display y Inter para body
- AppBar con fondo espresso, texto ivory
- ElevatedButton con forma pill (BorderRadius circular 99), fondo espresso
- OutlinedButton con borde espresso/30
- InputDecoration con borde redondeado y colores OCG
- CardTheme con color mist, borderRadius 20, elevación 0

**No uses el tema por defecto de Flutter para nada.** Si ves azul de Material en alguna pantalla, algo salió mal.

---

## Constantes de Firestore — No hardcodees strings de colecciones

```dart
// lib/shared/constants/firestore_paths.dart
class FirestorePaths {
  FirestorePaths._();
  static const String admins       = 'admins';
  static const String patients     = 'patients';
  static const String appointments = 'appointments';
  static const String payments     = 'payments';
  static const String simulations  = 'simulations';
  static const String notifications = 'notifications';

  static String adminDoc(String adminId)     => 'admins/$adminId';
  static String patientDoc(String patientId) => 'patients/$patientId';
  static String stageHistory(String patientId) =>
      'patients/$patientId/stageHistory';
  static String transactions(String paymentId) =>
      'payments/$paymentId/transactions';
}
```

```dart
// lib/shared/constants/storage_paths.dart
class StoragePaths {
  StoragePaths._();
  static String patientProfile(String id)       => 'patients/$id/profile/profile.jpg';
  static String patientPhoto(String id, String name) => 'patients/$id/photos/$name';
  static String simulationResult(String pid, String sid, String name) =>
      'simulations/$pid/$sid/$name';
  static String simulatorTemp(String sessionId, String name) =>
      'simulator_temp/$sessionId/$name';
}
```

---

## Widgets base a implementar en shared/widgets/

Estos widgets son los ladrillos del diseño. Todos usan exclusivamente tokens OCG.

### OcgButton
Tres variantes: primary (espresso relleno), outline (borde espresso), ghost (solo texto).
Acepta ícono opcional, estado isLoading que muestra CircularProgressIndicator de tamaño pequeño.

### OcgCard
Card base con: borderRadius 20, borde Color(0x1A2C2016), fondo mist, cero elevación.
Acepta padding personalizable y child slot.

### OcgChip
Badge de estado pequeño. Colores semánticos según el valor:
- completado → verde fondo + texto
- activo/en_curso → bronze
- pendiente → naranja
- cancelado → rojo

### OcgTextField
Campo de texto con label flotante, hint, ícono, mensaje de error, borde redondeado.
Estado focused: borde bronze. Error: borde error.

### OcgLoadingScreen
Pantalla completa con logo OCG centrado y un shimmer animado sutil debajo.
Duración esperada: < 2 segundos. Si dura más, algo está mal en el servicio.

### OcgEmptyState
Estado vacío: ícono grande (60px), título, subtítulo opcional, botón CTA opcional.
Usar cuando una lista no tiene resultados todavía.

### BeforeAfterSlider
Slider interactivo drag para comparar dos imágenes. Línea divisoria vertical arrastrable.
Reutilizado en: galería fotográfica de pacientes y resultado del Simulador de Sonrisa.
