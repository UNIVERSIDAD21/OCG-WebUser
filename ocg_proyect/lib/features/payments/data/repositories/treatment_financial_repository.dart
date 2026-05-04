import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../../../treatment/data/models/patient_treatment.dart';
import '../models/financial_item_model.dart';
import '../models/payment_model.dart';
import '../models/treatment_financial_summary_model.dart';

class TreatmentFinancialRepository {
  TreatmentFinancialRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _itemsRef(
    String patientId,
    String treatmentId,
  ) => _db.collection(
    FirestorePaths.treatmentFinancialItems(patientId, treatmentId),
  );

  DocumentReference<Map<String, dynamic>> _treatmentRef(
    String patientId,
    String treatmentId,
  ) => _db.doc(FirestorePaths.patientTreatmentDoc(patientId, treatmentId));

  DocumentReference<Map<String, dynamic>> _paymentRef(
    String patientId,
    String treatmentId,
  ) => _db.doc(FirestorePaths.treatmentPaymentDoc(patientId, treatmentId));

  DocumentReference<Map<String, dynamic>> _legacyPaymentRef(String patientId) =>
      _db.doc(FirestorePaths.paymentDoc(patientId));

  DocumentReference<Map<String, dynamic>> _patientRef(String patientId) =>
      _db.collection(FirestorePaths.patients).doc(patientId);

