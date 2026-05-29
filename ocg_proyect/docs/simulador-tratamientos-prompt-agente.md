# Prompt para el Agente — Simulador: Paso 1 — Reestructuración de Tratamientos

## Contexto del proyecto

Trabajas en el proyecto **OCG-WebUser** (Flutter + Firebase), ubicado en `/home/borlty/OCG-WebUser/ocg_proyect`. El módulo del Simulador permite al doctor generar imágenes con IA que simulan el resultado de tratamientos dentales.

El Paso 1 del Simulador es "Elegir tratamiento", donde el doctor selecciona qué tratamiento quiere simular.

## Lo que debes hacer

Reestructurar completamente el Paso 1 del Simulador para organizar los tratamientos por **grupos dentales** con una **UI de cards visualmente atractiva**, agregar 8 nuevos tratamientos, y modificar configuraciones específicas.

---

## TAREA 1 — Agregar clase `TreatmentGroup` y la lista de grupos

**Archivo:** `lib/features/simulator/domain/dental_treatment_profile.dart`

Agrega al final del archivo (antes de `treatmentProfiles`):

```dart
class TreatmentGroup {
  const TreatmentGroup({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.treatments,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<DentalTreatmentProfile> treatments;
}
```

Luego define `final List<TreatmentGroup> treatmentGroups = [...]` con los 7 grupos. Cada grupo contiene los `DentalTreatmentProfile` correspondientes como se detalla en la TAREA 2.

---

## TAREA 2 — Modificar y agregar perfiles de tratamiento

Debes modificar el registro `treatmentProfiles` en `dental_treatment_profile.dart`:

### 2A — PERFILES NUEVOS (agregar al inicio del registro)

Cada perfil nuevo debe tener `defaultVisualGoal: 'aesthetic_improvement'` y al menos un campo `arcada`.

**1. Reconstrucción** (`reconstruccion`)
```dart
const DentalTreatmentProfile(
  id: 'reconstruccion',
  label: 'Reconstrucción',
  description: 'Reconstruir un diente dañado o con caries extensa',
  icon: Icons.build_outlined,
  color: Color(0xFF8D6E63),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'diente',
      label: 'Diente',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'anterior', label: 'Anterior'),
        TreatmentConfigOption(value: 'posterior', label: 'Posterior'),
        TreatmentConfigOption(value: 'individual', label: 'Individual'),
      ],
      defaultValue: 'anterior',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      ],
      defaultValue: 'superior',
    ),
  ],
  defaultConfig: {'diente': 'anterior', 'arcada': 'superior'},
)
```

**2. Limpieza Oral** (`limpieza_oral`)
```dart
const DentalTreatmentProfile(
  id: 'limpieza_oral',
  label: 'Limpieza',
  description: 'Simulación del resultado después de una limpieza oral profesional',
  icon: Icons.clean_hands_outlined,
  color: Color(0xFF66BB6A),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'intensidad',
      label: 'Intensidad',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'leve', label: 'Leve'),
        TreatmentConfigOption(value: 'media', label: 'Media'),
        TreatmentConfigOption(value: 'profunda', label: 'Profunda'),
      ],
      defaultValue: 'media',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
        TreatmentConfigOption(value: 'ambas', label: 'Ambas'),
      ],
      defaultValue: 'ambas',
    ),
  ],
  defaultConfig: {'intensidad': 'media', 'arcada': 'ambas'},
)
```

**3. Reemplazo de dientes** (`reemplazo_dental`)
```dart
const DentalTreatmentProfile(
  id: 'reemplazo_dental',
  label: 'Reemplazo de dientes',
  description: 'Sustituir uno o varios dientes perdidos con prótesis, puentes o coronas',
  icon: Icons.account_tree_outlined,
  color: Color(0xFFFF7043),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'tipoProtesis',
      label: 'Tipo',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'corona', label: 'Corona'),
        TreatmentConfigOption(value: 'puente', label: 'Puente'),
        TreatmentConfigOption(value: 'protesis_parcial', label: 'Prótesis parcial'),
        TreatmentConfigOption(value: 'protesis_total', label: 'Prótesis total'),
      ],
      defaultValue: 'corona',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      ],
      defaultValue: 'superior',
    ),
  ],
  defaultConfig: {'tipoProtesis': 'corona', 'arcada': 'superior'},
)
```

