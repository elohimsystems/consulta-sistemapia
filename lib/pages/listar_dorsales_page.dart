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
  final _filterController = TextEditingController();
  String _filter = '';
  int _currentPage = 0;
  static const _pageSize = 20;

  List<Map<String, dynamic>> get _filteredItems {
    if (_filter.isEmpty) return _items;
    final f = _filter.toLowerCase();
    return _items.where((item) =>
      (item['nombre']?.toString().toLowerCase().contains(f) ?? false) ||
      (item['iddocumento']?.toString().toLowerCase().contains(f) ?? false) ||
      (item['numero']?.toString().toLowerCase().contains(f) ?? false) ||
      (item['competencia']?.toString().toLowerCase().contains(f) ?? false) ||
      (item['categoria']?.toString().toLowerCase().contains(f) ?? false)
    ).toList();
  }

  int get _pageCount => (_filteredItems.length / _pageSize).ceil().clamp(1, 9999);

  List<Map<String, dynamic>> get _paginatedItems {
    final start = _currentPage * _pageSize;
    return _filteredItems.skip(start).take(_pageSize).toList();
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page.clamp(0, _pageCount - 1));
  }

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
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const _cols = ['Dorsal', 'Nombre', 'Cédula', 'Nro', 'Competencia', 'Categoría'];
    const _imgWidth = 60.0;
    const _colFracts = [0.26, 0.22, 0.12, 0.21, 0.19];
    final tableWidth = MediaQuery.of(context).size.width * 0.80;
    final restWidth = tableWidth - _imgWidth;
    final colWidths = [_imgWidth, ..._colFracts.map((f) => restWidth * f)];

    return Scaffold(
      appBar: AppBar(title: Text('Dorsales - ${widget.eventoNombre}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No hay dorsales generados'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final table = SizedBox(
                      width: tableWidth,
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                          child: TextField(
                            controller: _filterController,
                            decoration: InputDecoration(
                              hintText: 'Filtrar...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              suffixIcon: _filter.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _filterController.clear(); setState(() => _filter = ''); })
                                  : null,
                            ),
                            onChanged: (v) { setState(() { _filter = v; _currentPage = 0; }); },
                          ),
                        ),
                        Container(
                          color: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: List.generate(_cols.length, (i) {
                              return SizedBox(
                                width: colWidths[i],
                                child: Text(_cols[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              );
                            }),
                          ),
                        ),
                        if (_paginatedItems.isEmpty)
                          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Sin resultados'))),
                        ..._paginatedItems.map((item) {
                          final id = int.parse(item['id'].toString());
                          final bytes = _imagenesCache[id];
                          return Container(
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: colWidths[0],
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: SizedBox(
                                      height: 50,
                                      child: bytes != null
                                          ? ClipRRect(child: Image.memory(bytes, fit: BoxFit.fitWidth))
                                          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                  ),
                                ),
                                SizedBox(width: colWidths[1], child: Text(item['nombre'] ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[2], child: Text(item['iddocumento'] ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[3], child: Text(item['numero']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[4], child: Text(item['competencia'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                SizedBox(width: colWidths[5], child: Text(item['categoria'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                              ],
                            ),
                          );
                        }),
                        if (_pageCount > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left),
                                  onPressed: _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
                                ),
                                ...List.generate(_pageCount, (i) {
                                  final isCurrent = i == _currentPage;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2),
                                    child: ChoiceChip(
                                      label: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                                      selected: isCurrent,
                                      onSelected: (_) => _goToPage(i),
                                    ),
                                  );
                                }),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _currentPage < _pageCount - 1 ? () => _goToPage(_currentPage + 1) : null,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ));
                    if (tableWidth <= constraints.maxWidth) {
                      return RefreshIndicator(
                        onRefresh: _cargar,
                        child: SingleChildScrollView(
                          child: Center(child: table),
                        ),
                      );
                    } else {
                      return RefreshIndicator(
                        onRefresh: _cargar,
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: table,
                          ),
                        ),
                      );
                    }
                  },
                ),
    );
  }
}
