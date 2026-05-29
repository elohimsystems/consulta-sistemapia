import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class BuscarDorsalPage extends StatefulWidget {
  final int idevento;
  const BuscarDorsalPage({super.key, required this.idevento});

  @override
  State<BuscarDorsalPage> createState() => _BuscarDorsalPageState();
}

class _BuscarDorsalPageState extends State<BuscarDorsalPage> {
  final _controller = TextEditingController();
  final _api = ApiService();
  List<Map<String, dynamic>>? _resultados;
  final Map<int, Uint8List?> _imagenesCache = {};
  bool _loading = false;
  String? _error;
  String _eventoNombre = '';

  @override
  void initState() {
    super.initState();
    _cargarEvento();
  }

  Future<void> _cargarEvento() async {
    try {
      final evento = await _api.getEvento(widget.idevento);
      setState(() => _eventoNombre = evento['nombre']?.toString() ?? 'Evento #${widget.idevento}');
    } catch (e) {
      _eventoNombre = 'Evento #${widget.idevento}';
    }
  }

  Future<void> _buscar() async {
    final doc = _controller.text.trim();
    if (doc.isEmpty) return;

    setState(() { _loading = true; _error = null; _resultados = null; _imagenesCache.clear(); });

    try {
      final res = await _api.buscarDorsalEnEvento(widget.idevento, doc);
      final items = res.cast<Map<String, dynamic>>();
      setState(() => _resultados = items);
      for (final item in items) {
        _cargarImagen(int.parse(item['id'].toString()));
      }
    } catch (e) {
      debugPrint('Error al buscar dorsal: $e');
      setState(() { _error = 'No se encontraron dorsales para este documento'; _loading = false; });
    }
    setState(() => _loading = false);
  }

  Future<void> _compartir(Uint8List bytes, String nombre) async {
    try {
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'dorsal.jpg')],
        text: 'Mi dorsal - $nombre',
      );
    } catch (e) {
      debugPrint('Error al compartir: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al compartir: $e')));
    }
  }

  Future<void> _cargarImagen(int id) async {
    try {
      final bytes = await _api.getImagenBytes(id);
      setState(() => _imagenesCache[id] = bytes);
    } catch (e) {
      debugPrint('Error al cargar imagen #$id: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: Scaffold(
      appBar: AppBar(title: Text('Consulta tu inscripción - $_eventoNombre'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Ingrese su cédula',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _buscar,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                  child: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(_error!, style: const TextStyle(fontSize: 16)),
              ),
            if (_resultados != null)
              ...(_resultados!.map((item) {
                final id = int.parse(item['id'].toString());
                final bytes = _imagenesCache[id];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if ((item['nombre'] ?? '').isNotEmpty)
                                _infoCol('Participante', item['nombre']),
                              if ((item['competencia'] ?? '').isNotEmpty)
                                _infoCol('Competencia', item['competencia']),
                              if ((item['categoria'] ?? '').isNotEmpty)
                                _infoCol('Categoría', item['categoria']),
                              if ((item['sexo'] ?? '').isNotEmpty)
                                _infoCol('Sexo', item['sexo']),
                              _infoCol('Cédula', item['iddocumento']),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: SizedBox(
                            width: double.infinity,
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: bytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(bytes, fit: BoxFit.contain),
                                  )
                                : Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (bytes != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _compartir(bytes, item['nombre'] ?? 'Participante'),
                            icon: const Icon(Icons.share),
                            label: const Text('Compartir'),
                          ),
                        ),
                    ],
                  ),
                );
              })),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Regresar'),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _infoCol(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
