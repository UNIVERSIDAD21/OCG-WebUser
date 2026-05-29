# Simulador - Paso 1: Reestructuración de Tratamientos

> **Objetivo:** Reorganizar completamente el selector de tratamientos del Paso 1 del Simulador para agruparlos por categorías dentales, agregar nuevos tratamientos, y mejorar la UI para que sea visualmente atractiva.

---

## BLOQUE 1 — Arquitectura actual

### Archivos involucrados
| Archivo | Rol |
|---|---|
| `lib/features/simulator/domain/dental_treatment_profile.dart` | Define `DentalTreatmentProfile`, `TreatmentConfigField`, y el registro `treatmentProfiles` (lista plana de perfiles) |
| `lib/features/simulator/presentation/widgets/treatment_profile_selector.dart` | Widget dropdown que muestra la lista plana con `MenuAnchor` |
| `lib/features/simulator/presentation/widgets/doctor_config_form.dart` | Renderiza los campos de configuración (`configFields`) de cada perfil |
| `lib/features/simulator/presentation/simulator_screen.dart` | Pantalla principal del simulador que integra `TreatmentProfileSelector` y `DoctorConfigForm` |

### Estructura de datos actual
```dart
class DentalTreatmentProfile {
  String id;            // ej: 'metal_braces'
  String label;         // ej: 'Brackets metálicos'
  String description;   // descripción corta
  IconData icon;        // icono de Material Icons
  Color color;          // color de acento del perfil
  String defaultVisualGoal;
  List<TreatmentConfigField> configFields;  // campos configurables
  Map<String, dynamic> defaultConfig;
}

class TreatmentConfigField {
  String key;                // ej: 'material', 'ligatureColor'
  String label;              // etiqueta visible
  TreatmentConfigFieldType type;  // chips o dropdown
  List<TreatmentConfigOption> options;  // opciones del campo
  dynamic defaultValue;
}
```

### Perfiles actuales (lista plana)
1. `metal_braces` — Brackets metálicos
2. `esthetic_braces` — Brackets estéticos
3. `clear_aligners` — Alineadores
4. `whitening` — Blanqueamiento
5. `veneers` — Carillas / Vinillas
6. `smile_design` — Diseño de sonrisa
7. `palatal_expander` — Expansor de paladar
8. `retainer` — Retenedor

---

## BLOQUE 2 — Nueva estructura de tratamientos (GRUPOS + SUB-TRATAMIENTOS)

Los tratamientos deben organizarse en **7 grupos principales**. Cada grupo puede contener uno o más sub-tratamientos. La UI debe mostrar primero los grupos (como cards o secciones expandibles) y dentro de cada grupo, los sub-tratamientos seleccionables.

### Grupo 1: Operatorio
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Reconstrucción | `reconstruccion` | Reconstruir un diente dañado o con caries extensa | `Icons.build_outlined` | `#8D6E63` |

### Grupo 2: Higiene Oral
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Limpieza | `limpieza_oral` | Simulación visual del resultado después de una limpieza oral profesional | `Icons.clean_hands_outlined` | `#66BB6A` |

### Grupo 3: Rehabilitación
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Reemplazo de dientes | `reemplazo_dental` | Tratamiento general para sustituir dientes perdidos (prótesis, puentes, coronas) | `Icons.account_tree_outlined` | `#FF7043` |
| Implantes dentales | `implantes_dentales` | Colocación de tornillo/raíz artificial en el hueso con corona que simula el diente | `Icons.medication_outlined` | `#5C6BC0` |

### Grupo 4: Diseño de Sonrisa
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Carillas | `carillas` (renombrar de `veneers`) | Forma, proporción y tono de dientes anteriores | `Icons.auto_fix_high_outlined` | `#E0C097` |
| Blanqueamiento | `blanqueamiento` (renombrar de `whitening`) | Cambio de tono dental sin alterar forma | `Icons.wb_sunny_outlined` | `#FFB74D` |
| Bordes dentales | `bordes_incisales` | Mejora de forma/tamaño de dientes delanteros desgastados, fracturados o desiguales | `Icons.format_shapes_outlined` | `#FFCC80` |

