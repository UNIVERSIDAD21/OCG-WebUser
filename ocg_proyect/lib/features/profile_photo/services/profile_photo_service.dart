import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    FirebaseAuth? auth,
    ImagePicker? picker,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _picker = picker ?? ImagePicker();

  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
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

    final extension = _resolveExtension(picked.name, picked.mimeType, bytes);
    if (!allowedExtensions.contains(extension)) {
      throw Exception('PROFILE_PHOTO_INVALID_TYPE');
    }

    final contentType = _contentType(extension);
    final currentAuthUid = _auth.currentUser?.uid;
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

    _trace('upload.start', {
      'ownerType': ownerType.name,
      'uid': uid,
      'path': path,
      'extension': extension,
      'contentType': contentType,
      'bytesLength': bytes.length,
      'currentAuthUid': currentAuthUid,
      'authUidMatchesUid': currentAuthUid == uid,
    });

    final docRef = _docRef(ownerType, uid);
    final previous = await docRef.get();
    final previousPath = previous.data()?['profilePhotoPath']?.toString();

    final ref = _storage.ref(path);
    try {
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
    } on FirebaseException catch (error) {
      _trace('upload.storageError', {
        'ownerType': ownerType.name,
        'uid': uid,
        'path': path,
        'extension': extension,
        'contentType': contentType,
        'bytesLength': bytes.length,
        'currentAuthUid': currentAuthUid,
        'code': error.code,
        'message': error.message,
      });
      rethrow;
    }
    final url = await ref.getDownloadURL();

    final update = <String, dynamic>{
      'photoUrl': url,
      'profilePhotoPath': path,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (ownerType == ProfilePhotoOwnerType.patient) {
      update['fotoUrl'] = url;
    }

    await docRef.set(update, SetOptions(merge: true));

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

  void _trace(String action, Map<String, Object?> details) {
    // ignore: avoid_print
    print('[ProfilePhotoService][$action] $details');
  }

  String _resolveExtension(String name, String? mimeType, List<int> bytes) {
    final cleanName = name.toLowerCase().trim();
    final dot = cleanName.lastIndexOf('.');
    if (dot >= 0 && dot < cleanName.length - 1) {
      final ext = cleanName.substring(dot + 1);
      if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') {
        return ext == 'jpeg' ? 'jpg' : ext;
      }
    }

    final fromMime = switch (mimeType?.toLowerCase().trim()) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => '',
    };
    if (fromMime.isNotEmpty) return fromMime;

    if (_looksLikeJpeg(bytes)) return 'jpg';
    if (_looksLikePng(bytes)) return 'png';
    if (_looksLikeWebp(bytes)) return 'webp';
    return '';
  }

  bool _looksLikeJpeg(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;

  bool _looksLikePng(List<int> bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;

  bool _looksLikeWebp(List<int> bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;

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
