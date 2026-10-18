import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/acerca_de_dialog.dart';

class BuscarDorsalPage extends StatefulWidget {
  final int? idevento;
  const BuscarDorsalPage({super.key, this.idevento});

  @override
  State<BuscarDorsalPage> createState() => _BuscarDorsalPageState();
}

class _BuscarDorsalPageState extends State<BuscarDorsalPage> {
  final _controller = TextEditingController();
  final _api = ApiService();
  List<Map<String, dynamic>>? _resultados;
  final Map<int, Uint8List?> _imagenesCache = {};
  bool _loading = false;
  bool _mostrandoResultados = false;
  String? _error;
  String _eventoNombre = '';
  String? _eventoLogo;

  String _footerUrl = 'https://www.sistemapia.com.ve';
  String _footerText = 'SistemaPIA';
  String _poweredByText = 'Powered by';

  @override
  void initState() {
    super.initState();
    _cargarEvento();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final config = await _api.getConfig();
      if (mounted) {
        setState(() {
          if (config['footerUrl'] != null && config['footerUrl'].toString().isNotEmpty) {
            _footerUrl = config['footerUrl'].toString();
          }
          if (config['footerText'] != null && config['footerText'].toString().isNotEmpty) {
            _footerText = config['footerText'].toString();
          }
          if (config['poweredByText'] != null && config['poweredByText'].toString().isNotEmpty) {
            _poweredByText = config['poweredByText'].toString();
          }
        });
      }
    } catch (e) {
      debugPrint('No se pudo cargar la configuración remota: $e');
    }
  }

  Future<void> _cargarEvento() async {
    final id = widget.idevento;
    if (id == null) {
      setState(() {
        _eventoNombre = '';
        _eventoLogo = null;
      });
      return;
    }
    try {
      final evento = await _api.getEvento(id);
      setState(() {
        _eventoNombre = evento['nombre']?.toString() ?? 'Evento #$id';
        _eventoLogo = evento['logo']?.toString();
      });
    } catch (e) {
      setState(() {
        _eventoNombre = 'Evento #$id';
        _eventoLogo = null;
      });
    }
  }

  void _buscarNuevamente() {
    setState(() {
      _mostrandoResultados = false;
      _resultados = null;
      _error = null;
      _imagenesCache.clear();
      _controller.clear();
    });
  }

  Future<void> _buscar() async {
    final doc = _controller.text.trim();
    if (doc.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _resultados = null;
      _imagenesCache.clear();
    });

    try {
      final res = widget.idevento != null
          ? await _api.buscarDorsalEnEvento(widget.idevento!, doc)
          : await _api.buscarDorsal(doc);
      final items = res.cast<Map<String, dynamic>>();
      setState(() {
        _resultados = items;
        _mostrandoResultados = true;
      });
      for (final item in items) {
        _cargarImagen(int.parse(item['id'].toString()));
      }
    } catch (e) {
      debugPrint('Error al buscar dorsal: $e');
      setState(() {
        _error = 'No se encontraron dorsales para este documento';
        _loading = false;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _compartir(Uint8List bytes, String nombre, int id) async {
    final imgUrl = _api.imagenUrl(id);
    try {
      if (kIsWeb) {
        try {
          await Share.shareXFiles(
            [XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'dorsal_$id.jpg')],
            text: 'Mi dorsal - $nombre\n$imgUrl',
          );
        } catch (_) {
          await Share.share('Mi dorsal - $nombre\n$imgUrl');
        }
      } else {
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/jpeg', name: 'dorsal_$id.jpg')],
          text: 'Mi dorsal - $nombre',
        );
      }
    } catch (e) {
      debugPrint('Error al compartir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir: $e')),
        );
      }
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

  Widget _buildEventoLogo() {
    if (_eventoLogo != null && _eventoLogo!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          _api.eventoLogoUrl(_eventoLogo!),
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildFooterSistemaPia() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: InkWell(
        onTap: () async {
          final url = Uri.parse(_footerUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo_sistemapia.png',
                width: 90,
                height: 56,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _poweredByText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _footerText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: true,
          toolbarHeight: 64,
          automaticallyImplyLeading: false,
          title: widget.idevento != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildEventoLogo(),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _eventoNombre,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Consulta tu inscripción',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.black54),
                    ),
                  ],
                )
              : const Text(''),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.black87),
              tooltip: 'Acerca de',
              onPressed: () => AcercaDeDialog.show(context),
            ),
          ],
        ),
        body: widget.idevento == null
            ? Center(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.red.shade50,
                  ),
                  child: const Text('Debe especificar un ID Evento en el URL',
                      style: TextStyle(fontSize: 16, color: Colors.red)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (!_mostrandoResultados)
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
                    if (_resultados != null && _mostrandoResultados)
                      ...(_resultados!.map((item) {
                        final id = int.parse(item['id'].toString());
                        final bytes = _imagenesCache[id];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            children: [
                              Card(
                                color: Colors.white,
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
                                color: Colors.white,
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
                                        : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (bytes != null)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _compartir(bytes, item['nombre'] ?? 'Participante', id),
                                    icon: const Icon(Icons.share),
                                    label: const Text('Compartir'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      })),
                    if (_mostrandoResultados)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _buscarNuevamente,
                            icon: const Icon(Icons.search),
                            label: const Text('Buscar nuevamente'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    _buildFooterSistemaPia(),
                  ],
                ),
              ),
      ),
    );
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