### Grupo 5: Acciones de Periodoncia
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Gingivectomía | `gingivectomia` | Recorte de encía para eliminar exceso de tejido gingival | `Icons.content_cut_outlined` | `#EF5350` |
| Gingivoplastia | `gingivoplastia` | Remodelación estética de la encía para darle mejor forma y contorno | `Icons.auto_fix_normal_outlined` | `#EC407A` |
| Alineación de márgenes | `alineacion_margenes` | Corrección del contorno gingival para niveles de encía más simétricos | `Icons.align_horizontal_center_outlined` | `#AB47BC` |

### Grupo 6: Ortodoncia
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Brackets metálicos | `metal_braces` (EXISTENTE) | Brackets metálicos visibles con arco y ligas de colores | `Icons.engineering_outlined` | `#607D8B` |
| Brackets estéticos | `esthetic_braces` (EXISTENTE, MODIFICADO) | Brackets cerámicos o metálicos discretos | `Icons.diamond_outlined` | `#B0BEC5` |
| Alineadores | `clear_aligners` (EXISTENTE) | Cubetas transparentes tipo Invisalign | `Icons.remove_red_eye_outlined` | `#4DB6AC` |

### Grupo 7: Ortopedia
| Sub-tratamiento | ID | Descripción | Icono | Color |
|---|---|---|---|---|
| Expansor del paladar | `palatal_expander` (EXISTENTE) | Expansor Hyrax/Haas en arcada superior | `Icons.architecture_outlined` | `#795548` |
| Retenedores | `retainer` (EXISTENTE) | Retenedor post-tratamiento Essix/Hawley/fijo | `Icons.lock_outline` | `#26A69A` |

---

## BLOQUE 3 — Cambios en la UI del Paso 1

### 3.1 Reemplazar el dropdown actual por una UI de grupos con cards

**Ubicación:** `treatment_profile_selector.dart`

**Qué hacer:**
- Eliminar el `MenuAnchor`/dropdown actual
- Reemplazar por una lista vertical de **grupos expandibles** (usando `ExpansionTile` o `ExpansionPanelList`)
- Cada grupo muestra:
  - **Header:** ícono del grupo + nombre del grupo + badge con cantidad de sub-tratamientos
  - **Body expandido:** grid de cards (2 columnas en desktop, 1 columna en móvil) con los sub-tratamientos
- Cada card de sub-tratamiento debe tener:
  - Ícono grande (40x40) con fondo del color del perfil al 12%
  - Nombre del tratamiento (bold, 14px)
  - Descripción corta (11px, color ink)
  - Al seleccionarlo: borde del color del perfil + check overlay
  - La card completa debe ser tappable

### 3.2 Estilo visual de las cards

```dart
// Cada card debe verse así:
Container(
  decoration: BoxDecoration(
    color: isSelected 
      ? profile.color.withOpacity(0.08) 
      : OcgColors.ivory,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isSelected 
        ? profile.color.withOpacity(0.4) 
        : OcgColors.bronze.withOpacity(0.12),
      width: isSelected ? 2 : 1,
    ),
  ),
  child: Column(
    children: [
      // Icono grande con fondo tintado
      Container(icon del tratamiento),
      // Nombre
      Text(profile.label, bold),
      // Descripción
      Text(profile.description, small),
      // Si está seleccionado: badge "Seleccionado"
      if (isSelected) badge de confirmación,
    ],
  ),
)
```

### 3.3 Definir la estructura de grupos en código

Crear una nueva clase o estructura en `dental_treatment_profile.dart`:

```dart
class TreatmentGroup {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<DentalTreatmentProfile> treatments;
}

// Luego definir la lista de grupos:
final List<TreatmentGroup> treatmentGroups = [
  TreatmentGroup(id: 'operatoria', label: 'Operatorio', ...),
  TreatmentGroup(id: 'higiene_oral', label: 'Higiene Oral', ...),
  // ... etc
];
```

### 3.4 El selector de grupos debe ser el nuevo widget

