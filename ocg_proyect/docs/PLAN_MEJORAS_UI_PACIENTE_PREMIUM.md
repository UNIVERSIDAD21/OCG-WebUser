# Plan de mejoras UI — Rediseño premium de OCG-WebUser

> Fecha: 2026-05-09 (actualizado tras segunda pasada de análisis)  
> Repo: `OCG-WebUser/ocg_proyect`  
> Responsable: Borlty  
> Objetivo: elevar la experiencia visual de todas las pantallas al mismo nivel premium/futurista que ya tienen login y recuperar contraseña.  
> Origen: análisis completo de `2026-05-09` (dos pasadas).  
> Referencia: paleta OCG (`OcgColors`), diseño glassmorphism, gradientes, blobs decorativos y animaciones sutiles.

---

## 📦 Pendientes de ejecutar cuando Jefe lo indique

Junto con este plan queda pendiente:

- **`docs/PLAN_REFACTOR_ARCHIVOS_GIGANTES_OCG.md`** — Refactor seguro de 14 archivos grandes de UI a módulos más pequeños sin romper funcionalidad. Ya iniciado en P6 sobre `admin_appointments_screen.dart` (helpers extraídos).

---

## 1. Rediseñar Perfil (paciente + admin)

**Archivos:** `patient_profile_screen.dart` (650 líneas), `admin_profile_screen.dart` (488 líneas)

**Estado actual:** Ambas pantallas usan AppBar + Scaffold básico con cards utilitarias y `AlertDialog` nativo para cerrar sesión. Sin tratamiento visual premium. El admin comparte el mismo problema: 488 líneas con cero diseño de marca.

**Mejoras planeadas:**

- Hero header premium con foto de perfil animada (pulso sutil en el borde)
- Glass card para cada sección (Datos personales, Contacto, Médico)
- Blobs decorativos de fondo con gradiente OCG
- Animación de entrada (fade + slide) al abrir
- Badges de estado del perfil (completo/incompleto)
- Acciones (editar teléfono, cambiar foto, restablecer contraseña, cerrar sesión) dentro de cards con iconografía premium
- Reemplazar `AlertDialog` de cierre de sesión por diálogo OCG unificado (ver bloque 4)

**Cuidado:**
- Paciente: no romper `embedded = true` (se usa dentro de `AdminMobileShell` y `PatientHomeScreen`)
- Admin: no romper `embeddedInMobileShell`
- No tocar providers de perfil, `ProfilePhotoService`, ni Firebase
- Mantener `PatientViewerMode`

---

## 2. Rediseñar Splash Screen

**Archivo:** `app_router.dart` → `_AuthResolvingScreen`

**Estado actual:** `CircularProgressIndicator` centrado sin branding.

**Mejoras planeadas:**

- Fondo con gradiente OCG (ivory → sand → mist)
- Logo OCG animado con escala + fade in
- Indicador de carga estilizado (línea de progreso inferior o dots animados)
- Transición suave hacia login o dashboard
- Blobs decorativos sutiles
- Texto "OCG" o "Human Bionics" con animación de entrada

**Cuidado:**
- No modificar la lógica de resolución de auth
- No bloquear el redirect del router
- Mantener el `CircularProgressIndicator` como fallback si la animación no carga

---

## 3. Rediseñar Empty States

**Archivo:** `shared/widgets/ocg_empty_state.dart`

**Estado actual:** Widget funcional con icono, título, subtítulo y botón opcional. Sin animaciones ni gradientes.

**Mejoras planeadas:**

- Ilustraciones con íconos grandes animados (escala sutil)
- Gradiente de fondo en el contenedor del empty state
- Bordes redondeados premium (glass card ligera)
- Variantes por contexto:
  - Sin pacientes
  - Sin citas
  - Sin documentos
  - Sin notificaciones
  - Sin tratamientos
  - Sin resultados de búsqueda
  - Sin conexión / error de red
