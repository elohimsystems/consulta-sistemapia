import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class ListarDorsalesPage extends StatefulWidget {
  final int idevento;
  final String eventoNombre;
  const ListarDorsalesPage({super.key, required this.idevento, this.eventoNombre = ''});

  @override
  State<ListarDorsalesPage> createState() => _ListarDorsalesPageState();
}

class _ListarDorsalesPageState extends State<ListarDorsalesPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  final Map<int, Uint8List?> _imagenesCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getDorsalesList(widget.idevento);
      final items = res.cast<Map<String, dynamic>>();
      setState(() { _items = items; _loading = false; });
      for (final item in items) {
        _cargarImagen(int.parse(item['id'].toString()));
      }
    } catch (e) {
      debugPrint('Error al listar dorsales: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _cargarImagen(int id) async {
    try {
      final bytes = await _api.getImagenBytes(id);
      if (mounted) setState(() => _imagenesCache[id] = bytes);
    } catch (e) {
      debugPrint('Error al cargar imagen #$id: $e');
    }
  }

  Future<void> _compartir(Uint8List bytes, String nombre) async {
    try {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'dorsal.jpg')],
        text: 'Mi dorsal - $nombre',
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dorsales - ${widget.eventoNombre}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No hay dorsales generados'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      final id = int.parse(item['id'].toString());
                      final bytes = _imagenesCache[id];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 100,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: bytes != null
                                      ? Image.memory(bytes, fit: BoxFit.fitWidth)
                                      : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  alignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(item['nombre'] ?? 'Sin nombre', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    if (item['iddocumento'] != null)
                                      Text('Ced: ${item['iddocumento']}', style: const TextStyle(fontSize: 12)),
                                    if (item['numero'] != null)
                                      Text('Nro: ${item['numero']}', style: const TextStyle(fontSize: 12)),
                                    if ((item['competencia'] ?? '').isNotEmpty)
                                      Text('${item['competencia']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    if ((item['categoria'] ?? '').isNotEmpty)
                                      Text('${item['categoria']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (bytes != null)
                                IconButton(
                                  icon: const Icon(Icons.share),
                                  onPressed: () => _compartir(bytes, item['nombre'] ?? 'Participante'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
