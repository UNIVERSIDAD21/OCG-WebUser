import 'package:flutter/material.dart';

/// Mirrors backend `treatment_profiles.ts` IDs exactly.
class DentalTreatmentProfile {
  const DentalTreatmentProfile({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.defaultVisualGoal,
    required this.configFields,
    required this.defaultConfig,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String defaultVisualGoal;
  final List<TreatmentConfigField> configFields;
  final Map<String, dynamic> defaultConfig;

  Map<String, dynamic> buildDefaultConfig() =>
      Map<String, dynamic>.from(defaultConfig);
}

class TreatmentConfigField {
  const TreatmentConfigField({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.defaultValue,
  });

  final String key;
  final String label;
  final TreatmentConfigFieldType type;
  final List<TreatmentConfigOption> options;
  final dynamic defaultValue;
}

enum TreatmentConfigFieldType { dropdown, chips }

class TreatmentConfigOption {
  const TreatmentConfigOption({required this.value, required this.label});
  final String value;
  final String label;
}

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

// Profile registry

const _chip = TreatmentConfigFieldType.chips;
// ignore: unused_element
const _drop = TreatmentConfigFieldType.dropdown;

const DentalTreatmentProfile reconstruccionProfile = DentalTreatmentProfile(
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
);

const DentalTreatmentProfile limpiezaOralProfile = DentalTreatmentProfile(
  id: 'limpieza_oral',
  label: 'Limpieza',
  description:
      'Simulación del resultado después de una limpieza oral profesional',
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
);

const DentalTreatmentProfile reemplazoDentalProfile = DentalTreatmentProfile(
  id: 'reemplazo_dental',
  label: 'Reemplazo de dientes',
  description:
      'Sustituir uno o varios dientes perdidos con prótesis, puentes o coronas',
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
        TreatmentConfigOption(
          value: 'protesis_parcial',
          label: 'Prótesis parcial',
        ),
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
);

const DentalTreatmentProfile implantesDentalesProfile = DentalTreatmentProfile(
  id: 'implantes_dentales',
  label: 'Implantes dentales',
  description:
      'Colocación de raíz artificial en el hueso con corona que simula el diente',
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
  defaultConfig: {
    'cantidad': 'unitario',
    'zona': 'anterior',
    'arcada': 'superior',
  },
);

const DentalTreatmentProfile bordesIncisalesProfile = DentalTreatmentProfile(
  id: 'bordes_incisales',
  label: 'Bordes dentales',
  description:
      'Mejora de forma y tamaño de dientes delanteros desgastados, fracturados o desiguales',
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
);

const DentalTreatmentProfile gingivectomiaProfile = DentalTreatmentProfile(
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
);

const DentalTreatmentProfile gingivoplastiaProfile = DentalTreatmentProfile(
  id: 'gingivoplastia',
  label: 'Gingivoplastia',
  description:
      'Remodelación estética de la encía para darle mejor forma y contorno',
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
);

const DentalTreatmentProfile alineacionMargenesProfile = DentalTreatmentProfile(
  id: 'alineacion_margenes',
  label: 'Alineación de márgenes',
  description:
      'Corrección del contorno gingival para niveles de encía más simétricos',
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
);

const DentalTreatmentProfile metalBracesProfile = DentalTreatmentProfile(
  id: 'metal_braces',
  label: 'Brackets metálicos',
  description: 'Brackets metálicos visibles con arco y ligas',
  icon: Icons.engineering_outlined,
  color: Color(0xFF607D8B),
  defaultVisualGoal: 'show_appliance',
  configFields: [
    TreatmentConfigField(
      key: 'ligatureColor',
      label: 'Color de ligas',
      type: _chip,
      options: [
        TreatmentConfigOption(value: '#9E9E9E', label: 'Gris'),
        TreatmentConfigOption(value: 'transparente', label: 'Transparente'),
        TreatmentConfigOption(value: '#2196F3', label: 'Azul'),
        TreatmentConfigOption(value: '#F44336', label: 'Rojo'),
        TreatmentConfigOption(value: '#673AB7', label: 'Morado'),
        TreatmentConfigOption(value: '#FF9800', label: 'Naranja'),
        TreatmentConfigOption(value: '#FFEB3B', label: 'Amarillo'),
        TreatmentConfigOption(value: '#4CAF50', label: 'Verde'),
        TreatmentConfigOption(value: '#00BCD4', label: 'Cyan'),
        TreatmentConfigOption(value: '#E91E63', label: 'Rosa'),
        TreatmentConfigOption(value: '#0D47A1', label: 'Azul oscuro'),
        TreatmentConfigOption(value: '#009688', label: 'Teal'),
        TreatmentConfigOption(value: '#795548', label: 'Café'),
        TreatmentConfigOption(value: '#607D8B', label: 'Azul grisáceo'),
        TreatmentConfigOption(value: '#FFFFFF', label: 'Blanco'),
        TreatmentConfigOption(value: '#000000', label: 'Negro'),
        TreatmentConfigOption(value: '#8BC34A', label: 'Verde claro'),
        TreatmentConfigOption(value: '#FFC107', label: 'Ámbar'),
        TreatmentConfigOption(value: '#CDDC39', label: 'Lima'),
        TreatmentConfigOption(value: '#E65100', label: 'Naranja oscuro'),
        TreatmentConfigOption(value: '#757575', label: 'Gris medio'),
        TreatmentConfigOption(value: '#9C27B0', label: 'Púrpura'),
        TreatmentConfigOption(value: '#03A9F4', label: 'Azul claro'),
        TreatmentConfigOption(value: '#D500F9', label: 'Fucsia'),
        TreatmentConfigOption(value: '#39FF14', label: 'Verde neón'),
        TreatmentConfigOption(value: '#FF5F1F', label: 'Naranja neón'),
        TreatmentConfigOption(value: '#81D4FA', label: 'Celeste'),
        TreatmentConfigOption(value: '#B39DDB', label: 'Lavanda'),
        TreatmentConfigOption(value: '#F8BBD0', label: 'Rosado claro'),
        TreatmentConfigOption(value: '#BBDEFB', label: 'Azul bebé'),
      ],
      defaultValue: '#9E9E9E',
    ),
    TreatmentConfigField(
      key: 'archwire',
      label: 'Arco',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'visible', label: 'Visible'),
        TreatmentConfigOption(value: 'fino', label: 'Fino'),
      ],
      defaultValue: 'visible',
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
  defaultConfig: {
    'ligatureColor': '#9E9E9E',
    'archwire': 'visible',
    'arcada': 'superior',
  },
);

const DentalTreatmentProfile estheticBracesProfile = DentalTreatmentProfile(
  id: 'esthetic_braces',
  label: 'Brackets estéticos',
  description: 'Brackets cerámicos o metálicos, discretos',
  icon: Icons.diamond_outlined,
  color: Color(0xFFB0BEC5),
  defaultVisualGoal: 'show_appliance',
  configFields: [
    TreatmentConfigField(
      key: 'material',
      label: 'Material',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'ceramico', label: 'Cerámico'),
        TreatmentConfigOption(value: 'metalico', label: 'Metálico'),
      ],
      defaultValue: 'ceramico',
    ),
    TreatmentConfigField(
      key: 'ligatureColor',
      label: 'Color de ligas',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'transparente', label: 'Transparente'),
        TreatmentConfigOption(value: 'perladas', label: 'Perladas'),
        TreatmentConfigOption(value: 'blancas', label: 'Blancas'),
      ],
      defaultValue: 'transparente',
    ),
    TreatmentConfigField(
      key: 'archwire',
      label: 'Arco',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'estandar', label: 'Estándar'),
        TreatmentConfigOption(value: 'reforzado', label: 'Reforzado'),
      ],
      defaultValue: 'estandar',
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
  defaultConfig: {
    'material': 'ceramico',
    'ligatureColor': 'transparente',
    'archwire': 'estandar',
    'arcada': 'superior',
  },
);

const DentalTreatmentProfile clearAlignersProfile = DentalTreatmentProfile(
  id: 'clear_aligners',
  label: 'Alineadores',
  description: 'Cubetas transparentes tipo Invisalign',
  icon: Icons.remove_red_eye_outlined,
  color: Color(0xFF4DB6AC),
  defaultVisualGoal: 'show_appliance',
  configFields: [
    TreatmentConfigField(
      key: 'attachments',
      label: 'Attachments',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'ninguno', label: 'Ninguno'),
        TreatmentConfigOption(value: 'pocos', label: 'Pocos'),
        TreatmentConfigOption(value: 'varios', label: 'Varios'),
      ],
      defaultValue: 'pocos',
    ),
    TreatmentConfigField(
      key: 'transparency',
      label: 'Transparencia',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'sutil', label: 'Sutil'),
        TreatmentConfigOption(value: 'medio', label: 'Media'),
      ],
      defaultValue: 'medio',
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
  defaultConfig: {
    'attachments': 'pocos',
    'transparency': 'medio',
    'arcada': 'superior',
  },
);

const DentalTreatmentProfile blanqueamientoProfile = DentalTreatmentProfile(
  id: 'blanqueamiento',
  label: 'Blanqueamiento',
  description: 'Cambio de tono dental, sin alterar forma',
  icon: Icons.wb_sunny_outlined,
  color: Color(0xFFFFB74D),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'toneTarget',
      label: 'Intensidad',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'leve', label: 'Leve'),
        TreatmentConfigOption(value: 'medio', label: 'Media'),
        TreatmentConfigOption(value: 'alto', label: 'Alta'),
      ],
      defaultValue: 'medio',
    ),
    TreatmentConfigField(
      key: 'naturalness',
      label: 'Naturalidad',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'natural', label: 'Natural'),
        TreatmentConfigOption(
          value: 'brillante',
          label: 'Brillante controlado',
        ),
      ],
      defaultValue: 'natural',
    ),
  ],
  defaultConfig: {'toneTarget': 'medio', 'naturalness': 'natural'},
);

const DentalTreatmentProfile carillasProfile = DentalTreatmentProfile(
  id: 'carillas',
  label: 'Carillas / Vinillas',
  description: 'Forma, proporción y tono de dientes anteriores',
  icon: Icons.auto_fix_high_outlined,
  color: Color(0xFFE0C097),
  defaultVisualGoal: 'aesthetic_improvement',
  configFields: [
    TreatmentConfigField(
      key: 'materialVisual',
      label: 'Material',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'resina', label: 'Resina'),
        TreatmentConfigOption(value: 'ceramica', label: 'Cerámica'),
      ],
      defaultValue: 'ceramica',
    ),
    TreatmentConfigField(
      key: 'forma',
      label: 'Forma',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'natural', label: 'Natural'),
        TreatmentConfigOption(value: 'ovalada', label: 'Ovalada'),
        TreatmentConfigOption(value: 'cuadrada-suave', label: 'Cuadrada suave'),
      ],
      defaultValue: 'natural',
    ),
    TreatmentConfigField(
      key: 'tono',
      label: 'Tono',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'natural claro', label: 'Natural claro'),
        TreatmentConfigOption(value: 'blanco calido', label: 'Blanco cálido'),
        TreatmentConfigOption(value: 'blanco alto', label: 'Blanco alto'),
      ],
      defaultValue: 'blanco calido',
    ),
    TreatmentConfigField(
      key: 'longitudIncisal',
      label: 'Borde incisal',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'conservar', label: 'Conservar'),
        TreatmentConfigOption(value: 'alargar leve', label: 'Alargar leve'),
        TreatmentConfigOption(value: 'alargar medio', label: 'Alargar medio'),
      ],
      defaultValue: 'conservar',
    ),
  ],
  defaultConfig: {
    'materialVisual': 'ceramica',
    'forma': 'natural',
    'tono': 'blanco calido',
    'longitudIncisal': 'conservar',
  },
);

const DentalTreatmentProfile palatalExpanderProfile = DentalTreatmentProfile(
  id: 'palatal_expander',
  label: 'Expansor de paladar',
  description: 'Expansor Hyrax/Haas en arcada superior',
  icon: Icons.architecture_outlined,
  color: Color(0xFF795548),
  defaultVisualGoal: 'show_appliance',
  configFields: [
    TreatmentConfigField(
      key: 'tipoVisual',
      label: 'Tipo',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'Hyrax', label: 'Hyrax'),
        TreatmentConfigOption(value: 'Haas', label: 'Haas'),
        TreatmentConfigOption(value: 'removible', label: 'Removible'),
      ],
      defaultValue: 'Hyrax',
    ),
  ],
  defaultConfig: {'tipoVisual': 'Hyrax'},
);

