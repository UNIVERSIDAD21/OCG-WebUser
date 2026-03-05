# 03 — Autenticación y Roles

> **Tu objetivo:** sistema de auth completo con Firebase Auth, dos roles diferenciados mediante Custom Claims, guards de navegación y login/logout funcionando en web, Android e iOS.

---

## Lo que debes entregar al terminar este bloque

- [ ] Login con email + contraseña funcionando
- [ ] Custom Claims configurados para los dos roles
- [ ] Cloud Function onUserCreated que asigna el rol patient por defecto
- [ ] Guard de go_router que redirige según rol
- [ ] LoginScreen con el diseño OCG
- [ ] ForgotPasswordScreen funcionando
- [ ] Logout funcional con limpieza de estado
- [ ] El admin NO puede registrarse solo — su cuenta la crea manualmente el dueño del proyecto

---

## Cómo funcionan los roles

Usa Firebase Auth **Custom Claims** para almacenar el rol. No uses un campo en Firestore para validar el rol en el cliente — los Custom Claims viajan en el token JWT y las reglas de Firestore los pueden leer directamente.

El Custom Claim es: `{ "role": "admin" }` o `{ "role": "patient" }`

Los Custom Claims SOLO se pueden setear desde el servidor (Cloud Functions o Admin SDK). El cliente nunca puede modificar su propio rol.

---

## Cloud Functions para gestión de roles

### onUserCreated — asigna rol patient a nuevos usuarios

```typescript
// functions/src/auth/on_user_created.ts
export const onUserCreated = functions.auth.user().onCreate(async (user) => {
  // Todo usuario nuevo es patient por defecto
  // El admin se crea manualmente y se le asigna el rol por separado
  await admin.auth().setCustomUserClaims(user.uid, { role: 'patient' });

  // Crear documento en patients/
  await admin.firestore().collection('patients').doc(user.uid).set({
    id: user.uid,
    nombre: user.displayName ?? '',
    email: user.email ?? '',
    telefono: '',
    fechaNacimiento: null,
    fotoUrl: null,
    tipoTratamiento: null,
    etapaActual: null,
    fechaInicio: null,
    fechaEstimadaFin: null,
    notasClinicas: '',
    fotosUrls: [],
    totalTratamiento: 0,
    saldoPendiente: 0,
    fechaProximoPago: null,
    fcmToken: '',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});
```

### setAdminRole — función manual para crear admin

Esta función se invoca una sola vez manualmente (o desde la consola de Firebase) para darle rol de admin a la doctora.

```typescript
export const setAdminRole = functions.https.onCall(async (data, context) => {
  // Solo puede ser invocada por otro admin autenticado
  if (context.auth?.token.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'No autorizado');
  }
  const { uid } = data;
  await admin.auth().setCustomUserClaims(uid, { role: 'admin' });

  // Mover documento de patients/ a admins/
  const patientDoc = await admin.firestore().collection('patients').doc(uid).get();
  if (patientDoc.exists) {
    await admin.firestore().collection('admins').doc(uid).set({
      ...patientDoc.data(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await admin.firestore().collection('patients').doc(uid).delete();
  }
  return { success: true };
});
```

---

## auth_service.dart — Servicio de autenticación

```dart
// lib/services/firebase/auth_service.dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream del usuario actual
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener el rol del token (Custom Claims)
  Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final tokenResult = await user.getIdTokenResult(true); // forceRefresh=true
    return tokenResult.claims?['role'] as String?;
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email, password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Después del login, actualizar el FCM token del usuario
  Future<void> updateFcmToken(String uid, String role, String token) async {
    final collection = role == 'admin' ? 'admins' : 'patients';
    await _db.collection(collection).doc(uid).update({'fcmToken': token});
  }
}
```

---

## auth_provider.dart — Estado de autenticación en Riverpod

```dart
// lib/features/auth/providers/auth_provider.dart

// Estado del usuario autenticado
@riverpod
Stream<User?> authState(AuthStateRef ref) {
  return FirebaseAuth.instance.authStateChanges();
}

// Rol del usuario actual (lee Custom Claims)
@riverpod
Future<String?> userRole(UserRoleRef ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final authService = ref.read(authServiceProvider);
  return authService.getUserRole();
}

// Notifier para el proceso de login
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signIn(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(email, password);
    });
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(authStateProvider);
    ref.invalidate(userRoleProvider);
  }
}
```

---

## Guards de navegación en go_router

```dart
// lib/app/router/app_router.dart
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authStateProvider);
  final userRole = ref.watch(userRoleProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading || userRole.isLoading;

      if (isLoading) return null; // Esperar mientras carga

      if (!isLoggedIn) {
        // No autenticado — solo puede ir a /login y /forgot-password
        final allowed = ['/login', '/forgot-password'];
        if (!allowed.contains(state.matchedLocation)) return '/login';
        return null;
      }

      final role = userRole.valueOrNull;

      // Autenticado pero en /login — redirigir según rol
      if (state.matchedLocation == '/login') {
        return role == 'admin' ? '/admin/dashboard' : '/patient/home';
      }

      // Admin intentando acceder a rutas de paciente — redirigir
      if (role == 'admin' && state.matchedLocation.startsWith('/patient')) {
        return '/admin/dashboard';
      }

      // Paciente intentando acceder a rutas de admin — redirigir
      if (role == 'patient' && state.matchedLocation.startsWith('/admin')) {
        return '/patient/home';
      }

      return null; // Todo bien, continuar
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      // Rutas admin — ver documento 04 en adelante
      ShellRoute(/* ... */),
      // Rutas patient
      ShellRoute(/* ... */),
    ],
  );
}
```

---

## LoginScreen — Diseño OCG

La pantalla de login es la primera impresión del sistema. Tiene que verse profesional.

Estructura visual:
1. Logo OCG (texto "OCG Clínica" en Cormorant Garamond, espresso + bronze) — centrado
2. Subtítulo pequeño: "Panel de gestión clínica" — en Inter, gris
3. Campo email con ícono de sobre
4. Campo contraseña con ícono de candado y toggle de visibilidad
5. Botón OcgButton primary: "Iniciar sesión" — full width
6. Link de texto: "¿Olvidaste tu contraseña?" — centrado debajo

Fondo: ivory. Sin imágenes innecesarias. Sin animaciones complejas. Limpio y sobrio.

Manejo de errores:
- Credenciales incorrectas → mensaje en rojo debajo del botón: "Correo o contraseña incorrectos"
- Sin conexión → "Sin conexión a internet. Verifica tu red."
- El botón muestra loading mientras se procesa

---

## Registro de pacientes

Los pacientes se registran desde la app o desde el portal web usando Firebase Auth createUserWithEmailAndPassword. Al crearse la cuenta, la Cloud Function onUserCreated asigna automáticamente el rol 'patient' y crea su documento en patients/.

El admin NO crea las cuentas de los pacientes manualmente — el paciente se registra solo. Lo que SÍ hace el admin es completar los datos clínicos del perfil después de la primera cita presencial.