- Botón CTA con estilo OCG (espresso, bordes redondeados)
- Soporte para CTA secundario (ej: "Limpiar filtros")
- Animación de entrada al mostrarse

**Cuidado:**
- Mantener compatibilidad con todas las pantallas que usan `OcgEmptyState`
- No cambiar la API del widget sin actualizar todos los call sites
- Hacer extracción gradual (un componente a la vez)

---

## 4. Diálogos de confirmación unificados (marca OCG)

**Alcance real:** **38+ instancias** de `AlertDialog` nativo en toda la app.

**Estado actual:** Mientras login, registro y recuperar contraseña ya tienen diseño glass-morphism premium, **todo el resto de la app** usa `AlertDialog` gris de Material. Esto es el mayor problema de consistencia visual del proyecto.

**Instancias detectadas por módulo:**

| Módulo | Usos de `AlertDialog` |
|--------|:--:|
| Admin appointments screen | 10 |
| Patient appointments screen | 4 |
| Admin dashboard screen | 2 |
| Admin profile screen | 2 |
| Admin patients screen | 2 |
| Admin sidebar | 3 |
| Admin topbar | 1 |
| Patient profile screen | 3 |
| Patient form screen | 1 |
| Patient detail screen | 1 |
| Patient clinical history tab | 2 |
| Patient payments screen | 2 |
| Manage patient treatment dialog | 1 |
| Update stage dialog | 1 |
| Register payment dialog | 1 |
| PayU checkout screen | 1 |
| Patient simulator tab | 1 |

**Mejoras planeadas:**

- Crear `OcgConfirmDialog` con diseño glassmorphism
- Header con ícono de gradiente según tipo (peligro, info, éxito)
- Botones estilizados: cancelar (outline arena) y confirmar (espresso sólido o rojo para destruir)
- Animación de entrada (escala + fade)
- Soporte para variantes:
  - `danger` (eliminar, cerrar sesión, desactivar) — ícono rojo
  - `warning` (cambios no guardados, salir sin guardar) — ícono ámbar
  - `info` (confirmar acción, enviar) — ícono OCG bronze
- Fondo semi-transparente con blur
- API simple: `OcgConfirmDialog.show(context, type:, title:, message:, onConfirm:)`

**Cuidado:**
- Reemplazar gradualmente, un módulo por commit
- No cambiar comportamiento de confirmación (mantener `popDialog(ctx, true/false)`)
- Priorizar primero los más visibles: eliminar paciente, cerrar sesión, cancelar cita

---

## 5. Rediseñar formulario crear/editar paciente

**Archivo:** `patient_form_screen.dart` (692 líneas)

**Estado actual:** Formulario funcional pero utilitario. Sin diseño premium.

**Mejoras planeadas:**

- Hero header con gradiente OCG e ícono de paciente
- Campos con el estilo de inputs del nuevo registro (labels con iconografía arriba)
- Secciones con divisores decorativos (Datos personales, Contacto, Médico)
- Foto de perfil con placeholder premium y botón de cámara estilizado
- Validación visual en tiempo real (borde verde/rojo al validar)
- Botones de acción con altura consistente y gradiente en el principal
- Animación de entrada al abrir
- Versión móvil con scroll optimizado y teclado (sin overflow)

**Cuidado:**
- No romper `embeddedInAdminMobileShell`
- Mantener `PatientFormScreen(patientId:)` para edición
- No tocar providers ni repositorios
- Validaciones (`Validators`) intactas

---

## 6. Rediseñar pantalla de Citas del paciente

**Archivo:** `patient_appointments_screen.dart` (1567 líneas)

**Estado actual:** Pantalla funcional con lista de citas. Visualmente plana para el paciente. 4 `AlertDialog` nativos.

**Mejoras planeadas:**

- Hero header premium con resumen: próxima cita, total pendientes
- Cards de cita con diseño de marca:
  - Icono y color por estado (pendiente, confirmada, completada, cancelada)
  - Chip de estado fuerte
  - Fecha y hora destacadas
  - Tipo de cita y duración
  - Notas clínicas si existen
