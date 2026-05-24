import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:4550');

  Future<List<dynamic>> getEventos() async {
    final res = await http.get(Uri.parse('$baseUrl/eventos'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('Error al cargar eventos: ${res.body}');
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
    final res = await http.get(Uri.parse('$baseUrl/dorsales/buscar/$iddocumento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('No se encontraron dorsales: ${res.body}');
  }

  Future<List<dynamic>> buscarDorsalEnEvento(int idevento, String iddocumento) async {
    final res = await http.get(Uri.parse('$baseUrl/dorsales/buscar/$idevento/$iddocumento'));
    if (res.statusCode == 200) return jsonDecode(res.body) as List<dynamic>;
    throw Exception('No se encontraron dorsales: ${res.body}');
  }

  String imagenUrl(int id) => '$baseUrl/dorsales/imagen/$id';

  String baseImagenUrl(int id) => '$baseUrl/dorsales/base-imagen/$id/imagen';

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

  Future<Uint8List> getPreview(int idbaseimagen, Map<String, dynamic> config) async {
    final res = await http.post(
      Uri.parse('$baseUrl/dorsales/preview'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idbaseimagen': idbaseimagen, 'camposConfig': config['camposConfig']}),
    );
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Error al generar preview: ${res.body}');
  }
}
