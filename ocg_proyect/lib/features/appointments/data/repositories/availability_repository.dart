import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/constants/firestore_paths.dart';
import '../models/availability_day_model.dart';

class AvailabilityRepository {
  AvailabilityRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _availabilityRef =>
      _db.collection(FirestorePaths.availability);

  Stream<AvailabilityDayModel?> watchAvailabilityByDay(String dayKey) {
    return _availabilityRef.doc(dayKey).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AvailabilityDayModel.fromJson(doc.id, doc.data()!);
    });
  }

  Future<AvailabilityDayModel?> getAvailabilityByDay(String dayKey) async {
    final doc = await _availabilityRef.doc(dayKey).get();
    if (!doc.exists || doc.data() == null) return null;
    return AvailabilityDayModel.fromJson(doc.id, doc.data()!);
  }
}
