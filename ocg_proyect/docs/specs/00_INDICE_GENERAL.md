# OCG Clínica — Índice General del Proyecto

> **Stack:** Flutter 3.x + Dart · Firebase · Riverpod · go_router
> **Plataformas:** Web Admin + Android + iOS — un solo repositorio
> **Repositorio:** OCG-WebUser en GitHub · **Firebase:** ocg_proyect

---

## ⚠️ Lee esto antes de escribir una sola línea de código

Esto no es un proyecto de práctica. Es un sistema de gestión clínica real. Hay pacientes reales, datos de salud sensibles, pagos reales y una doctora que confía en que el sistema funciona bien. Cada decisión de arquitectura que tomes ahora costará el doble corregirla después. Lee todos los documentos antes de empezar.

---

## Mapa de documentos

| # | Archivo | Qué cubre |
|---|---|---|
| 00 | 00_INDICE_GENERAL.md | Visión global, reglas, stack, tokens de color |
| 01 | 01_ARQUITECTURA_Y_SETUP.md | Estructura de carpetas, main.dart, tema OCG, widgets base |
| 02 | 02_BASE_DE_DATOS.md | Esquema Firestore — **lee esto primero que todo** |
| 03 | 03_AUTENTICACION_Y_ROLES.md | Firebase Auth, 2 roles, custom claims, guards |
| 04 | 04_GESTION_PACIENTES.md | CRUD pacientes, pantallas, providers, repositorios |
| 05 | 05_AGENDA_CITAS.md | Citas desde app y web, calendario, estados |
| 06 | 06_TRATAMIENTO_Y_ETAPAS.md | Timeline de etapas, progreso visual |
| 07 | 07_PAGOS.md | Epayco Colombia, recibos PDF, historial |
| 08 | 08_SIMULADOR_SONRISA.md | OpenAI inpainting + ML Kit — feature estrella |
| 09 | 09_NOTIFICACIONES_FCM.md | Push notifications — todos los triggers |

---

## Los dos únicos roles del sistema

No hay roles intermedios. No hay coordinador ni asistente. Son dos:

**Admin (la doctora):** gestión completa de pacientes, agenda citas, actualiza etapas, registra pagos, usa el simulador, ve métricas.

**Paciente:** agenda citas desde la app Y desde la web, ve su tratamiento y etapa actual, paga, usa el simulador, recibe notificaciones.

---

## Plataformas

| Plataforma | Tech | Acceso |
|---|---|---|
| Web Admin / Portal | Flutter Web | Botón "Iniciar Sesión" en la landing page |
| App Android | Flutter Android | Play Store |
| App iOS | Flutter iOS | App Store |

> La Landing Page existe en React + TypeScript + Tailwind. No la toques. Proyecto separado.

---

## Reglas de oro — violación implica rehacer el trabajo

1. No improvises Firestore. Lee 02_BASE_DE_DATOS.md antes de crear un documento.
2. Riverpod para todo el estado. Cero setState fuera de widgets 100% locales.
3. Repositorios como única puerta a Firebase. La UI nunca llama directo a FirebaseFirestore.
4. go_router con guards. Ninguna ruta protegida sin auth y rol correcto.
5. Manejo de errores visible al usuario. Cero fallos silenciosos, cero prints en producción.
6. Colores del tema OCG en todo. Nada de Colors.blue hardcodeado fuera de ocg_colors.dart.
7. URLs de Storage siempre temporales. Fotos de pacientes nunca son públicas permanentes.

---

## Stack completo

```yaml
# Ya instalados:
flutter_riverpod: ^3.2.1
go_router: ^17.1.0
firebase_core: ^4.5.0
firebase_auth: ^6.2.0
cloud_firestore: ^6.1.3
firebase_storage: ^13.1.0
firebase_functions: ^0.0.1
dio: ^5.9.2

# DEBES AGREGAR:
firebase_messaging
google_mlkit_face_detection
camera
image_picker
image
flutter_local_notifications
cached_network_image
intl
url_launcher
table_calendar
fl_chart
pdf
share_plus
```

---

## Tokens de color OCG

```dart
// lib/shared/theme/ocg_colors.dart
class OcgColors {
  OcgColors._();
  static const Color espresso = Color(0xFF2C2016); // Principal
  static const Color bronze   = Color(0xFF8A6F59); // Acento
  static const Color ivory    = Color(0xFFF8F5F0); // Fondo
  static const Color sand     = Color(0xFFECD9C6); // Fondo alt
  static const Color mist     = Color(0xFFF2EDE8); // Cards
  static const Color ink      = Color(0xFF1A1410); // Texto
  static const Color success  = Color(0xFF166534); // Verde
  static const Color warning  = Color(0xFF92400E); // Naranja
  static const Color error    = Color(0xFF991B1B); // Rojo
}
```
