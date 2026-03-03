class StoragePaths {
  StoragePaths._();

  static String patientProfile(String id) => 'patients/$id/profile/profile.jpg';
  static String patientPhoto(String id, String name) => 'patients/$id/photos/$name';
  static String simulationResult(String pid, String sid, String name) => 'simulations/$pid/$sid/$name';
  static String simulatorTemp(String sessionId, String name) => 'simulator_temp/$sessionId/$name';
}