Modificar `TreatmentProfileSelector` para que:
- Reciba la lista de `treatmentGroups` en vez de `treatmentProfiles`
- Renderice los grupos con `ExpansionTile` o similar
- Al seleccionar un sub-tratamiento, llame a `onSelected(profile.id)` igual que antes
- Mantener compatibilidad con el parámetro `compact` para móvil

---

## BLOQUE 4 — Configuraciones específicas de cada sub-tratamiento

### 4.1 Brackets metálicos: Selector de COLOR COMPLETO

**Cambio:** Reemplazar el campo `ligatureColor` tipo chips (6 opciones fijas: gris, transparente, azul, rojo, morado, multicolor) por un **selector de color completo**.

**Implementación sugerida:**
- Usar `GridView` con una paleta de colores predefinida (todos los colores estándar de ligas ortodónticas: ~20-30 colores)
- Cada celda es un círculo del color
- Al seleccionar: borde blanco + check
- Se puede usar un `ColorPicker` simplificado con chips circulares:

```dart
// Colores de ligas disponibles (todos)
static const List<Color> ligatureColors = [
  Colors.grey,        // Gris
  Colors.transparent, // Transparente (representado con borde punteado)
  Color(0xFF2196F3), // Azul
  Color(0xFFF44336), // Rojo
  Color(0xFF9C27B0), // Morado
  Color(0xFFFF5722), // Naranja
  Color(0xFFFFEB3B), // Amarillo
  Color(0xFF4CAF50), // Verde
  Color(0xFF00BCD4), // Cyan
  Color(0xFFE91E63), // Rosa
  Color(0xFF3F51B5), // Azul oscuro
  Color(0xFF009688), // Teal
  Color(0xFF795548), // Café
  Color(0xFF607D8B), // Azul grisáceo
  Color(0xFFFFFFFF), // Blanco
  Color(0xFF212121), // Negro
  Color(0xFF8BC34A), // Verde claro
  Color(0xFFFFC107), // Ámbar
  Color(0xFFCDDC39), // Lima
  Color(0xFFFF9800), // Naranja oscuro
  Color(0xFF9E9E9E), // Gris medio
  Color(0xFF673AB7), // Púrpura
  Color(0xFF03A9F4), // Azul claro
  Color(0xFFE040FB), // Fucsia
  Color(0xFF76FF03), // Verde neón
  Color(0xFFFF6E40), // Naranja neón
  Color(0xFF40C4FF), // Celeste
  Color(0xFFB388FF), // Lavanda
  Color(0xFFFF80AB), // Rosado claro
  Color(0xFF80D8FF), // Azul bebé
];
```

- Agregar campo `ligatureColorName` para mapear el color hexadecimal a un nombre descriptivo
- `defaultValue` debe cambiar a `'gris'` → color `Colors.grey`

**En `DoctorConfigForm`:**
- Detectar el campo `ligatureColor` del perfil `metal_braces`
- Renderizar un `GridView` de círculos de colores en vez de chips
- Cada círculo tappable, con borde de selección

### 4.2 Brackets estéticos: Cambios en materiales y arco

**Materiales:**
- **QUITAR** `zafiro` de las opciones
- Agregar `metalico` a las opciones
- Opciones finales: `Cerámico` (value: `ceramico`), `Metálico` (value: `metalico`)
- `defaultValue` sigue siendo `ceramico`

**Arco (archwire):**
- **QUITAR** `Estético claro` (value: `estetico`)
- **QUITAR** `Metálico fino` (value: `metalico`)
- Agregar nuevas opciones: `Estándar` (value: `estandar`), `Reforzado` (value: `reforzado`)
- Opciones finales: `Estándar` (value: `estandar`), `Reforzado` (value: `reforzado`)
- `defaultValue`: `estandar`

### 4.3 Perfiles NUEVOS — configFields mínimos

Los perfiles nuevos (`reconstruccion`, `limpieza_oral`, `reemplazo_dental`, `implantes_dentales`, `bordes_incisales`, `gingivectomia`, `gingivoplastia`, `alineacion_margenes`) necesitan `configFields` y `defaultConfig`.