**4. Implantes dentales** (`implantes_dentales`)
```dart
const DentalTreatmentProfile(
  id: 'implantes_dentales',
  label: 'Implantes dentales',
  description: 'Colocación de raíz artificial en el hueso con corona que simula el diente',
  icon: Icons.medication_outlined,
  color: Color(0xFF5C6BC0),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'cantidad',
      label: 'Cantidad',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'unitario', label: 'Unitario'),
        TreatmentConfigOption(value: 'multiple', label: 'Múltiple'),
      ],
      defaultValue: 'unitario',
    ),
    TreatmentConfigField(
      key: 'zona',
      label: 'Zona',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'anterior', label: 'Anterior'),
        TreatmentConfigOption(value: 'posterior', label: 'Posterior'),
      ],
      defaultValue: 'anterior',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      ],
      defaultValue: 'superior',
    ),
  ],
  defaultConfig: {'cantidad': 'unitario', 'zona': 'anterior', 'arcada': 'superior'},
)
```

**5. Bordes dentales** (`bordes_incisales`)
```dart
const DentalTreatmentProfile(
  id: 'bordes_incisales',
  label: 'Bordes dentales',
  description: 'Mejora de forma y tamaño de dientes delanteros desgastados, fracturados o desiguales',
  icon: Icons.format_shapes_outlined,
  color: Color(0xFFFFCC80),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'ajuste',
      label: 'Ajuste',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'conservador', label: 'Conservador'),
        TreatmentConfigOption(value: 'moderado', label: 'Moderado'),
        TreatmentConfigOption(value: 'significativo', label: 'Significativo'),
      ],
      defaultValue: 'moderado',
    ),
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
  defaultConfig: {'ajuste': 'moderado', 'arcada': 'superior'},
)
```

**6. Gingivectomía** (`gingivectomia`)
```dart
const DentalTreatmentProfile(
  id: 'gingivectomia',
  label: 'Gingivectomía',
  description: 'Recorte de encía para eliminar exceso de tejido gingival',
  icon: Icons.content_cut_outlined,
  color: Color(0xFFEF5350),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'zona',
      label: 'Zona',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'sector1', label: 'Sector 1'),
        TreatmentConfigOption(value: 'sector2', label: 'Sector 2'),
        TreatmentConfigOption(value: 'sector3', label: 'Sector 3'),
        TreatmentConfigOption(value: 'sector4', label: 'Sector 4'),
        TreatmentConfigOption(value: 'generalizada', label: 'Generalizada'),
      ],
      defaultValue: 'sector1',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      ],
      defaultValue: 'superior',
    ),
  ],
  defaultConfig: {'zona': 'sector1', 'arcada': 'superior'},
)
```

**7. Gingivoplastia** (`gingivoplastia`)
```dart
const DentalTreatmentProfile(
  id: 'gingivoplastia',
  label: 'Gingivoplastia',
  description: 'Remodelación estética de la encía para darle mejor forma y contorno',
  icon: Icons.auto_fix_normal_outlined,
  color: Color(0xFFEC407A),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'zona',
      label: 'Zona',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'sector1', label: 'Sector 1'),
        TreatmentConfigOption(value: 'sector2', label: 'Sector 2'),
        TreatmentConfigOption(value: 'sector3', label: 'Sector 3'),
        TreatmentConfigOption(value: 'sector4', label: 'Sector 4'),
        TreatmentConfigOption(value: 'generalizada', label: 'Generalizada'),
      ],
      defaultValue: 'sector1',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      ],
      defaultValue: 'superior',
    ),
  ],
  defaultConfig: {'zona': 'sector1', 'arcada': 'superior'},
)
```

**8. Alineación de márgenes** (`alineacion_margenes`)
```dart
const DentalTreatmentProfile(
  id: 'alineacion_margenes',
  label: 'Alineación de márgenes',
  description: 'Corrección del contorno gingival para niveles de encía más simétricos',
  icon: Icons.align_horizontal_center_outlined,
  color: Color(0xFFAB47BC),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'zona',
      label: 'Zona',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'sector1', label: 'Sector 1'),
        TreatmentConfigOption(value: 'sector2', label: 'Sector 2'),
        TreatmentConfigOption(value: 'sector3', label: 'Sector 3'),
        TreatmentConfigOption(value: 'sector4', label: 'Sector 4'),
        TreatmentConfigOption(value: 'generalizada', label: 'Generalizada'),
      ],
      defaultValue: 'sector1',
    ),
    TreatmentConfigField(
      key: 'arcada',
      label: 'Arcada',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'superior', label: 'Superior'),
        TreatmentConfigOption(value: 'inferior', label: 'Inferior'),
      ],
      defaultValue: 'superior',
    ),
  ],
  defaultConfig: {'zona': 'sector1', 'arcada': 'superior'},
)
```

