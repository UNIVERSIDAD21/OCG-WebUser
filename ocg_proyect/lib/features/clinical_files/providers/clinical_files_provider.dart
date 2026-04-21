import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/constants/storage_paths.dart';
import '../../treatment/data/models/patient_treatment.dart';
import '../data/models/clinical_file_model.dart';
import '../data/repositories/clinical_files_repository.dart';
import '../services/clinical_file_picker_service.dart';
import '../services/clinical_file_validator.dart';
import '../services/clinical_files_storage_service.dart';

final clinicalFilesRepositoryProvider = Provider<ClinicalFilesRepository>((
  ref,
) {
  return ClinicalFilesRepository(FirebaseFirestore.instance);
});

final clinicalFilesStorageProvider = Provider<ClinicalFilesStorageService>((
  ref,
) {
  return ClinicalFilesStorageService(FirebaseStorage.instance);
});

final clinicalFilePickerProvider = Provider<ClinicalFilePickerService>((ref) {
  return ClinicalFilePickerService();
});

final clinicalFileValidatorProvider = Provider<ClinicalFileValidator>((ref) {
  return ClinicalFileValidator();
});

final patientClinicalFilesProvider =
    StreamProvider.family<
      List<ClinicalFileModel>,
      ({String patientId, String? treatmentId, bool onlyVisibleToPatient})
    >((ref, args) {
      return ref
          .watch(clinicalFilesRepositoryProvider)
          .watchFiles(
            args.patientId,
            treatmentId: args.treatmentId,
            onlyVisibleToPatient: args.onlyVisibleToPatient,
          );
    });

class ClinicalFileUploadProgressNotifier extends Notifier<double?> {
  @override
  double? build() => null;

  void setProgress(double? value) => state = value;
  void reset() => state = null;
}

final clinicalFileUploadProgressProvider =
    NotifierProvider<ClinicalFileUploadProgressNotifier, double?>(
      ClinicalFileUploadProgressNotifier.new,
    );

class UploadClinicalFileNotifier extends AsyncNotifier<void> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> upload({
    required String patientId,
    required String uploadedBy,
    required String category,
    required String displayName,
    String? notes,
    PatientTreatment? treatment,
    bool visibleToPatient = false,
  }) async {
    final picker = ref.read(clinicalFilePickerProvider);
    final validator = ref.read(clinicalFileValidatorProvider);
    final storage = ref.read(clinicalFilesStorageProvider);
    final repository = ref.read(clinicalFilesRepositoryProvider);

    final progressState = ref.read(clinicalFileUploadProgressProvider.notifier);

    state = const AsyncLoading(progress: 0);
    progressState.setProgress(0);
    state = await AsyncValue.guard(() async {
      final picked = await picker.pick();
      if (picked == null) {
        throw Exception('CLINICAL_FILE_PICK_CANCELLED');
      }
      validator.validate(picked);

      final fileId = DateTime.now().microsecondsSinceEpoch.toString();
      final storagePath = StoragePaths.patientClinicalFile(
        patientId,
        fileId,
        picked.fileName,
        treatmentId: treatment?.id,
      );

      try {
        final url = await storage.upload(
          patientId: patientId,
          treatmentId: treatment?.id,
          fileId: fileId,
          file: picked,
          onProgress: (progress) {
            progressState.setProgress(progress);
            state = AsyncLoading(progress: progress);
          },
        );

        final now = DateTime.now();
        final model = ClinicalFileModel(
          id: fileId,
          patientId: patientId,
          treatmentId: treatment?.id,
          treatmentNameSnapshot: treatment?.displayName,
          originalName: picked.fileName,
          displayName: displayName.trim().isEmpty
              ? picked.fileName
              : displayName.trim(),
          storagePath: storagePath,
          downloadUrl: url,
          mimeType: picked.mimeType,
          extension: picked.extension,
          sizeBytes: picked.sizeBytes,
          category: category,
          notes: notes?.trim().isEmpty ?? true ? null : notes?.trim(),
          uploadedBy: uploadedBy,
          uploadedAt: now,
          updatedAt: now,
          active: true,
          visibleToPatient: visibleToPatient,
        );

        await repository.saveMetadata(model);
        progressState.setProgress(1);
      } on FirebaseException catch (error) {
        if (error.plugin == 'firebase_storage' ||
            error.code == 'unauthorized') {
          throw Exception('CLINICAL_FILE_STORAGE_PERMISSION_DENIED');
        }
        if (error.plugin == 'cloud_firestore' ||
            error.code == 'permission-denied') {
          try {
            await storage.deleteByPath(storagePath);
          } catch (_) {}
          throw Exception('CLINICAL_FILE_METADATA_PERMISSION_DENIED');
        }
        rethrow;
      } catch (error) {
        final text = error.toString();
        if (text.contains('permission-denied')) {
          try {
            await storage.deleteByPath(storagePath);
          } catch (_) {}
          throw Exception('CLINICAL_FILE_METADATA_PERMISSION_DENIED');
        }
        rethrow;
      }
    });
    progressState.reset();
  }

  Future<void> softDelete({
    required String patientId,
    required String fileId,
    required String deletedBy,
  }) async {
    final repository = ref.read(clinicalFilesRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => repository.softDelete(
        patientId: patientId,
        fileId: fileId,
        deletedBy: deletedBy,
      ),
    );
  }
}

final uploadClinicalFileProvider =
    AsyncNotifierProvider<UploadClinicalFileNotifier, void>(
      UploadClinicalFileNotifier.new,
    );
