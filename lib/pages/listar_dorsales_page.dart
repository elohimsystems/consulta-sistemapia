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
  int _pageSize = 20;
  int _sortCol = -1;
  bool _sortAsc = true;
  final Set<int> _selectedIds = {};
  bool _sendingEmail = false;
  bool _sendingTodos = false;
  bool _showEnviarTodos = true;

  List<Map<String, dynamic>> get _filteredItems {
    var items = _items;
    if (_filter.isNotEmpty) {
      final f = _filter.toLowerCase();
      items = items.where((item) =>
        (item['nombre']?.toString().toLowerCase().contains(f) ?? false) ||
        (item['iddocumento']?.toString().toLowerCase().contains(f) ?? false) ||
        (item['numero']?.toString().toLowerCase().contains(f) ?? false) ||
        (item['competencia']?.toString().toLowerCase().contains(f) ?? false) ||
        (item['categoria']?.toString().toLowerCase().contains(f) ?? false) ||
        ((item['emailpersonal'] ?? item['email'] ?? '').toString().toLowerCase().contains(f))
      ).toList();
    }
    if (_sortCol >= 2) {
      items.sort((a, b) {
        final keys = ['', '', 'nombre', 'iddocumento', 'email', 'numero', 'competencia', 'categoria', 'enviado'];
        final k = keys[_sortCol];
        String va(String v) => v.toString().toLowerCase();
        if (_sortCol == 5) {
          final na = (a[k] as num?)?.toInt() ?? 0;
          final nb = (b[k] as num?)?.toInt() ?? 0;
          return _sortAsc ? na.compareTo(nb) : nb.compareTo(na);
        }
        if (_sortCol == 8) {
          int orden(v) => v == true ? 2 : v == false ? 1 : 0;
          final ba = orden(a['enviado']);
          final bb = orden(b['enviado']);
          return _sortAsc ? ba.compareTo(bb) : bb.compareTo(ba);
        }
        if (_sortCol == 4) {
          final ea = (a['emailpersonal'] ?? a['email'] ?? '').toString().toLowerCase();
          final eb = (b['emailpersonal'] ?? b['email'] ?? '').toString().toLowerCase();
          return _sortAsc ? ea.compareTo(eb) : eb.compareTo(ea);
        }
        return _sortAsc
            ? va(a[k] ?? '').compareTo(va(b[k] ?? ''))
            : va(b[k] ?? '').compareTo(va(a[k] ?? ''));
      });
    }
    return items;
  }

  int get _pageCount => (_filteredItems.length / _pageSize).ceil().clamp(1, 9999);

  List<Map<String, dynamic>> get _paginatedItems {
    final start = _currentPage * _pageSize;
    return _filteredItems.skip(start).take(_pageSize).toList();
  }

  void _sortBy(int col) {
    setState(() {
      if (_sortCol == col) {
        _sortAsc = !_sortAsc;
      } else {
        _sortCol = col;
        _sortAsc = true;
      }
    });
  }

  void _toggleSel(int id) {
    setState(() { _selectedIds.contains(id) ? _selectedIds.remove(id) : _selectedIds.add(id); });
  }

  void _selectAll() {
    setState(() { _selectedIds.addAll(_paginatedItems.map((e) => int.parse(e['id'].toString()))); });
  }

  void _clearSel() {
    setState(() => _selectedIds.clear());
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page.clamp(0, _pageCount - 1));
  }

  Future<void> _desmarcarEnviado(int id) async {
    try {
      await _api.desmarcarEnviadoDorsal(id);
      setState(() {
        final idx = _items.indexWhere((it) => int.parse(it['id'].toString()) == id);
        if (idx >= 0) _items[idx]['enviado'] = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pollTask(String taskId) async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final status = await _api.getEmailTaskStatus(taskId);
        if (status['status'] == 'completed') {
          final enviados = status['enviados'] ?? 0;
          final fallidos = (status['fallidos'] as List?) ?? [];
          final omitidos = fallidos.where(
            (f) => (f['error'] as String?)?.contains('ya fue enviado') == true,
          ).length;
          final realFallidos = fallidos.length - omitidos;
          if (mounted) {
            await _cargar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                realFallidos > 0
                    ? 'Enviados: $enviados. Fallidos: $realFallidos. Omitidos: $omitidos.'
                    : 'Enviados: $enviados. Omitidos: $omitidos.',
              ),
              duration: Duration(seconds: 4),
            ));
          }
          break;
        }
      } catch (_) {}
    }
  }

  Future<void> _enviarEmail() async {
    final ids = _selectedIds.toList();
    final yaEnviados = ids.where((id) => _items.any((it) => int.parse(it['id'].toString()) == id && it['enviado'] == true)).length;
    final subjectCtl = TextEditingController();
    final msgCtl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar dorsal por correo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${ids.length} seleccionado(s)'),
            if (yaEnviados > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('$yaEnviados ya fueron enviados antes y serán omitidos', style: const TextStyle(color: Colors.orange, fontSize: 13))),
            const SizedBox(height: 12),
            TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Asunto', border: OutlineInputBorder()), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()), maxLines: 4),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (result != true || subjectCtl.text.trim().isEmpty) return;
    setState(() => _sendingEmail = true);
    try {
      final res = await _api.enviarEmailDorsales(
        ids: ids,
        subject: subjectCtl.text.trim(),
        message: msgCtl.text.trim(),
      );
      final taskId = res['task_id'];
      if (taskId != null) {
        _pollTask(taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando correos en segundo plano...')));
          setState(() => _sendingEmail = false);
        }
      }
      _cargar();
      _clearSel();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _sendingEmail = false);
    }
  }

  Future<void> _enviarTodos() async {
    final subjectCtl = TextEditingController();
    final msgCtl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar todos los dorsales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${_items.length} dorsal(es) en total'),
            if (_items.any((it) => it['enviado'] == true))
              const Padding(padding: EdgeInsets.only(top: 8), child: Text('Los ya enviados serán omitidos', style: TextStyle(color: Colors.orange, fontSize: 13))),
            const SizedBox(height: 12),
            TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Asunto', border: OutlineInputBorder()), autofocus: true),
            const SizedBox(height: 12),
            TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()), maxLines: 4),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar todos')),
        ],
      ),
    );
    if (result != true || subjectCtl.text.trim().isEmpty) return;
    setState(() => _sendingTodos = true);
    try {
      final res = await _api.enviarTodosDorsales(
        idevento: widget.idevento,
        subject: subjectCtl.text.trim(),
        message: msgCtl.text.trim(),
      );
      final taskId = res['task_id'];
      if (taskId != null) {
        _pollTask(taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando todos los correos en segundo plano...')));
        }
      }
      _cargar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sendingTodos = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarConfig();
    _cargar();
  }

  Future<void> _cargarConfig() async {
    try {
      final config = await _api.getConfig();
      final pantalla = config['listarDorsales'] as Map<String, dynamic>? ?? {};
      if (mounted) setState(() {
        _showEnviarTodos = pantalla['showEnviarTodos'] ?? true;
        _pageSize = pantalla['pageSize'] ?? 20;
      });
    } catch (_) {}
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getDorsalesList(widget.idevento);
      final items = res.cast<Map<String, dynamic>>();
      items.sort((a, b) => ((a['numero'] as num?)?.toInt() ?? 0).compareTo((b['numero'] as num?)?.toInt() ?? 0));
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
    const _cols = ['', 'Dorsal', 'Nombre', 'Cédula', 'Email', 'Nro', 'Competencia', 'Categoría', 'Enviado'];
    const _imgWidth = 60.0;
    const _selWidth = 36.0;
    const _envWidth = 50.0;
    const _colFracts = [0.20, 0.16, 0.20, 0.09, 0.16, 0.14];
    final tableWidth = MediaQuery.of(context).size.width * 0.80;
    final restWidth = tableWidth - _imgWidth - _selWidth - _envWidth;
    final colWidths = [_selWidth, _imgWidth, ..._colFracts.map((f) => restWidth * f), _envWidth];

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
                          child: Row(
                            children: [
                              Expanded(
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
                              if (_showEnviarTodos) const SizedBox(width: 8),
                              if (_showEnviarTodos)
                                ElevatedButton.icon(
                                  icon: _sendingTodos
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.mail_outline, size: 18),
                                  label: Text(_sendingTodos ? 'Enviando...' : 'Enviar todos', style: const TextStyle(fontSize: 12)),
                                  onPressed: (_sendingTodos || _items.isEmpty) ? null : _enviarTodos,
                                ),
                            ],
                          ),
                        ),
                        if (_selectedIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Text('${_selectedIds.length} seleccionado(s)', style: const TextStyle(fontSize: 13)),
                                const Spacer(),
                                TextButton.icon(
                                  icon: const Icon(Icons.deselect, size: 18),
                                  label: const Text('Quitar selección', style: TextStyle(fontSize: 12)),
                                  onPressed: _clearSel,
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: _sendingEmail
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.email, size: 18),
                                  label: Text(_sendingEmail ? 'Enviando...' : 'Enviar por correo', style: const TextStyle(fontSize: 12)),
                                  onPressed: (_sendingEmail || _selectedIds.isEmpty) ? null : _enviarEmail,
                                ),
                              ],
                            ),
                          ),
                        Container(
                          color: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: colWidths[0],
                                child: Checkbox(
                                  value: _paginatedItems.isNotEmpty && _selectedIds.containsAll(_paginatedItems.map((e) => int.parse(e['id'].toString()))),
                                  onChanged: (_) {
                                    final allSel = _paginatedItems.every((e) => _selectedIds.contains(int.parse(e['id'].toString())));
                                    allSel ? _clearSel() : _selectAll();
                                  },
                                ),
                              ),
                              ...List.generate(_cols.length - 1, (i) {
                                final colIdx = i + 1;
                                final isSorted = _sortCol == colIdx;
                                return SizedBox(
                                  width: colWidths[colIdx],
                                  child: GestureDetector(
                                    onTap: colIdx >= 2 ? () => _sortBy(colIdx) : null,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _cols[colIdx],
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isSorted ? Colors.blue.shade700 : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSorted)
                                          Icon(
                                            _sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                                            size: 14,
                                            color: Colors.blue.shade700,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        if (_paginatedItems.isEmpty)
                          const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Sin resultados'))),
                        ..._paginatedItems.map((item) {
                          final id = int.parse(item['id'].toString());
                          final bytes = _imagenesCache[id];
                          final sel = _selectedIds.contains(id);
                          final enviado = item['enviado'];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                              color: sel ? Colors.blue.shade50 : null,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: colWidths[0],
                                  child: Checkbox(value: sel, onChanged: (_) => _toggleSel(id)),
                                ),
                                SizedBox(
                                  width: colWidths[1],
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
                                SizedBox(width: colWidths[2], child: Text(item['nombre'] ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[3], child: Text(item['iddocumento'] ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(
                                  width: colWidths[4],
                                  child: Text(
                                    (item['emailpersonal'] ?? item['email'] ?? ''),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: colWidths[5], child: Text(item['numero']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[6], child: Text(item['competencia'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                SizedBox(width: colWidths[7], child: Text(item['categoria'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                SizedBox(
                                  width: colWidths[8],
                                  child: enviado == true
                                      ? Checkbox(value: true, onChanged: (_) => _desmarcarEnviado(id))
                                      : enviado == false
                                          ? const Icon(Icons.cancel, color: Colors.red, size: 18)
                                          : const Icon(Icons.hourglass_empty, color: Colors.grey, size: 18),
                                ),
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
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _filteredItems.isEmpty
                                ? '0 registros'
                                : 'Mostrando del ${_currentPage * _pageSize + 1} al ${((_currentPage + 1) * _pageSize).clamp(0, _filteredItems.length)} de ${_filteredItems.length} registros',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
