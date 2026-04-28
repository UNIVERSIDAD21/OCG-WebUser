import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/simulator/data/models/simulation_model.dart';

void main() {
  test('SimulationModel serializa y deserializa campos principales', () {
    final model = SimulationModel(
      id: 'sim-1',
      patientId: 'p-1',
      originalPath: 'simulations/p-1/sim-1/original.jpg',
      resultPath: null,
      compartidaConPaciente: false,
      createdAt: DateTime(2026, 3, 23, 12, 0),
      updatedAt: DateTime(2026, 3, 23, 12, 30),
      createdBy: 'admin-1',
      treatmentType: TreatmentType.alineadores,
      status: SimulationStatus.draft,
      notes: 'Primera carga',
      generationProvider: 'openai',
      modelUsed: 'gpt-image-2',
      attemptCount: 0,
      errorMessage: null,
      generatedAt: null,
      promptUsed: null,
      promptVersion: 'v1',
      mlKitUsed: false,
      detectedRegion: {'x': 0.2, 'y': 0.3, 'w': 0.4, 'h': 0.2},
      promptMetadata: {'version': 'v1'},
      fechaCompartida: null,
    );

    final json = model.toJson();
    expect(json['createdAt'], isA<Timestamp>());
    expect(json['updatedAt'], isA<Timestamp>());

    final decoded = SimulationModel.fromJson(json);
    expect(decoded.id, 'sim-1');
    expect(decoded.patientId, 'p-1');
    expect(decoded.generationProvider, 'openai');
    expect(decoded.modelUsed, 'gpt-image-2');
    expect(decoded.treatmentType, TreatmentType.alineadores);
    expect(decoded.status, SimulationStatus.draft);
    expect(decoded.notes, 'Primera carga');
    expect(decoded.detectedRegion?['w'], 0.4);
    expect(decoded.promptMetadata?['version'], 'v1');
  });

  test('SimulationModel mantiene compatibilidad con legacy originalUrl/resultUrl/mode', () {
    final decoded = SimulationModel.fromJson({
      'id': 'legacy-1',
      'patientId': 'p-legacy',
      'originalUrl': 'https://x/original.jpg',
      'resultUrl': 'https://x/result.jpg',
      'mode': 'manualDoctora',
      'creadoPor': 'admin-legacy',
      'status': 'ready',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

    expect(decoded.originalPath, 'https://x/original.jpg');
    expect(decoded.resultPath, 'https://x/result.jpg');
    expect(decoded.createdBy, 'admin-legacy');
    expect(decoded.status, SimulationStatus.ready);
  });
}
