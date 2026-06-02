import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    const _cols = ['', 'Nombre', 'Cédula', 'Nro', 'Competencia', 'Categoría'];
    const _colWidths = [110.0, 160.0, 110.0, 70.0, 140.0, 140.0];
    const _totalWidth = 730.0;

    return Scaffold(
      appBar: AppBar(title: Text('Dorsales - ${widget.eventoNombre}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No hay dorsales generados'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _totalWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: List.generate(_cols.length, (i) {
                                  return SizedBox(
                                    width: _colWidths[i],
                                    child: Text(_cols[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  );
                                }),
                              ),
                            ),
                            ..._items.map((item) {
                              final id = int.parse(item['id'].toString());
                              final bytes = _imagenesCache[id];
                              return Container(
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: _colWidths[0],
                                      height: 90,
                                      child: bytes != null
                                          ? ClipRRect(child: Image.memory(bytes, fit: BoxFit.fitWidth))
                                          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                    SizedBox(width: _colWidths[1], child: Text(item['nombre'] ?? '', style: const TextStyle(fontSize: 12))),
                                    SizedBox(width: _colWidths[2], child: Text(item['iddocumento'] ?? '', style: const TextStyle(fontSize: 12))),
                                    SizedBox(width: _colWidths[3], child: Text(item['numero']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                                    SizedBox(width: _colWidths[4], child: Text(item['competencia'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                    SizedBox(width: _colWidths[5], child: Text(item['categoria'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
