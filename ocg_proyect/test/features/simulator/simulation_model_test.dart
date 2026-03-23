import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocg_proyect/features/patients/data/models/patient_model.dart';
import 'package:ocg_proyect/features/simulator/data/models/simulation_model.dart';

void main() {
  test('SimulationModel serializa y deserializa campos principales', () {
    final model = SimulationModel(
      id: 'sim-1',
      patientId: 'p-1',
      originalUrl: 'https://x/original.jpg',
      resultUrl: null,
      mode: SimulationMode.manualDoctora,
      compartidaConPaciente: false,
      createdAt: DateTime(2026, 3, 23, 12, 0),
      updatedAt: DateTime(2026, 3, 23, 12, 30),
      creadoPor: 'admin-1',
      treatmentType: TreatmentType.alineadores,
      status: SimulationStatus.draft,
      notes: 'Primera carga',
      mlKitUsed: false,
      detectedRegion: {'x': 0.2, 'y': 0.3, 'w': 0.4, 'h': 0.2},
      promptMetadata: {'version': 'v1'},
    );

    final json = model.toJson();
    expect(json['createdAt'], isA<Timestamp>());
    expect(json['updatedAt'], isA<Timestamp>());

    final decoded = SimulationModel.fromJson(json);
    expect(decoded.id, 'sim-1');
    expect(decoded.patientId, 'p-1');
    expect(decoded.mode, SimulationMode.manualDoctora);
    expect(decoded.treatmentType, TreatmentType.alineadores);
    expect(decoded.status, SimulationStatus.draft);
    expect(decoded.notes, 'Primera carga');
    expect(decoded.detectedRegion?['w'], 0.4);
    expect(decoded.promptMetadata?['version'], 'v1');
  });
}