### 2B — MODIFICAR perfiles existentes

**Brackets metálicos (`metal_braces`):**
- Reemplazar el campo `ligatureColor` (tipo chips con 6 opciones) por un campo especial de **selector de color**. Agregar un nuevo tipo de campo o usar un approach con lista de colores predefinidos.
- En el `DoctorConfigForm`, cuando detecte `metal_braces` + campo `ligatureColor`, renderizar una grilla de círculos de colores en vez de chips.
- Colores disponibles: Gris, Transparente, Azul, Rojo, Morado, Naranja, Amarillo, Verde, Cyan, Rosa, Azul oscuro, Teal, Café, Azul grisáceo, Blanco, Negro, Verde claro, Ámbar, Lima, Naranja oscuro, Gris medio, Púrpura, Azul claro, Fucsia, Verde neón, Naranja neón, Celeste, Lavanda, Rosado claro, Azul bebé.

**Brackets estéticos (`esthetic_braces`):**
- Campo `material`: quitar opción `zafiro`, agregar `metalico` (value: `metalico`, label: `Metálico`). Quedan: `Cerámico`, `Metálico`. Default: `ceramico`.
- Campo `archwire`: quitar `Estético claro` (value: `estetico`) y `Metálico fino` (value: `metalico`). Agregar `Estándar` (value: `estandar`, label: `Estándar`) y `Reforzado` (value: `reforzado`, label: `Reforzado`). Default: `estandar`.

**Renombrar IDs:**
- `veneers` → `carillas`
- `whitening` → `blanqueamiento`

**Eliminar:**
- `smile_design` (Diseño de sonrisa como perfil independiente — ahora cubierto por carillas, blanqueamiento, bordes)

### 2C — Definir `treatmentGroups`

Después de definir/actualizar todos los perfiles, agregar:

```dart
final List<TreatmentGroup> treatmentGroups = [
  const TreatmentGroup(
    id: 'operatoria',
    label: 'Operatorio',
    icon: Icons.handyman_outlined,
    color: Color(0xFF8D6E63),
    treatments: [/* perfil reconstruccion */],
  ),
  const TreatmentGroup(
    id: 'higiene_oral',
    label: 'Higiene Oral',
    icon: Icons.health_and_safety_outlined,
    color: Color(0xFF66BB6A),
    treatments: [/* perfil limpieza_oral */],
  ),
  const TreatmentGroup(
    id: 'rehabilitacion',
    label: 'Rehabilitación',
    icon: Icons.engineering_outlined,
    color: Color(0xFFFF7043),
    treatments: [/* perfiles reemplazo_dental, implantes_dentales */],
  ),
  const TreatmentGroup(
    id: 'diseno_sonrisa',
    label: 'Diseño de Sonrisa',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFFE0C097),
    treatments: [/* perfiles carillas, blanqueamiento, bordes_incisales */],
  ),
  const TreatmentGroup(
    id: 'periodoncia',
    label: 'Acciones de Periodoncia',
    icon: Icons.spa_outlined,
    color: Color(0xFFEF5350),
    treatments: [/* perfiles gingivectomia, gingivoplastia, alineacion_margenes */],
  ),
  const TreatmentGroup(
    id: 'ortodoncia',
    label: 'Ortodoncia',
    icon: Icons.straighten_outlined,
    color: Color(0xFF607D8B),
    treatments: [/* perfiles metal_braces, esthetic_braces, clear_aligners */],
  ),
  const TreatmentGroup(
    id: 'ortopedia',
    label: 'Ortopedia',
    icon: Icons.accessibility_new_outlined,
    color: Color(0xFF795548),
    treatments: [/* perfiles palatal_expander, retainer */],
  ),
];
```

NOTA: Debes referenciar los perfiles por su variable dentro del mismo `treatmentProfiles`. Como `treatmentProfiles` es una `const` list, puedes crear cada grupo con los perfiles ya definidos. Asegúrate de que `treatmentGroups` se defina DESPUÉS de `treatmentProfiles`.

---

## TAREA 3 — Reconstruir `TreatmentProfileSelector`

**Archivo:** `lib/features/simulator/presentation/widgets/treatment_profile_selector.dart`

**Reemplazar completamente el widget actual** por uno nuevo que:

