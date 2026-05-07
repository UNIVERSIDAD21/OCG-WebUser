import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/constants/firestore_paths.dart';
import '../../../shared/constants/storage_paths.dart';

enum ProfilePhotoOwnerType { admin, patient }

class ProfilePhotoResult {
  const ProfilePhotoResult({required this.url, required this.storagePath});

  final String url;
  final String storagePath;
}

class ProfilePhotoService {
  ProfilePhotoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? picker,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _picker = picker ?? ImagePicker();

  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  Future<ProfilePhotoResult?> pickAndUpload({
    required ProfilePhotoOwnerType ownerType,
    required String uid,
    required ImageSource source,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 86,
    );
    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    if (bytes.length > maxBytes) {
      throw Exception('PROFILE_PHOTO_TOO_LARGE');
    }

    final extension = _resolveExtension(picked.name, picked.mimeType);
    if (!allowedExtensions.contains(extension)) {
      throw Exception('PROFILE_PHOTO_INVALID_TYPE');
    }

    final contentType = _contentType(extension);
    final path = switch (ownerType) {
      ProfilePhotoOwnerType.admin => StoragePaths.adminProfilePhoto(
        uid,
        extension,
      ),
      ProfilePhotoOwnerType.patient => StoragePaths.patientProfilePhoto(
        uid,
        extension,
      ),
    };

    final docRef = _docRef(ownerType, uid);
    final previous = await docRef.get();
    final previousPath = previous.data()?['profilePhotoPath']?.toString();

    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();

    await docRef.set({
      'photoUrl': url,
      'profilePhotoPath': path,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != path) {
      await _deleteStoragePath(previousPath);
    }

    return ProfilePhotoResult(url: url, storagePath: path);
  }

  Future<void> deletePhoto({
    required ProfilePhotoOwnerType ownerType,
    required String uid,
  }) async {
    final docRef = _docRef(ownerType, uid);
    final doc = await docRef.get();
    final data = doc.data() ?? const <String, dynamic>{};
    final path = data['profilePhotoPath']?.toString();

    if (path != null && path.isNotEmpty) {
      await _deleteStoragePath(path);
    }

    final update = <String, dynamic>{
      'photoUrl': null,
      'profilePhotoPath': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Limpieza de compatibilidad para perfiles de paciente antiguos.
    if (ownerType == ProfilePhotoOwnerType.patient) {
      update['fotoUrl'] = null;
    }

    await docRef.set(update, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> _docRef(
    ProfilePhotoOwnerType ownerType,
    String uid,
  ) {
    final collection = switch (ownerType) {
      ProfilePhotoOwnerType.admin => FirestorePaths.admins,
      ProfilePhotoOwnerType.patient => FirestorePaths.patients,
    };
    return _db.collection(collection).doc(uid);
  }

  String _resolveExtension(String name, String? mimeType) {
    final cleanName = name.toLowerCase().trim();
    final dot = cleanName.lastIndexOf('.');
    if (dot >= 0 && dot < cleanName.length - 1) {
      final ext = cleanName.substring(dot + 1);
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') {
        return ext;
      }
    }

    return switch (mimeType?.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => '',
    };
  }

  String _contentType(String extension) {
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  Future<void> _deleteStoragePath(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') rethrow;
    }
  }
}
