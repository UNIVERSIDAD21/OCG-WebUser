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

// ── Profile registry ────────────────────────────────────

const _chip = TreatmentConfigFieldType.chips;
// ignore: unused_element
const _drop = TreatmentConfigFieldType.dropdown;

final List<DentalTreatmentProfile> treatmentProfiles = [
  const DentalTreatmentProfile(
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
          TreatmentConfigOption(value: 'gris', label: 'Gris'),
          TreatmentConfigOption(value: 'transparente', label: 'Transparente'),
          TreatmentConfigOption(value: 'azul', label: 'Azul'),
          TreatmentConfigOption(value: 'rojo', label: 'Rojo'),
          TreatmentConfigOption(value: 'morado', label: 'Morado'),
          TreatmentConfigOption(value: 'multicolor', label: 'Multicolor'),
        ],
        defaultValue: 'gris',
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
      'ligatureColor': 'gris',
      'archwire': 'visible',
      'arcada': 'superior',
    },
  ),
  const DentalTreatmentProfile(
    id: 'esthetic_braces',
    label: 'Brackets estéticos',
    description: 'Brackets cerámicos o zafiro, discretos',
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
          TreatmentConfigOption(value: 'zafiro', label: 'Zafiro'),
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
          TreatmentConfigOption(value: 'estetico', label: 'Estético claro'),
          TreatmentConfigOption(value: 'metalico', label: 'Metálico fino'),
        ],
        defaultValue: 'estetico',
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
      'archwire': 'estetico',
      'arcada': 'superior',
    },
  ),
  const DentalTreatmentProfile(
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
  ),
  const DentalTreatmentProfile(
    id: 'whitening',
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
  ),
  const DentalTreatmentProfile(
    id: 'veneers',
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
          TreatmentConfigOption(
            value: 'cuadrada-suave',
            label: 'Cuadrada suave',
          ),
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
  ),
  const DentalTreatmentProfile(
    id: 'smile_design',
    label: 'Diseño de sonrisa',
    description: 'Resultado final ideal sin aparatos visibles',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFF4A3527),
    defaultVisualGoal: 'final_result',
    configFields: [
      TreatmentConfigField(
        key: 'estilo',
        label: 'Estilo',
        type: _chip,
        options: [
          TreatmentConfigOption(value: 'natural', label: 'Natural'),
          TreatmentConfigOption(value: 'armonico', label: 'Armónico'),
          TreatmentConfigOption(value: 'cosmetico', label: 'Cosmético'),
        ],
        defaultValue: 'armonico',
      ),
      TreatmentConfigField(
        key: 'alineacionFinal',
        label: 'Alineación',
        type: _chip,
        options: [
          TreatmentConfigOption(value: 'leve', label: 'Leve'),
          TreatmentConfigOption(value: 'media', label: 'Media'),
          TreatmentConfigOption(value: 'idealizada', label: 'Idealizada'),
        ],
        defaultValue: 'media',
      ),
      TreatmentConfigField(
        key: 'tono',
        label: 'Tono dental',
        type: _chip,
        options: [
          TreatmentConfigOption(value: 'natural claro', label: 'Natural claro'),
          TreatmentConfigOption(
            value: 'blanco moderado',
            label: 'Blanco moderado',
          ),
        ],
        defaultValue: 'blanco moderado',
      ),
    ],
    defaultConfig: {
      'estilo': 'armonico',
      'alineacionFinal': 'media',
      'tono': 'blanco moderado',
    },
  ),
  const DentalTreatmentProfile(
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
  ),
  const DentalTreatmentProfile(
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
  try {
    return treatmentProfiles.firstWhere((p) => p.id == id);
  } catch (_) {
    return null;
  }
}