- Timeline visual para paciente (pendientes → historial)
- Filtros rápidos: Pendientes, Historial
- Empty state premium cuando no hay citas
- Acción rápida: ver perfil del doctor, agregar al calendario
- Reemplazar `AlertDialog` por `OcgConfirmDialog`

**Cuidado:**
- No tocar `AppointmentsBusinessRules`
- No modificar providers ni repositorios
- Mantener `embedded = false/true` para modo admin y paciente
- No romper navegación de FCM desde notificaciones a citas

---

## 7. Rediseñar sección Tratamiento del paciente — vista móvil

**Archivos:** `patient_home_screen.dart` (2531 líneas), `patient_treatment_tab.dart` (2250 líneas)

**Estado actual:** `PatientHomeScreen` maneja tratamientos con un selector y contenido de tabs (overview, pagos, documentos). El diseño es funcional pero no premium.

**Mejoras planeadas:**

- Hero de tratamiento activo con gradiente OCG y progreso visual de etapas
- Timeline horizontal de etapas con animación de progreso
- Cards expandibles para cada etapa (estado, fechas, notas)
- Selector de tratamiento multi-tratamiento más premium (chips con gradiente)
- Métricas rápidas del tratamiento (inicio, valor total, saldo, próxima cita)
- Alertas contextuales mejoradas (sin próxima cita, etapa estancada, saldo pendiente)
- Transiciones suaves entre tabs (overview ↔ pagos ↔ documentos)
- Chips de estado con iconografía y color fuerte

**Cuidado:**
- No romper `initialSection` ni `initialTreatmentView`
- No reintroducir scroll anidado
- Mantener `PatientTreatmentInitialView` para navegación interna
- No tocar lógica financiera, pagos ni repositorios

---

## 8. 🆕 Estandarizar Loading States

**Archivos:** ~30+ ubicaciones con `CircularProgressIndicator` pelado

**Estado actual:** La app usa `CircularProgressIndicator()` sin color OCG en la mayoría de pantallas. Existe `OcgLoadingState` pero casi nadie lo usa. Esto rompe la experiencia premium durante las esperas.

**Ubicaciones detectadas (parcial):**

| Archivo | Usos |
|--------|:--:|
| `patient_home_screen.dart` | 6 |
| `admin_appointments_screen.dart` | 4 |
| `admin_dashboard_screen.dart` | 3 |
| `patient_appointments_screen.dart` | 2 |
| `simulator_screen.dart` | 4 |
| `patient_simulations_screen.dart` | 2 |
| `patient_shared_clinical_files_screen.dart` | 1 |
| `app_router.dart` (splash) | 1 |

**Mejoras planeadas:**

- Revisar y mejorar `OcgLoadingState` existente
- Agregar variantes: `inline` (pequeño), `fullPage` (con gradiente de fondo), `overlay` (semi-transparente)
- Reemplazar todos los `CircularProgressIndicator` pelados por `OcgLoadingState`
- Asegurar que el color del spinner sea siempre `OcgColors.espresso` o `OcgColors.bronze`

**Cuidado:**
- No cambiar la lógica de `AsyncValue.when(loading: ...)`
- Reemplazar en lote por archivo para evitar regresiones
- Un commit por módulo

---

## 9. 🆕 AppBars premium OCG

**Archivos:** 7+ pantallas con `AppBar(title: Text(...))` básico

**Estado actual:** Varias pantallas del paciente usan AppBar plano de Material sin ningún diseño de marca, mientras que las pantallas admin ya tienen `AdminWebShell` con header premium. Esto crea una experiencia inconsistente entre roles.

**Pantallas con AppBar básico:**

