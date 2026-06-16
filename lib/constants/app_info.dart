class AppInfo {
  static const String nombre = 'SistemaPIA';
  static const String version = '1.0.0';
  static const String empresa = 'ElohimSystemns';
  static const List<String> desarrolladores = ['Freddy Garcia'];
  static const String _defaultMinApi = '1.0.0';
  static String get minApiVersion {
    const env = String.fromEnvironment('MIN_API_VERSION');
    return env.isNotEmpty ? env : _defaultMinApi;
  }
}
