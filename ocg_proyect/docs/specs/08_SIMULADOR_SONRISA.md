# 08 — Simulador de Sonrisa [CORREGIDO v2.0]

## ⚠️ VERSIÓN CORREGIDA — Corrección BD-05 aplicada

**SmileSimulationModel** ahora registra cuándo se compartió la simulación. Esto permite auditoría y métricas de uso.

---

## Lo que debes entregar al terminar este bloque

- [ ] CameraCaptureScreen con overlay guía de posicionamiento del rostro
- [ ] Generación de máscara PNG con ML Kit (mask_generator.dart)
- [ ] Cloud Function processSmileSimulation que llama a OpenAI
- [ ] SimulatorProcessingScreen con animación atractiva
- [ ] SimulatorResultScreen con BeforeAfterSlider interactivo
- [ ] SimulationHistoryScreen con el historial del paciente
- [ ] Disclaimer clínico visible e inamovible
- [ ] Funcionalidad de compartir por WhatsApp (con auditoría BD-05)

---

## SmileSimulationModel [BD-05 CORREGIDO]

```dart
class SmileSimulationModel {
  final String id;
  final String patientId;
  final String originalFrenteUrl;    // Foto original frente en Storage
  final String? originalPerfilUrl;   // Foto perfil — opcional, v2.0
  final String simuladoFrenteUrl;    // Resultado IA frente
  final String? simuladoPerfilUrl;   // Resultado IA perfil — v2.0
  final String tipoTratamiento;      // 'braces_removal' | 'aligners' | 'whitening'
  final String promptUsado;          // Prompt enviado a OpenAI — para auditoría
  final String creadoPor;            // adminId o patientId
  final String? notasDoctora;        // Observaciones clínicas opcionales
  
  // ⚠️ CAMBIO BD-05: Campos de auditoría
  final bool compartida;             // ¿Se compartió por WhatsApp?
  final DateTime? fechaCompartida;   // Cuándo se compartió
  
  final DateTime createdAt;
}
```

---

## SimulatorResultScreen — Marcar como compartida [BD-05]

Cuando el usuario toca "Compartir por WhatsApp", actualizar el documento ANTES de abrir WhatsApp:

```dart
// En SimulatorResultScreen
Future<void> _shareByWhatsApp(String simulationId) async {
  try {
    // 1. Marcar como compartida en Firestore (BD-05)
    await _db
        .collection('simulations')
        .doc(simulationId)
        .update({
          'compartida': true,
          'fechaCompartida': FieldValue.serverTimestamp(),
        });

    // 2. Generar mensaje con URL de la imagen
    final message = '''
Me acabo de hacer una simulación de sonrisa en OCG Clínica 😁

Original → Simulado ✨

Revisa cómo se vería mi sonrisa después del tratamiento. 
¿No es increíble? Quiero agendar mi consulta ahora.
    '''.trim();

    // 3. Abrir WhatsApp
    final doctorPhone = '573001234567'; // Número de la doctora
    final whatsappUrl = 'https://wa.me/$doctorPhone?text=${Uri.encodeFull(message)}';
    
    if (await canLaunch(whatsappUrl)) {
      await launch(whatsappUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp no está instalado')),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al compartir: $e')),
    );
  }
}
```

---

## Auditoría de compartición [BD-05]

En el SimulationHistoryScreen o admin dashboard, mostrar:
- Fecha de creación de la simulación
- Si fue compartida (ícono de WhatsApp)
- Cuándo se compartió exactamente

```dart
// En SimulationCard del historial
if (simulation.compartida) {
  Row(
    children: [
      Icon(Icons.check_circle, color: OcgColors.success, size: 16),
      const SizedBox(width: 8),
      Text(
        'Compartida el ${DateFormat('d MMM, HH:mm').format(simulation.fechaCompartida!)}',
        style: const TextStyle(fontSize: 12, color: OcgColors.bronze),
      ),
    ],
  );
}
```

---

## Resto del documento

Lo demás se mantiene igual:
- CameraCaptureScreen
- mask_generator.dart con ML Kit
- Cloud Function processSmileSimulation
- BeforeAfterSlider
- Manejo de errores

El ÚNICO cambio es:
- BD-05: Agregar `compartida` y `fechaCompartida` a SmileSimulationModel
- BD-05: Actualizar Firestore cuando se comparte

---

## Nota técnica

Los campos de auditoría no afectan la privacidad del usuario:
- Solo registran que SE COMPARTIÓ (bool), no con quién
- La fecha de compartición es metadata operacional

Si en el futuro necesitas saber "cuántas simulaciones se compartieron este mes", puedes queryar:
```dart
_db
    .collection('simulations')
    .where('compartida', isEqualTo: true)
    .where('fechaCompartida', isGreaterThan: Timestamp.fromDate(monthStart))
    .where('fechaCompartida', isLessThan: Timestamp.fromDate(monthEnd))
    .count()
    .get()
```

