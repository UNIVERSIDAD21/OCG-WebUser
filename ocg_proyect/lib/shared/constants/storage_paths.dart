class StoragePaths {
  StoragePaths._();

  static String adminProfilePhoto(String id, String extension) =>
      'admins/$id/profile/profile.$extension';
  static String patientProfile(String id) => 'patients/$id/profile/profile.jpg';
  static String patientProfilePhoto(String id, String extension) =>
      'patients/$id/profile/profile.$extension';
  static String patientPhoto(String id, String name) =>
      'patients/$id/photos/$name';
  static String patientClinicalFile(
    String patientId,
    String fileId,
    String originalName, {
    String? treatmentId,
  }) {
    final cleanName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (treatmentId != null && treatmentId.isNotEmpty) {
      return 'patients/$patientId/treatments/$treatmentId/clinical-files/${fileId}_$cleanName';
    }
    return 'patients/$patientId/clinical-files/${fileId}_$cleanName';
  }

  static String simulationOriginal(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/original.jpg';
  static String simulationResult(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/result.jpg';
  static String simulationThumbOriginal(
    String patientId,
    String simulationId,
  ) => 'simulations/$patientId/$simulationId/thumb_original.jpg';
  static String simulationThumbResult(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/thumb_result.jpg';
  static String simulatorTemp(String sessionId, String name) =>
      'simulator_temp/$sessionId/$name';
}