Cada uno debe tener al menos:
```dart
configFields: [
  TreatmentConfigField(
    key: 'arcada',
    label: 'Arcada',
    type: _chip,
    options: [
      TreatmentConfigOption(value: 'superior', label: 'Superior'),
      TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      TreatmentConfigOption(value: 'ambas', label: 'Ambas'),
    ],
    defaultValue: 'superior',
  ),
],
defaultConfig: {'arcada': 'superior'},
```

Además, según el tratamiento:
- **Reconstrucción:** agregar campo `diente` (dropdown: número del diente 1-32 o sectores)
- **Limpieza oral:** campo `intensidad` (leve, media, profunda)
- **Reemplazo de dientes:** campo `tipoProtesis` (corona, puente, prótesis parcial, prótesis total)
- **Implantes dentales:** campo `cantidad` (unitario, múltiple), `zona` (anterior, posterior)
- **Bordes dentales:** campo `ajuste` (conservador, moderado, significativo)
- **Gingivectomía/Gingivoplastia/Alineación:** campo `zona` (sector 1-4 o generalizada)

---

## BLOQUE 5 — Perfiles EXISTENTES que se mantienen (sin cambios)

- `clear_aligners` — Alineadores (se mantiene igual)
- `palatal_expander` — Expansor de paladar (se mantiene igual)
- `retainer` — Retenedor (se mantiene igual)
- `veneers` → renombrar ID a `carillas`, se mantienen configFields (se mueve al grupo Diseño de Sonrisa)
- `whitening` → renombrar ID a `blanqueamiento`, se mantienen configFields (se mueve al grupo Diseño de Sonrisa)
- `smile_design` — se ELIMINA como perfil independiente (ahora los sub-tratamientos de Diseño de Sonrisa cubren esto: carillas, blanqueamiento, bordes)

---

## BLOQUE 6 — Plan de implementación (orden)

### Paso 1: Agregar `TreatmentGroup` al modelo (`dental_treatment_profile.dart`)
- Crear clase `TreatmentGroup` con `id`, `label`, `icon`, `color`, `treatments`
- Definir `final List<TreatmentGroup> treatmentGroups = [...]` con los 7 grupos

### Paso 2: Agregar/Modificar perfiles (`dental_treatment_profile.dart`)
- Agregar 8 perfiles nuevos: `reconstruccion`, `limpieza_oral`, `reemplazo_dental`, `implantes_dentales`, `bordes_incisales`, `gingivectomia`, `gingivoplastia`, `alineacion_margenes`
- Modificar `metal_braces`: cambiar `ligatureColor` de chips a un campo especial `colorPicker`
- Modificar `esthetic_braces`: quitar zafiro de `material`, agregar metálico; quitar `Estético claro` y `Metálico fino` de `archwire`, agregar `Estándar` y `Reforzado`
- Renombrar `veneers` → `carillas`, `whitening` → `blanqueamiento`
- Eliminar `smile_design` (ahora cubierto por los sub-tratamientos de Diseño de Sonrisa)
- Mantener `clear_aligners`, `palatal_expander`, `retainer` sin cambios

### Paso 3: Reconstruir `TreatmentProfileSelector` (`treatment_profile_selector.dart`)
- Cambiar de dropdown plano a UI de grupos con cards
- Cada grupo expandible muestra sus sub-tratamientos como cards en grid
- Card seleccionada tiene borde de color + check
- Mantener compatibilidad con `compact` (móvil)

### Paso 4: Actualizar `DoctorConfigForm` (`doctor_config_form.dart`)
- Agregar soporte para el selector de color de ligas (grid de círculos de colores)
- Los campos normales (chips, dropdown) siguen funcionando igual

### Paso 5: Actualizar `simulator_screen.dart`
- Verificar que `defaultProfileIdFromTreatmentType` y `lookupProfile` sigan funcionando
- Actualizar mapeos si es necesario

### Paso 6: Actualizar tests
- Modificar `treatment_catalog_repository_test.dart` y `simulator_provider_test.dart` si referencian IDs de perfiles
- Agregar tests para los nuevos perfiles

---

## BLOQUE 7 — Prompt para el agente implementador

Copiar el texto debajo de esta línea como prompt para el agente que hará la implementación:
