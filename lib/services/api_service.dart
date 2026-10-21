import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ServerConnectionException implements Exception {
  final String message;
  ServerConnectionException([this.message = 'No hay conexión con el servidor. Verifique su conexión o intente más tarde.']);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException([this.message = 'No se encontraron dorsales para este documento.']);
  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4550');

  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/config')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<dynamic>> getEventos() async {
    final res = await http.get(Uri.parse('$baseUrl/eventos'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar eventos: ${res.body}');
  }

  Future<List<dynamic>> getEventosActivos() async {
    final res = await http.get(Uri.parse('$baseUrl/eventos/activos'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar eventos activos: ${res.body}');
  }

  Future<Map<String, dynamic>> getEvento(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/eventos/$id'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al cargar evento: ${res.body}');
  }

  Future<List<dynamic>> getCompetencias({int? idevento}) async {
    final url = idevento != null ? '$baseUrl/eventos/$idevento/competencias' : '$baseUrl/competencias';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar competencias: ${res.body}');
  }

  Future<List<dynamic>> getCategorias({int? idevento}) async {
    final url = idevento != null ? '$baseUrl/eventos/$idevento/categorias' : '$baseUrl/categorias';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar categorias: ${res.body}');
  }

  Future<Map<String, dynamic>> getConfigDorsal(int idevento) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/config/$idevento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 404) return {};
    throw Exception('Error al cargar config: ${res.body}');
  }

  Future<void> saveConfigDorsal(Map<String, dynamic> config) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dorsales/config'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config),
    );
    if (res.statusCode != 201) throw Exception('Error al guardar config: ${res.body}');
  }

  Future<Map<String, dynamic>> uploadBaseImage({
    required int idevento,
    required Uint8List bytes,
    required String filename,
    String? competencias,
    String? categorias,
    String? sexos,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/dorsales/base-imagen/$idevento'));
    req.files.add(http.MultipartFile.fromBytes('imagen', bytes, filename: filename));
    if (competencias != null) req.fields['competencias'] = competencias;
    if (categorias != null) req.fields['categorias'] = categorias;
    if (sexos != null) req.fields['sexos'] = sexos;
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al subir imagen: ${res.body}');
  }

  Future<List<dynamic>> getBaseImagenes(int idevento) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/base-imagenes/$idevento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar imagenes base: ${res.body}');
  }

  Future<void> deleteBaseImagen(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/dorsales/base-imagen/$id'));
    if (res.statusCode != 200) throw Exception('Error al eliminar imagen: ${res.body}');
  }

  Future<Map<String, dynamic>> generarDorsales(int idevento) async {
    final res = await http.post(Uri.parse('$baseUrl/dorsales/generar/$idevento'));
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al generar dorsales: ${res.body}');
  }

  Future<Map<String, dynamic>> generarDorsalesPorDocumentos(int idevento, List<String> documentos) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dorsales/generar/$idevento/por-documentos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'documentos': documentos}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al generar dorsales por documentos: ${res.body}');
  }

  Future<Map<String, dynamic>> contarDorsales(int idevento) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/generar/$idevento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    return {'total': 0};
  }

  Future<Map<String, dynamic>> eliminarDorsales(int idevento) async {
    final res = await http.delete(Uri.parse('$baseUrl/dorsales/generar/$idevento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al eliminar dorsales: ${res.body}');
  }

  Future<List<dynamic>> buscarDorsal(String iddocumento) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/dorsales/buscar/$iddocumento')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      if (res.statusCode == 404) throw NotFoundException('No se encontraron dorsales para este documento');
      throw ServerConnectionException('Error en el servidor (${res.statusCode})');
    } catch (e) {
      if (e is NotFoundException) rethrow;
      throw ServerConnectionException('No se pudo conectar con el servidor. Verifique su conexión a internet o intente más tarde.');
    }
  }

  Future<List<dynamic>> buscarDorsalEnEvento(int idevento, String iddocumento) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/dorsales/buscar/$idevento/$iddocumento')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
      if (res.statusCode == 404) throw NotFoundException('No se encontraron dorsales para este documento');
      throw ServerConnectionException('Error en el servidor (${res.statusCode})');
    } catch (e) {
      if (e is NotFoundException) rethrow;
      throw ServerConnectionException('No se pudo conectar con el servidor. Verifique su conexión a internet o intente más tarde.');
    }
  }

  Future<List<dynamic>> getDorsalesList(int idevento) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/listar/$idevento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al listar dorsales: ${res.body}');
  }

  Future<Map<String, dynamic>> enviarEmailDorsales({
    required List<int> ids,
    required String subject,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dorsales/enviar-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'ids': ids, 'subject': subject, 'message': message}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al enviar email: ${res.body}');
  }

  Future<Map<String, dynamic>> enviarTodosDorsales({
    required int idevento,
    required String subject,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dorsales/enviar/$idevento'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'subject': subject, 'message': message}),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al enviar todos: ${res.body}');
  }

  Future<Map<String, dynamic>> getEmailTaskStatus(String taskId) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/email-task/$taskId'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al obtener estado: ${res.body}');
  }

  Future<void> marcarPendienteDorsal(int id) async {
    final res = await http.patch(Uri.parse('$baseUrl/dorsales/$id/desmarcar-enviado'));
    if (res.statusCode != 200) throw Exception('Error al marcar pendiente: ${res.body}');
  }

  String imagenUrl(int id) => '$baseUrl/dorsales/imagen/$id';

  String baseImagenUrl(int id) => '$baseUrl/dorsales/base-imagen/$id/imagen';

  String eventoLogoUrl(String logo) {
    if (logo.startsWith('http://') || logo.startsWith('https://')) {
      return Uri.encodeFull(logo);
    }
    return Uri.encodeFull('$baseUrl/eventos/logo/$logo');
  }

  Future<void> updateBaseImagen(int id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/dorsales/base-imagen/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode != 200) throw Exception('Error al actualizar imagen: ${res.body}');
  }

  Future<Uint8List> getImagenBytes(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/imagen/$id'));
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Error al cargar imagen: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getConfig() async {
    final res = await http.get(Uri.parse('$baseUrl/config'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al obtener config: ${res.body}');
  }

  Future<Map<String, dynamic>> getVersion() async {
    final res = await http.get(Uri.parse('$baseUrl/version'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al obtener versión: ${res.body}');
  }

  Future<Uint8List> getPreview(int idbaseimagen, Map<String, dynamic> config) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dorsales/preview'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idbaseimagen': idbaseimagen, 'camposConfig': config['camposConfig']}),
    );
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Error al generar preview: ${res.body}');
  }

  // ---- Notificaciones ----
  Future<Map<String, dynamic>> enviarNotificacion({
    required List<int> ids,
    required String subject,
    required String message,
    Uint8List? archivoBytes,
    String? archivoName,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/notificaciones/enviar'));
    req.fields['ids'] = ids.join(',');
    req.fields['subject'] = subject;
    req.fields['message'] = message;
    if (archivoBytes != null && archivoName != null) {
      req.files.add(http.MultipartFile.fromBytes('archivo', archivoBytes, filename: archivoName));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al enviar notificación: ${res.body}');
  }

  Future<Map<String, dynamic>> enviarNotificacionTodos({
    required int idevento,
    required String subject,
    required String message,
    Uint8List? archivoBytes,
    String? archivoName,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/notificaciones/enviar/$idevento'));
    req.fields['subject'] = subject;
    req.fields['message'] = message;
    if (archivoBytes != null && archivoName != null) {
      req.files.add(http.MultipartFile.fromBytes('archivo', archivoBytes, filename: archivoName));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al enviar notificación: ${res.body}');
  }

  Future<Map<String, dynamic>> getNotificacionTaskStatus(String taskId) async {
    final res = await http.get(Uri.parse('$baseUrl/notificaciones/email-task/$taskId'));
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al obtener estado: ${res.body}');
  }

  Future<List<dynamic>> getInscritosPorEvento(int idevento) async {
    final res = await http.get(Uri.parse('$baseUrl/inscritos/evento/$idevento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar inscritos: ${res.body}');
  }

  // ---- Proveedores de Correo ----
  Future<List<dynamic>> getMailProviders() async {
    final res = await http.get(Uri.parse('$baseUrl/mail/providers'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar proveedores de correo: ${res.body}');
  }

  Future<Map<String, dynamic>> createMailProvider(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/mail/providers'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al crear proveedor de correo: ${res.body}');
  }

  Future<Map<String, dynamic>> updateMailProvider(int id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/mail/providers/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al actualizar proveedor de correo: ${res.body}');
  }

  Future<void> deleteMailProvider(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/mail/providers/$id'));
    if (res.statusCode != 200) throw Exception('Error al eliminar proveedor: ${res.body}');
  }

  Future<void> activarMailProvider(int id) async {
    final res = await http.patch(Uri.parse('$baseUrl/mail/providers/$id/activar'));
    if (res.statusCode != 200) throw Exception('Error al activar proveedor: ${res.body}');
  }

  Future<Map<String, dynamic>> testMailProvider({int? id, required String email}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/mail/providers/test'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'email': email}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception('Error al probar proveedor: ${res.body}');
  }
}
