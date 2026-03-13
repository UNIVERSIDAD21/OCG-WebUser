import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/availability_day_model.dart';
import '../data/repositories/availability_repository.dart';
import '../../patients/providers/patients_provider.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(firestoreProvider));
});

final availabilityByDayProvider =
    StreamProvider.family<AvailabilityDayModel?, String>((ref, dayKey) {
  return ref.watch(availabilityRepositoryProvider).watchAvailabilityByDay(dayKey);
});
