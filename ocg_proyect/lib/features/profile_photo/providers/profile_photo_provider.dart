import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/firestore_paths.dart';
import '../services/profile_photo_service.dart';

final profilePhotoServiceProvider = Provider<ProfilePhotoService>((ref) {
  return ProfilePhotoService();
});

final adminProfileDocProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, adminId) {
      if (adminId.trim().isEmpty) return const Stream.empty();
      return FirebaseFirestore.instance
          .collection(FirestorePaths.admins)
          .doc(adminId)
          .snapshots()
          .map((doc) => doc.data());
    });

String? resolveProfilePhotoUrl(Map<String, dynamic>? data) {
  final photoUrl = data?['photoUrl']?.toString().trim();
  if (photoUrl != null && photoUrl.isNotEmpty) return photoUrl;

  // Compatibilidad con documentos antiguos de pacientes.
  final legacyFotoUrl = data?['fotoUrl']?.toString().trim();
  if (legacyFotoUrl != null && legacyFotoUrl.isNotEmpty) return legacyFotoUrl;

  return null;
}

String mapProfilePhotoError(Object error) {
  final raw = error.toString();
  if (raw.contains('PROFILE_PHOTO_TOO_LARGE')) {
    return 'La foto supera el tamaño máximo permitido de 5 MB.';
  }
  if (raw.contains('PROFILE_PHOTO_INVALID_TYPE')) {
    return 'Formato no permitido. Usa JPG, JPEG, PNG o WEBP.';
  }
  if (raw.contains('permission-denied') || raw.contains('unauthorized')) {
    return 'No tienes permisos para actualizar esta foto.';
  }
  return 'No se pudo actualizar la foto. Intenta de nuevo.';
}
