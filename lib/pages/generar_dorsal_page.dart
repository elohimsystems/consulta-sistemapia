import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class GenerarDorsalPage extends StatefulWidget {
  final Map<String, dynamic> evento;
  const GenerarDorsalPage({super.key, required this.evento});

  @override
  State<GenerarDorsalPage> createState() => _GenerarDorsalPageState();
}

class _GenerarDorsalPageState extends State<GenerarDorsalPage> {
  final _api = ApiService();
  final _picker = ImagePicker();

  static const _camposLabels = {
    'numero': 'Número', 'nombre': 'Nombre', 'iddocumento': 'Documento',
    'sexo': 'Sexo', 'equipo': 'Equipo', 'competencia': 'Competencia', 'categoria': 'Categoría',
  };

  static const _camposDefaults = {
    'numero': {'posicionX': '400', 'posicionY': '200', 'fontSize': '72', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': '123'},
    'nombre': {'posicionX': '400', 'posicionY': '300', 'fontSize': '36', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': 'Nombre Apellido'},
    'iddocumento': {'posicionX': '400', 'posicionY': '350', 'fontSize': '28', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': 'Doc: V-12345678'},
    'sexo': {'posicionX': '400', 'posicionY': '400', 'fontSize': '28', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': 'Sexo: M'},
    'equipo': {'posicionX': '400', 'posicionY': '450', 'fontSize': '28', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': 'Equipo: Nombre'},
    'competencia': {'posicionX': '400', 'posicionY': '500', 'fontSize': '28', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': 'Competencia'},
    'categoria': {'posicionX': '400', 'posicionY': '550', 'fontSize': '28', 'fontFamily': 'sans-serif', 'fontColor': '#000000', 'valor': 'Cat: Categoria'},
  };

  late int _idevento;
  bool _loading = false;
  bool _deleting = false;
  bool _previewLoading = false;
  List<dynamic> _bases = [];
  List<dynamic> _competencias = [];
  List<dynamic> _categorias = [];
  int? _selectedBaseId;
  Uint8List? _previewBytes;
  int _dorsalesExistentes = 0;

  final _camposCheck = <String, bool>{
    'numero': true, 'nombre': true, 'iddocumento': true,
    'sexo': false, 'equipo': false, 'competencia': false, 'categoria': false,
  };

  final _camposConfig = <String, Map<String, TextEditingController>>{};

  String get _camposMostrar => _camposCheck.entries.where((e) => e.value).map((e) => e.key).join(',');

  @override
  void initState() {
    super.initState();
    _idevento = int.parse(widget.evento['id'].toString());
    _initControllers();
    _cargarDatos();
  }

  Future<void> _verificarDorsales() async {
    try {
      final res = await _api.contarDorsales(_idevento);
      setState(() => _dorsalesExistentes = res['total'] ?? 0);
    } catch (e) {
      _dorsalesExistentes = 0;
    }
  }

  void _initControllers() {
    _camposConfig.clear();
    for (final entry in _camposDefaults.entries) {
      _camposConfig[entry.key] = {};
      for (final kv in entry.value.entries) {
        _camposConfig[entry.key]![kv.key] = TextEditingController(text: kv.value);
      }
    }
  }

  Map<String, dynamic>? get _selectedBase {
    try {
      return _bases.firstWhere((b) => int.parse(b['id'].toString()) == _selectedBaseId) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _cargarConfigDesdeBase(Map<String, dynamic>? img) {
    final json = img?['camposConfig'] as Map<String, dynamic>?;
    final camposMostrarStr = (img?['camposMostrar'] as String? ?? 'numero,nombre,iddocumento').split(',');
    for (final k in _camposCheck.keys) {
      _camposCheck[k] = camposMostrarStr.contains(k);
    }
    for (final k in _camposConfig.keys) {
      final saved = json?[k] as Map<String, dynamic>?;
      if (saved != null) {
        _camposConfig[k]!['posicionX']!.text = (saved['posicionX'] ?? _camposDefaults[k]!['posicionX']).toString();
        _camposConfig[k]!['posicionY']!.text = (saved['posicionY'] ?? _camposDefaults[k]!['posicionY']).toString();
        _camposConfig[k]!['fontSize']!.text = (saved['fontSize'] ?? _camposDefaults[k]!['fontSize']).toString();
        _camposConfig[k]!['fontFamily']!.text = saved['fontFamily'] ?? _camposDefaults[k]!['fontFamily']!;
        _camposConfig[k]!['fontColor']!.text = saved['fontColor'] ?? _camposDefaults[k]!['fontColor']!;
        _camposConfig[k]!['valor']!.text = saved['valor'] ?? _camposDefaults[k]!['valor']!;
      } else {
        for (final kv in _camposDefaults[k]!.entries) {
          _camposConfig[k]![kv.key]!.text = kv.value;
        }
      }
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final bases = await _api.getBaseImagenes(_idevento);
      final comps = await _api.getCompetencias(idevento: _idevento);
      final cats = await _api.getCategorias(idevento: _idevento);
      setState(() {
        _bases = bases;
        _competencias = comps;
        _categorias = cats;
        if (bases.isNotEmpty && _selectedBaseId == null) {
          _selectedBaseId = int.parse(bases.first['id'].toString());
          _cargarConfigDesdeBase(bases.first as Map<String, dynamic>);
        }
      });
      await _verificarDorsales();
    } catch (e) {
      debugPrint('Error al cargar datos: $e');
    }
  }

  Map<String, dynamic> _buildCamposConfigPayload() {
    final arr = <Map<String, dynamic>>[];
    for (final k in _camposCheck.keys) {
      if (!_camposCheck[k]!) continue;
      final c = _camposConfig[k]!;
      arr.add({
        'campo': k,
        'posicionX': int.tryParse(c['posicionX']!.text) ?? 400,
        'posicionY': int.tryParse(c['posicionY']!.text) ?? 500,
        'fontSize': int.tryParse(c['fontSize']!.text) ?? 72,
        'fontFamily': c['fontFamily']!.text,
        'fontColor': c['fontColor']!.text,
        'valor': c['valor']!.text,
      });
    }
    return {'camposMostrar': _camposMostrar, 'camposConfig': arr};
  }

  Future<void> _guardarConfig() async {
    final sel = _selectedBase;
    if (sel == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una imagen base primero')));
      return;
    }
    try {
      final jsonConfig = <String, Map<String, dynamic>>{};
      for (final k in _camposConfig.keys) {
        final c = _camposConfig[k]!;
        jsonConfig[k] = {
          'posicionX': int.tryParse(c['posicionX']!.text) ?? 400,
          'posicionY': int.tryParse(c['posicionY']!.text) ?? 500,
          'fontSize': int.tryParse(c['fontSize']!.text) ?? 72,
          'fontFamily': c['fontFamily']!.text,
          'fontColor': c['fontColor']!.text,
          'valor': c['valor']!.text,
        };
      }
      await _api.updateBaseImagen(_selectedBaseId!, {
        'camposMostrar': _camposMostrar,
        'camposConfig': jsonConfig,
      });
      final bases = await _api.getBaseImagenes(_idevento);
      setState(() => _bases = bases);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Config guardada')));
    } catch (e) {
      debugPrint('Error al guardar config: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generarPreview() async {
    if (_selectedBaseId == null) return;
    setState(() => _previewLoading = true);
    try {
      final payload = _buildCamposConfigPayload();
      final bytes = await _api.getPreview(_selectedBaseId!, payload);
      setState(() => _previewBytes = bytes);
    } catch (e) {
      debugPrint('Error al generar preview: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _previewLoading = false);
  }

  Future<void> _subirImagen() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    String? comps, cats, sexos;
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _FiltrosDialog(
        competencias: _competencias,
        categorias: _categorias,
        onResult: (c, ct, s) { comps = c; cats = ct; sexos = s; },
      ),
    );

    try {
      final bytes = await picked.readAsBytes();
      final nueva = await _api.uploadBaseImage(
        idevento: _idevento,
        bytes: bytes,
        filename: picked.name,
        competencias: comps,
        categorias: cats,
        sexos: sexos,
      );
      final bases = await _api.getBaseImagenes(_idevento);
      setState(() {
        _bases = bases;
        _selectedBaseId = int.parse(nueva['id'].toString());
        _cargarConfigDesdeBase(nueva);
        _previewBytes = null;
      });
    } catch (e) {
      debugPrint('Error al subir imagen: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _generar() async {
    setState(() => _loading = true);
    try {
      final res = await _api.generarDorsales(_idevento);
      setState(() => _dorsalesExistentes = res['total'] ?? 0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se generaron ${res['total']} dorsales')));
    } catch (e) {
      debugPrint('Error al generar dorsales: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _loading = false);
  }

  Future<void> _eliminarDorsales() async {
    setState(() => _deleting = true);
    try {
      final res = await _api.eliminarDorsales(_idevento);
      setState(() => _dorsalesExistentes = 0);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['eliminados']} dorsales eliminados')));
    } catch (e) {
      debugPrint('Error al eliminar dorsales: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _deleting = false);
  }

  @override
  void dispose() {
    for (final c in _camposConfig.values) {
      for (final tc in c.values) tc.dispose();
    }
    super.dispose();
  }

  String _nombreImagen(Map<String, dynamic> bm) {
    final nombres = <String>[];
    final comps = bm['competencias'] as String?;
    final cats = bm['categorias'] as String?;
    final sexo = bm['sexos'] as String?;
    if (comps != null && comps.isNotEmpty) {
      for (final c in _competencias) {
        final cm = c as Map<String, dynamic>;
        if (comps.split(',').map((s) => s.trim()).contains(cm['id'].toString())) {
          nombres.add(cm['descripcion']?.toString() ?? cm['id'].toString());
        }
      }
    }
    if (cats != null && cats.isNotEmpty) {
      for (final c in _categorias) {
        final cm = c as Map<String, dynamic>;
        if (cats.split(',').map((s) => s.trim()).contains(cm['id'].toString())) {
          nombres.add(cm['descripcion']?.toString() ?? cm['id'].toString());
        }
      }
    }
    if (sexo != null && sexo.isNotEmpty) nombres.add('Sexo: $sexo');
    return nombres.isNotEmpty ? nombres.join(', ') : 'Imagen #${bm['id']}';
  }

  @override
  Widget build(BuildContext context) {
    final evento = widget.evento;
    final sel = _selectedBase;
    return Scaffold(
      appBar: AppBar(title: Text('Dorsales: ${evento['nombre'] ?? evento['id']}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Imágenes base', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(onPressed: _subirImagen, icon: const Icon(Icons.add_photo_alternate), label: const Text('Agregar imagen base')),
                    const SizedBox(height: 8),
                    if (_bases.isEmpty)
                      const Text('No hay imágenes cargadas', style: TextStyle(color: Colors.grey))
                    else
                      ...(_bases.map((b) {
                        final bm = b as Map<String, dynamic>;
                        final id = int.parse(bm['id'].toString());
                        final isSelected = id == _selectedBaseId;
                        return Card(
                          color: isSelected ? Colors.blue.shade50 : null,
                          child: ListTile(
                            leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? Colors.blue : null),
                            title: Text(_nombreImagen(bm)),
                            subtitle: Text([
                              if (bm['competencias'] != null) 'Comp: ${bm['competencias']}',
                              if (bm['categorias'] != null) 'Cat: ${bm['categorias']}',
                              if (bm['sexos'] != null) 'Sexo: ${bm['sexos']}',
                            ].join(', ')),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _api.deleteBaseImagen(id);
                                final bases = await _api.getBaseImagenes(_idevento);
                                setState(() {
                                  _bases = bases;
                                  if (_selectedBaseId == id) {
                                    _selectedBaseId = bases.isNotEmpty ? int.parse(bases.first['id'].toString()) : null;
                                  }
                                });
                              },
                            ),
                            onTap: () {
                              setState(() {
                                _selectedBaseId = id;
                                _cargarConfigDesdeBase(bm);
                                _previewBytes = null;
                              });
                            },
                          ),
                        );
                      })),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (sel != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Configuración — Imagen #${sel['id']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Campos activos:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 4,
                        children: _camposCheck.keys.map((k) {
                          return FilterChip(
                            label: Text(_camposLabels[k] ?? k, style: const TextStyle(fontSize: 13)),
                            selected: _camposCheck[k]!,
                            onSelected: (v) => setState(() => _camposCheck[k] = v),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      ..._camposCheck.entries.where((e) => e.value).map((e) {
                        final k = e.key;
                        final c = _camposConfig[k]!;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(_camposLabels[k] ?? k, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: TextField(controller: c['valor'], decoration: const InputDecoration(labelText: 'Valor', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), style: const TextStyle(fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(controller: c['posicionX'], decoration: const InputDecoration(labelText: 'X', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(controller: c['posicionY'], decoration: const InputDecoration(labelText: 'Y', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(controller: c['fontSize'], decoration: const InputDecoration(labelText: 'Tamaño', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: TextField(controller: c['fontFamily'], decoration: const InputDecoration(labelText: 'Fuente', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), style: const TextStyle(fontSize: 12)),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: TextField(controller: c['fontColor'], decoration: const InputDecoration(labelText: 'Color', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8)), style: const TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: ElevatedButton(onPressed: _guardarConfig, child: const Text('Guardar Config'))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _previewLoading ? null : _generarPreview,
                            icon: _previewLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.visibility),
                            label: const Text('Vista Previa'),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_previewBytes != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vista previa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_previewBytes!, fit: BoxFit.contain, width: double.infinity),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_loading || _bases.isEmpty || _dorsalesExistentes > 0) ? null : _generar,
                icon: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: Text(_loading ? 'Generando...' : 'Generar Dorsales'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
            if (_dorsalesExistentes > 0) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('$_dorsalesExistentes dorsales generados', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      ElevatedButton.icon(
                        onPressed: _deleting ? null : _eliminarDorsales,
                        icon: _deleting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.delete_forever, color: Colors.red),
                        label: Text(_deleting ? 'Eliminando...' : 'Borrar Dorsales', style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FiltrosDialog extends StatefulWidget {
  final List<dynamic> competencias;
  final List<dynamic> categorias;
  final void Function(String? comps, String? cats, String? sexos) onResult;

  const _FiltrosDialog({required this.competencias, required this.categorias, required this.onResult});

  @override
  State<_FiltrosDialog> createState() => _FiltrosDialogState();
}

class _FiltrosDialogState extends State<_FiltrosDialog> {
  final _compSelecteds = <int>{};
  final _catSelecteds = <int>{};
  String _sexo = '';
  final _sexos = ['', 'M', 'F'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Asociar imagen a:'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Competencias (opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
            ...widget.competencias.map((c) {
              final cm = c as Map<String, dynamic>;
              return CheckboxListTile(
                dense: true,
                title: Text(cm['descripcion'] ?? '#${cm['id']}'),
                value: _compSelecteds.contains(int.parse(cm['id'].toString())),
                onChanged: (v) { setState(() { v == true ? _compSelecteds.add(int.parse(cm['id'].toString())) : _compSelecteds.remove(int.parse(cm['id'].toString())); }); },
              );
            }),
            const Divider(),
            const Text('Categorías (opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
            ...widget.categorias.map((c) {
              final cm = c as Map<String, dynamic>;
              return CheckboxListTile(
                dense: true,
                title: Text(cm['descripcion'] ?? '#${cm['id']}'),
                value: _catSelecteds.contains(int.parse(cm['id'].toString())),
                onChanged: (v) { setState(() { v == true ? _catSelecteds.add(int.parse(cm['id'].toString())) : _catSelecteds.remove(int.parse(cm['id'].toString())); }); },
              );
            }),
            const Divider(),
            const Text('Sexo (opcional):', style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _sexo,
              isExpanded: true,
              items: _sexos.map((s) => DropdownMenuItem(value: s, child: Text(s.isEmpty ? 'Todos' : s))).toList(),
              onChanged: (v) => setState(() => _sexo = v ?? ''),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () {
            widget.onResult(
              _compSelecteds.isEmpty ? null : _compSelecteds.join(','),
              _catSelecteds.isEmpty ? null : _catSelecteds.join(','),
              _sexo.isEmpty ? null : _sexo,
            );
            Navigator.pop(context);
          },
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