| Pantalla | AppBar actual |
|----------|:--|
| Perfil paciente | `AppBar(title: 'Mi perfil')` |
| Detalle paciente (móvil) | `AppBar(title: 'Detalle de paciente')` |
| Crear/editar paciente | `AppBar(title: ...)` |
| Notificaciones paciente | `AppBar(title: ...)` |
| Simulaciones paciente | `AppBar(title: ...)` |
| Documentos clínicos | `AppBar(title: 'Documentos clínicos')` |
| Citas paciente | `AppBar(title: ...)` |

**Mejoras planeadas:**

- Crear `OcgAppBar` reutilizable con:
  - Gradiente de fondo OCG sutil
  - Título con tipografía OCG
  - Botón de retroceso estilizado
  - Soporte para acciones premium
  - Sombra inferior suave (glass effect)
- Crear `OcgPageHeader` para pantallas sin AppBar (modo embedded)
- Reemplazar gradualmente en todas las pantallas del paciente

**Cuidado:**
- No romper botones de acción existentes
- Mantener compatibilidad con `embedded` mode
- Respetar `SafeArea` y `systemOverlayStyle`

---

## 10. 🆕 Rediseñar Documentos clínicos del paciente

**Archivos:** `patient_shared_clinical_files_screen.dart` (327 líneas), `patient_clinical_history_tab.dart` (958 líneas)

**Estado actual:** Pantalla funcional pero con loading states básicos y listas planas. Los archivos se muestran como items de lista sin iconografía de tipo ni diseño premium. 2 `AlertDialog` nativos (visibilidad, confirmación).

**Mejoras planeadas:**

- Hero header premium con resumen de documentos
- Cards por archivo con:
  - Icono grande según tipo (PDF, imagen, informe, radiografía, etc.)
  - Categoría con chip de color
  - Tratamiento asociado
  - Fecha y tamaño
  - Indicador de visibilidad (paciente/admin/solo admin)
  - Estados: activo, archivado
- Filtros premium: por tratamiento, categoría, visibilidad
- Empty state premium con CTA de subir documento
- Acciones contextuales en cada card: abrir, descargar, cambiar visibilidad
- Reemplazar `AlertDialog` de confirmación por `OcgConfirmDialog`

**Cuidado:**
- No tocar Firebase Storage ni reglas
- No cambiar estructura de datos sin justificar migración
- Mantener `embedded` y `patientIdOverride`
- No romper upload/delete/visibility writes

---

## Orden de ejecución recomendado

### Fase 1 — Componentes transversales (bajo riesgo, alto impacto)
1. **Splash screen** — branding inmediato al abrir la app
2. **Empty states** — mejora todas las pantallas de una vez
3. **Loading states** — elimina spinners pelados en toda la app
4. **Diálogos de confirmación** — 38+ AlertDialogs nativos → OCG glass

### Fase 2 — AppBars y estructura
5. **AppBars premium OCG** — unifica headers en 7+ pantallas

### Fase 3 — Pantallas del paciente
6. **Citas del paciente** — operación diaria, alto uso
7. **Documentos clínicos paciente** — cards premium, iconografía de tipo
8. **Tratamiento paciente móvil** — el más complejo, mucho contenido denso

### Fase 4 — Perfiles y formularios
9. **Perfil (paciente + admin)** — glass cards, hero premium
10. **Formulario crear/editar paciente** — data entry premium

---

## Checklist para cada bloque

- [ ] Confirmar alcance exacto con Jefe
- [ ] No tocar módulos fuera de alcance
- [ ] No romper providers, repositorios, Firebase ni rutas
- [ ] Revisar scroll/navegación/bottom nav después del cambio
- [ ] Verificar estados loading/error/empty
- [ ] `dart format` en archivos tocados
- [ ] `flutter analyze` limpio
- [ ] `flutter test` en tests del módulo
- [ ] `flutter test` suite completa
- [ ] Revisar `git diff` antes de commit
- [ ] Commit en español, sin prefijos tipo `feat:`/`fix:`
- [ ] Push a `main` con validación limpia