const DentalTreatmentProfile retainerProfile = DentalTreatmentProfile(
  id: 'retainer',
  label: 'Retenedor',
  description: 'Retenedor post-tratamiento Essix/Hawley/fijo',
  icon: Icons.lock_outline,
  color: Color(0xFF26A69A),
  defaultVisualGoal: 'show_appliance',
  configFields: [
    TreatmentConfigField(
      key: 'tipo',
      label: 'Tipo de retenedor',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'Essix', label: 'Essix'),
        TreatmentConfigOption(value: 'Hawley', label: 'Hawley'),
        TreatmentConfigOption(value: 'fijo lingual', label: 'Fijo lingual'),
      ],
      defaultValue: 'Essix',
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
    TreatmentConfigField(
      key: 'visibilidad',
      label: 'Visibilidad',
      type: _chip,
      options: [
        TreatmentConfigOption(value: 'sutil', label: 'Sutil'),
        TreatmentConfigOption(value: 'media', label: 'Media'),
        TreatmentConfigOption(value: 'alta', label: 'Alta'),
      ],
      defaultValue: 'media',
    ),
  ],
  defaultConfig: {
    'tipo': 'Essix',
    'arcada': 'superior',
    'visibilidad': 'media',
  },
);

final List<DentalTreatmentProfile> treatmentProfiles = const [
  reconstruccionProfile,
  limpiezaOralProfile,
  reemplazoDentalProfile,
  implantesDentalesProfile,
  bordesIncisalesProfile,
  gingivectomiaProfile,
  gingivoplastiaProfile,
  alineacionMargenesProfile,
  metalBracesProfile,
  estheticBracesProfile,
  clearAlignersProfile,
  blanqueamientoProfile,
  carillasProfile,
  palatalExpanderProfile,
  retainerProfile,
];

final List<TreatmentGroup> treatmentGroups = const [
  TreatmentGroup(
    id: 'operatoria',
    label: 'Operatorio',
    icon: Icons.handyman_outlined,
    color: Color(0xFF8D6E63),
    treatments: [reconstruccionProfile],
  ),
  TreatmentGroup(
    id: 'higiene_oral',
    label: 'Higiene Oral',
    icon: Icons.health_and_safety_outlined,
    color: Color(0xFF66BB6A),
    treatments: [limpiezaOralProfile],
  ),
  TreatmentGroup(
    id: 'rehabilitacion',
    label: 'Rehabilitación',
    icon: Icons.engineering_outlined,
    color: Color(0xFFFF7043),
    treatments: [reemplazoDentalProfile, implantesDentalesProfile],
  ),
  TreatmentGroup(
    id: 'diseno_sonrisa',
    label: 'Diseño de Sonrisa',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFFE0C097),
    treatments: [
      carillasProfile,
      blanqueamientoProfile,
      bordesIncisalesProfile,
    ],
  ),
  TreatmentGroup(
    id: 'periodoncia',
    label: 'Acciones de Periodoncia',
    icon: Icons.spa_outlined,
    color: Color(0xFFEF5350),
    treatments: [
      gingivectomiaProfile,
      gingivoplastiaProfile,
      alineacionMargenesProfile,
    ],
  ),
  TreatmentGroup(
    id: 'ortodoncia',
    label: 'Ortodoncia',
    icon: Icons.straighten_outlined,
    color: Color(0xFF607D8B),
    treatments: [
      metalBracesProfile,
      estheticBracesProfile,
      clearAlignersProfile,
    ],
  ),
  TreatmentGroup(
    id: 'ortopedia',
    label: 'Ortopedia',
    icon: Icons.accessibility_new_outlined,
    color: Color(0xFF795548),
    treatments: [palatalExpanderProfile, retainerProfile],
  ),
];

/// Resolves default profile from legacy TreatmentType name.
String? defaultProfileIdFromTreatmentType(String? treatmentType) {
  if (treatmentType == null || treatmentType.isEmpty) return null;
  const map = <String, String>{
    'convencional': 'metal_braces',
    'estetico': 'esthetic_braces',
    'autoligado': 'metal_braces',
    'alineadores': 'clear_aligners',
    'ortopedia': 'palatal_expander',
    'retenedores': 'retainer',
  };
  return map[treatmentType.toLowerCase().trim()];
}

DentalTreatmentProfile? lookupProfile(String id) {
  const aliases = <String, String>{
    'whitening': 'blanqueamiento',
    'veneers': 'carillas',
  };
  final normalizedId = aliases[id] ?? id;
  try {
    return treatmentProfiles.firstWhere((p) => p.id == normalizedId);
  } catch (_) {
    return null;
  }
}