  Stream<List<FinancialItemModel>> watchFinancialItems(
    String patientId,
    String treatmentId,
  ) {
    return _itemsRef(patientId, treatmentId).orderBy('order').snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map((doc) => FinancialItemModel.fromJson(doc.data(), id: doc.id))
          .toList();
      items.sort((a, b) => a.order.compareTo(b.order));
      return items;
    });
  }

  Future<Map<String, dynamic>> verifyFinancialItemsPersistence({
    required String patientId,
    required String treatmentId,
  }) async {
    final path = FirestorePaths.treatmentFinancialItems(patientId, treatmentId);
    final snapshot = await _itemsRef(patientId, treatmentId).get();
    return <String, dynamic>{
      'path': path,
      'count': snapshot.docs.length,
      'ids': snapshot.docs.map((doc) => doc.id).toList(),
      'items': snapshot.docs.map((doc) => doc.data()).toList(),
    };
  }

  Future<void> ensureBaseItems({
    required String patientId,
    required PatientTreatment treatment,
    String createdBy = 'system',
  }) async {
    final snapshot = await _itemsRef(patientId, treatment.id).get();
    if (snapshot.docs.isNotEmpty) return;

    final now = DateTime.now();
    final defaults = _defaultItems(
      patientId: patientId,
      treatment: treatment,
      now: now,
      createdBy: createdBy,
    );
    final batch = _db.batch();
    for (final item in defaults) {
      batch.set(_itemsRef(patientId, treatment.id).doc(item.id), item.toJson());
    }
    await batch.commit();
    await recalculateSummary(patientId: patientId, treatment: treatment);
  }

  Future<void> replaceFinancialItems({
    required String patientId,
    required PatientTreatment treatment,
    required List<FinancialItemModel> items,
    String updatedBy = 'system',
  }) async {
    _validateItems(items);

    final existing = await _itemsRef(patientId, treatment.id).get();
    final batch = _db.batch();
    final nextIds = items.map((item) => item.id).toSet();

    for (final doc in existing.docs) {
      if (!nextIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }

    for (final item in items) {
      Map<String, dynamic>? existingData;
      for (final doc in existing.docs) {
        if (doc.id == item.id) {
          existingData = doc.data();
          break;
        }
      }
      final prepared = item.copyWith(
        createdBy:
            item.createdBy ??
            existingData?['createdBy']?.toString() ??
            updatedBy,
        updatedBy: updatedBy,
        createdAt: existingData?['createdAt'] is Timestamp
            ? (existingData!['createdAt'] as Timestamp).toDate()
            : item.createdAt,
        updatedAt: DateTime.now(),
      );
      batch.set(
        _itemsRef(patientId, treatment.id).doc(item.id),
        prepared.toJson(),
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    await recalculateSummary(patientId: patientId, treatment: treatment);
  }

  Future<List<FinancialItemModel>> normalizeBaseItemsForTreatmentType({
    required String patientId,
    required PatientTreatment treatment,
    bool preserveAmount = true,
  }) async {
    final snapshot = await _itemsRef(patientId, treatment.id).get();
    final items =
        snapshot.docs
            .map((doc) => FinancialItemModel.fromJson(doc.data(), id: doc.id))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final wantsOrthopedics = treatment.tipoBase == 'ortopedia';
    final retainersIndex = items.indexWhere((item) => item.id == 'retainers');
    final applianceIndex = items.indexWhere((item) => item.id == 'appliance_1');

    if (wantsOrthopedics && retainersIndex != -1) {
      final retainers = items[retainersIndex];
      items[retainersIndex] = retainers.copyWith(
        id: 'appliance_1',
        name: 'Aparato 1',
        normalizedName: 'aparato_1',
        kind: 'appliance',
        amount: preserveAmount ? retainers.amount : 0,
        active: true,
        updatedAt: DateTime.now(),
      );
      if (applianceIndex != -1 && applianceIndex != retainersIndex) {
        items[applianceIndex] = items[applianceIndex].copyWith(
          active: false,
          updatedAt: DateTime.now(),
        );
      }
    }

    if (!wantsOrthopedics && applianceIndex != -1) {
      final appliance = items[applianceIndex];
      items[applianceIndex] = appliance.copyWith(
        id: 'retainers',
        name: 'Retenedores',
        normalizedName: 'retenedores',
        kind: 'retainers',
        amount: preserveAmount ? appliance.amount : 0,
        active: true,
        updatedAt: DateTime.now(),
      );
      if (retainersIndex != -1 && retainersIndex != applianceIndex) {
        items[retainersIndex] = items[retainersIndex].copyWith(
          active: false,
          updatedAt: DateTime.now(),
        );
      }
    }

    return items;
  }

  Future<void> recalculateSummary({
    required String patientId,
    required PatientTreatment treatment,
  }) async {
    final snapshot = await _itemsRef(patientId, treatment.id).get();
    final items =
        snapshot.docs
            .map((doc) => FinancialItemModel.fromJson(doc.data(), id: doc.id))
            .where((item) => item.active)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    final total = items.fold<double>(
      0,
      (totalSoFar, item) => totalSoFar + item.amount,
    );
    final paymentDoc = await _paymentRef(patientId, treatment.id).get();
    final paymentData = paymentDoc.data() ?? <String, dynamic>{};
    final paidBefore =
        (paymentData['montoPagado'] as num?)?.toDouble() ??
        ((treatment.totalTratamiento ?? 0) - (treatment.saldoPendiente ?? 0))
            .clamp(0, double.infinity)
            .toDouble();
    final pending = (total - paidBefore).clamp(0, double.infinity).toDouble();
    final nextPaymentDate = paymentData['fechaProximoPago'];
    final paymentStatus = PaymentModel.calcularEstado(
      saldoPendiente: pending,
      fechaProximoPago: _parseNullableDate(nextPaymentDate),
    );

    final summary = TreatmentFinancialSummaryModel(
      currency: 'COP',
      subtotalAmount: total,
      discountAmount: 0.0,
      totalAmount: total,
      paidAmount: paidBefore,
      pendingAmount: pending,
      itemsCount: items.length,
      lastPricingUpdateAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(_treatmentRef(patientId, treatment.id), {
      'totalTratamiento': total,
      'saldoPendiente': pending,
      'financialSummary': summary.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_paymentRef(patientId, treatment.id), {
      'id': treatment.id,
      'patientId': patientId,
      'treatmentId': treatment.id,
      'totalTratamiento': total,
      'montoPagado': paidBefore,
      'saldoPendiente': pending,
      'estado': paymentStatus.name,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': paymentData['createdAt'] ?? FieldValue.serverTimestamp(),
      'fechaProximoPago': nextPaymentDate,
      'schemaVersion': 2,
    }, SetOptions(merge: true));

    if (treatment.isPrimary) {
      batch.set(_legacyPaymentRef(patientId), {
        'id': patientId,
        'patientId': patientId,
        'treatmentId': treatment.id,
        'totalTratamiento': total,
        'montoPagado': paidBefore,
        'saldoPendiente': pending,
        'estado': paymentStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': paymentData['createdAt'] ?? FieldValue.serverTimestamp(),
        'fechaProximoPago': nextPaymentDate,
        'legacyMirror': true,
        'schemaVersion': 1,
      }, SetOptions(merge: true));
      batch.set(_patientRef(patientId), {
        'primaryTreatmentId': treatment.id,
        'totalTratamiento': total,
        'saldoPendiente': pending,
        'updatedAt': FieldValue.serverTimestamp(),
        'treatmentOverview': {
          'mode': 'primary-treatment',
          'source': 'treatment-truth',
          'treatmentId': treatment.id,
          'treatmentName': treatment.displayName,
          'baseType': treatment.tipoBase,
          'subtype': treatment.subtipo,
          'currentStage': treatment.etapaActual.name,
          'status': treatment.estado,
          'financial': {
            'totalTratamiento': total,
            'montoPagado': paidBefore,
            'saldoPendiente': pending,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'legacyProjection.financialSource': 'compatibility-only',
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  List<FinancialItemModel> _defaultItems({
    required String patientId,
    required PatientTreatment treatment,
    required DateTime now,
    required String createdBy,
  }) {
    final isOrthopedics = treatment.tipoBase == 'ortopedia';
    final required = <FinancialItemModel>[
      FinancialItemModel(
        id: 'initial',
        patientId: patientId,
        treatmentId: treatment.id,
        name: 'Inicial',
        normalizedName: 'inicial',
        kind: 'initial',
        amount: 0,
        deletable: false,
        editableName: true,
        order: 1,
        active: true,
        createdByAdmin: true,
        createdBy: createdBy,
        updatedBy: createdBy,
        createdAt: now,
        updatedAt: now,
      ),
      FinancialItemModel(
        id: 'controls',
        patientId: patientId,
        treatmentId: treatment.id,
        name: 'Controles',
        normalizedName: 'controles',
        kind: 'controls',
        amount: 0,
        unitAmount: 0,
        quantity: 1,
        deletable: false,
        editableName: true,
        order: 2,
        active: true,
        createdByAdmin: true,
        createdBy: createdBy,
        updatedBy: createdBy,
        createdAt: now,
        updatedAt: now,
      ),
      FinancialItemModel(
        id: isOrthopedics ? 'appliance_1' : 'retainers',
        patientId: patientId,
        treatmentId: treatment.id,
        name: isOrthopedics ? 'Aparato 1' : 'Retenedores',
        normalizedName: isOrthopedics ? 'aparato_1' : 'retenedores',
        kind: isOrthopedics ? 'appliance' : 'retainers',
        amount: 0,
        deletable: true,
        editableName: true,
        order: 3,
        active: true,
        createdByAdmin: true,
        createdBy: createdBy,
        updatedBy: createdBy,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final legacyAmount = treatment.totalTratamiento ?? 0;
    if (legacyAmount > 0) {
      return <FinancialItemModel>[
        ...required,
        FinancialItemModel(
          id: 'legacy_total',
          patientId: patientId,
          treatmentId: treatment.id,
          name: 'Valor tratamiento anterior',
          normalizedName: 'valor_tratamiento_anterior',
          kind: 'legacy',
          amount: legacyAmount,
          deletable: false,
          editableName: true,
          order: 4,
          active: true,
          createdByAdmin: true,
          createdBy: createdBy,
          updatedBy: createdBy,
          createdAt: now,
          updatedAt: now,
        ),
      ];
    }

    return required;
  }

  void _validateItems(List<FinancialItemModel> items) {
    if (items.isEmpty) {
      throw Exception('FINANCIAL_ITEMS_REQUIRED');
    }
    final active = items.where((item) => item.active).toList();
    final hasInitial = active.any((item) => item.kind == 'initial');
    final hasControls = active.any((item) => item.kind == 'controls');
    if (!hasInitial || !hasControls) {
      throw Exception('REQUIRED_FINANCIAL_ITEMS_MISSING');
    }

    final seen = <String>{};
    for (final item in items) {
      if (item.name.trim().isEmpty) {
        throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
      }
      if (item.amount < 0) throw Exception('FINANCIAL_ITEM_NEGATIVE_AMOUNT');
      final key = item.normalizedName.trim();
      if (key.isEmpty) throw Exception('FINANCIAL_ITEM_NAME_REQUIRED');
      if (seen.contains(key)) throw Exception('FINANCIAL_ITEM_DUPLICATE_NAME');
      seen.add(key);
      if (item.isRequired && !item.active) {
        throw Exception('REQUIRED_FINANCIAL_ITEM_CANNOT_BE_DISABLED');
      }
    }
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
