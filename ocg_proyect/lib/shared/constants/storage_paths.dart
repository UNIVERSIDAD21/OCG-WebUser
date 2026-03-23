class StoragePaths {
  StoragePaths._();

  static String patientProfile(String id) => 'patients/$id/profile/profile.jpg';
  static String patientPhoto(String id, String name) => 'patients/$id/photos/$name';
  static String simulationOriginal(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/original.jpg';
  static String simulationResult(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/result.jpg';
  static String simulationThumbOriginal(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/thumb_original.jpg';
  static String simulationThumbResult(String patientId, String simulationId) =>
      'simulations/$patientId/$simulationId/thumb_result.jpg';
  static String simulatorTemp(String sessionId, String name) => 'simulator_temp/$sessionId/$name';
}