1. En vez de un `MenuAnchor` dropdown, renderiza una **lista vertical de grupos expandibles**
2. Cada grupo usa `ExpansionTile` o un `AnimatedContainer` con expand/colapsar manual
3. El header de cada grupo muestra: `[ícono] [nombre del grupo] [badge: X tratamientos]`
4. Al expandir, muestra una **grilla de cards** (2 columnas con `GridView` o `Wrap`)
5. Cada card es un `GestureDetector` que al hacer tap selecciona ese tratamiento
6. La card seleccionada tiene: borde de 2px del color del perfil, fondo tintado, icono check en esquina

### Estructura de cada card:
```dart
Container(
  decoration: BoxDecoration(
    color: isSelected ? profile.color.withOpacity(0.08) : OcgColors.ivory,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: isSelected ? profile.color.withOpacity(0.4) : OcgColors.bronze.withOpacity(0.12),
      width: isSelected ? 2 : 1,
    ),
  ),
  // Icono del tratamiento (grande, centrado)
  // Nombre del tratamiento (bold, 13px)
  // Descripción (11px, 2 líneas max, ink)
  // Badge "Seleccionado" si está activo
)
```

### Comportamiento:
- Solo UN grupo puede estar expandido a la vez (acordeón)
- Al seleccionar un tratamiento, llamar `widget.onSelected(profile.id)`
- Mantener el parámetro `compact` para ajustar a móvil (1 columna en vez de 2)

---

## TAREA 4 — Actualizar `DoctorConfigForm` para el selector de color

**Archivo:** `lib/features/simulator/presentation/widgets/doctor_config_form.dart`

Agregar soporte para el campo `ligatureColor` del perfil `metal_braces`:

- Detectar si el campo actual es `ligatureColor` y el perfil es `metal_braces`
- En ese caso, renderizar un `Wrap` o `GridView` con **círculos de color** (30 colores predefinidos)
- Cada círculo es tappable, 36x36px, con `BoxShape.circle`
- El color seleccionado muestra un borde blanco + icono check centrado
- Los colores son los listados en la TAREA 2B

```dart
// Ejemplo de widget para el selector de color:
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: ligatureColors.map((color) {
    final isSelected = currentValue == colorToHex(color);
    return GestureDetector(
      onTap: () => onColorSelected(colorToHex(color)),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(...)] : null,
        ),
        child: isSelected ? Icon(Icons.check, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, size: 16) : null,
      ),
    );
  }).toList(),
)
```

- Colores especiales: el color "Transparente" se representa con un círculo de borde punteado y fondo con patrón de ajedrez (sugerencia visual de transparencia)
- Almacenar el valor como string hexadecimal: ej `'#2196F3'` o `'transparente'`

---

## TAREA 5 — Actualizar referencias

**Archivo:** `lib/features/simulator/presentation/simulator_screen.dart`

- Verificar que `defaultProfileIdFromTreatmentType` siga funcionando con los IDs renombrados (`carillas`, `blanqueamiento`)
- Si algún componente externo referencia `smile_design`, actualizarlo o eliminarlo

**Eliminar `smile_design`** de cualquier mapeo o referencia en tests, providers, etc.

---

## TAREA 6 — No romper nada existente

- `lookupProfile(String id)` debe seguir funcionando con todos los IDs (nuevos y renombrados)
- `defaultProfileIdFromTreatmentType(String?)` debe mapear correctamente los `TreatmentType` legacy a los nuevos IDs
- `DoctorConfigForm` debe seguir renderizando correctamente todos los campos tipo chips/dropdown para los perfiles no modificados
- La compatibilidad con `compact` en `TreatmentProfileSelector` debe mantenerse

---

## RESUMEN DE ARCHIVOS A TOCAR

| Archivo | Acción |
|---|---|
| `dental_treatment_profile.dart` | Agregar `TreatmentGroup`, 8 perfiles nuevos, modificar 2 existentes, renombrar 2, eliminar 1, definir `treatmentGroups` |
| `treatment_profile_selector.dart` | Reconstruir completamente: de dropdown a UI de grupos con cards |
| `doctor_config_form.dart` | Agregar renderizado de selector de color para ligas de brackets metálicos |
| `simulator_screen.dart` | Verificar compatibilidad (posiblemente sin cambios) |

## RESULTADO ESPERADO

Al abrir el Simulador Paso 1, el doctor ve:
1. Una lista de 7 grupos expandibles (Operatorio, Higiene Oral, Rehabilitación, Diseño de Sonrisa, Acciones de Periodoncia, Ortodoncia, Ortopedia)
2. Al expandir un grupo, ve cards visuales con ícono, nombre y descripción de cada sub-tratamiento
3. Al tocar una card, queda seleccionada con borde de color y check
4. En Paso 2, los campos de configuración aparecen según el perfil (incluyendo el selector de color para brackets metálicos)
