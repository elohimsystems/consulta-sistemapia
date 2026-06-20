import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';

class NotificarPage extends StatefulWidget {
  final int idevento;
  final String eventoNombre;
  const NotificarPage({super.key, required this.idevento, this.eventoNombre = ''});

  @override
  State<NotificarPage> createState() => _NotificarPageState();
}

class _NotificarPageState extends State<NotificarPage> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _filterController = TextEditingController();
  String _filter = '';
  int _currentPage = 0;
  int _pageSize = 20;
  int _sortCol = -1;
  bool _sortAsc = true;
  final Set<int> _selectedIds = {};
  bool _sending = false;

  List<Map<String, dynamic>> get _filteredItems {
    var items = _items;
    if (_filter.isNotEmpty) {
      final f = _filter.toLowerCase();
      items = items.where((item) {
        final comp = item['competidor'] as Map<String, dynamic>? ?? {};
        final nombre = '${comp['nombre'] ?? ''} ${comp['apellido'] ?? ''}'.toLowerCase();
        final doc = (comp['iddocumento'] ?? '').toString().toLowerCase();
        final email = (comp['emailpersonal'] ?? comp['email'] ?? '').toString().toLowerCase();
        final numero = (item['numero']?.toString() ?? '').toLowerCase();
        final competencia = (item['competencia'] is Map ? (item['competencia'] as Map)['descripcion']?.toString() ?? '' : '').toLowerCase();
        final categoria = (item['categoria'] is Map ? (item['categoria'] as Map)['descripcion']?.toString() ?? '' : '').toLowerCase();
        final estatus = (item['estatus']?.toString() ?? '').toLowerCase();
        return nombre.contains(f) || doc.contains(f) || email.contains(f) || numero.contains(f) || competencia.contains(f) || categoria.contains(f) || estatus.contains(f);
      }).toList();
    }
    if (_sortCol >= 0) {
      items.sort((a, b) {
        final compA = a['competidor'] as Map<String, dynamic>? ?? {};
        final compB = b['competidor'] as Map<String, dynamic>? ?? {};
        int compareStr(String va, String vb) => _sortAsc ? va.compareTo(vb) : vb.compareTo(va);
        switch (_sortCol) {
          case 0:
            return compareStr('${compA['nombre'] ?? ''} ${compA['apellido'] ?? ''}', '${compB['nombre'] ?? ''} ${compB['apellido'] ?? ''}');
          case 1:
            return compareStr(compA['iddocumento']?.toString() ?? '', compB['iddocumento']?.toString() ?? '');
          case 2:
            return compareStr((compA['emailpersonal'] ?? compA['email'] ?? '').toString(), (compB['emailpersonal'] ?? compB['email'] ?? '').toString());
          case 3: {
            final na = (a['numero'] as num?)?.toInt() ?? 0;
            final nb = (b['numero'] as num?)?.toInt() ?? 0;
            return _sortAsc ? na.compareTo(nb) : nb.compareTo(na);
          }
          case 4:
            return compareStr(a['competencia'] is Map ? (a['competencia'] as Map)['descripcion']?.toString() ?? '' : '', b['competencia'] is Map ? (b['competencia'] as Map)['descripcion']?.toString() ?? '' : '');
          case 5:
            return compareStr(a['categoria'] is Map ? (a['categoria'] as Map)['descripcion']?.toString() ?? '' : '', b['categoria'] is Map ? (b['categoria'] as Map)['descripcion']?.toString() ?? '' : '');
          case 6:
            return compareStr(a['estatus']?.toString() ?? '', b['estatus']?.toString() ?? '');
          default:
            return 0;
        }
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

  Future<void> _pollTask(String taskId) async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final status = await _api.getNotificacionTaskStatus(taskId);
        if (status['status'] == 'completed') {
          final enviados = status['enviados'] ?? 0;
          final fallidos = (status['fallidos'] as List?) ?? [];
          if (mounted) {
            await _cargar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                fallidos.isNotEmpty
                    ? 'Enviados: $enviados. Fallidos: ${fallidos.length}.'
                    : 'Enviados: $enviados.',
              ),
              duration: const Duration(seconds: 4),
            ));
          }
          break;
        }
      } catch (_) {}
    }
  }

  Future<void> _enviarSeleccionados() async {
    final ids = _selectedIds.toList();
    final subjectCtl = TextEditingController();
    final msgCtl = TextEditingController();
    Uint8List? archivoBytes;
    String? archivoName;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Enviar notificación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${ids.length} seleccionado(s)'),
                const SizedBox(height: 12),
                TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Asunto', border: OutlineInputBorder()), autofocus: true),
                const SizedBox(height: 12),
                TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()), maxLines: 4),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text(archivoName != null ? 'Cambiar archivo' : 'Adjuntar archivo'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp'],
                          withData: true,
                        );
                        if (result != null && result.files.single.bytes != null) {
                          setDialogState(() {
                            archivoBytes = result.files.single.bytes;
                            archivoName = result.files.single.name;
                          });
                        }
                      },
                    ),
                    if (archivoName != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(archivoName!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setDialogState(() { archivoBytes = null; archivoName = null; }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar')),
          ],
        ),
      ),
    );

    if (result != true || subjectCtl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final res = await _api.enviarNotificacion(
        ids: ids,
        subject: subjectCtl.text.trim(),
        message: msgCtl.text.trim(),
        archivoBytes: archivoBytes,
        archivoName: archivoName,
      );
      final taskId = res['task_id'];
      if (taskId != null) {
        _pollTask(taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando correos en segundo plano...')));
        }
      }
      _clearSel();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _enviarTodos() async {
    final subjectCtl = TextEditingController();
    final msgCtl = TextEditingController();
    Uint8List? archivoBytes;
    String? archivoName;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Enviar notificación a todos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${_items.length} participante(s) en total'),
                const SizedBox(height: 12),
                TextField(controller: subjectCtl, decoration: const InputDecoration(labelText: 'Asunto', border: OutlineInputBorder()), autofocus: true),
                const SizedBox(height: 12),
                TextField(controller: msgCtl, decoration: const InputDecoration(labelText: 'Mensaje', border: OutlineInputBorder()), maxLines: 4),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text(archivoName != null ? 'Cambiar archivo' : 'Adjuntar archivo'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp'],
                          withData: true,
                        );
                        if (result != null && result.files.single.bytes != null) {
                          setDialogState(() {
                            archivoBytes = result.files.single.bytes;
                            archivoName = result.files.single.name;
                          });
                        }
                      },
                    ),
                    if (archivoName != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(archivoName!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setDialogState(() { archivoBytes = null; archivoName = null; }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enviar a todos')),
          ],
        ),
      ),
    );

    if (result != true || subjectCtl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      final res = await _api.enviarNotificacionTodos(
        idevento: widget.idevento,
        subject: subjectCtl.text.trim(),
        message: msgCtl.text.trim(),
        archivoBytes: archivoBytes,
        archivoName: archivoName,
      );
      final taskId = res['task_id'];
      if (taskId != null) {
        _pollTask(taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enviando correos en segundo plano...')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getInscritosPorEvento(widget.idevento);
      setState(() { _items = res.cast<Map<String, dynamic>>(); _loading = false; });
    } catch (e) {
      debugPrint('Error al cargar inscritos: $e');
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  String _nombre(Map<String, dynamic> item) {
    final comp = item['competidor'] as Map<String, dynamic>?;
    if (comp == null) return '';
    return '${comp['nombre'] ?? ''} ${comp['apellido'] ?? ''}'.trim();
  }

  String _documento(Map<String, dynamic> item) {
    return (item['competidor'] as Map<String, dynamic>?)?['iddocumento']?.toString() ?? '';
  }

  String _email(Map<String, dynamic> item) {
    final comp = item['competidor'] as Map<String, dynamic>?;
    return (comp?['emailpersonal'] ?? comp?['email'] ?? '').toString();
  }

  String _competencia(Map<String, dynamic> item) {
    final comp = item['competencia'];
    return comp is Map ? (comp['descripcion']?.toString() ?? '') : '';
  }

  String _categoria(Map<String, dynamic> item) {
    final cat = item['categoria'];
    return cat is Map ? (cat['descripcion']?.toString() ?? '') : '';
  }

  String _estatus(Map<String, dynamic> item) {
    return item['estatus']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    const _cols = ['Nombre', 'Cédula', 'Email', 'Nro', 'Competencia', 'Categoría', 'Estatus'];
    const _selWidth = 36.0;
    final tableWidth = MediaQuery.of(context).size.width * 0.85;
    final colWidths = [_selWidth, ...List.generate(_cols.length, (i) => (tableWidth - _selWidth) / _cols.length)];

    return Scaffold(
      appBar: AppBar(title: Text('Notificar - ${widget.eventoNombre}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No hay participantes inscritos'))
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
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: _sending
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.mail_outline, size: 18),
                                label: Text(_sending ? 'Enviando...' : 'Enviar todos', style: const TextStyle(fontSize: 12)),
                                onPressed: (_sending || _items.isEmpty) ? null : _enviarTodos,
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
                                  icon: _sending
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.email, size: 18),
                                  label: Text(_sending ? 'Enviando...' : 'Enviar por correo', style: const TextStyle(fontSize: 12)),
                                  onPressed: (_sending || _selectedIds.isEmpty) ? null : _enviarSeleccionados,
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
                              ...List.generate(_cols.length, (i) {
                                final isSorted = _sortCol == i;
                                return SizedBox(
                                  width: colWidths[i + 1],
                                  child: GestureDetector(
                                    onTap: () => _sortBy(i),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _cols[i],
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
                          final sel = _selectedIds.contains(id);
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
                                SizedBox(width: colWidths[1], child: Text(_nombre(item), style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[2], child: Text(_documento(item), style: const TextStyle(fontSize: 12))),
                                SizedBox(
                                  width: colWidths[3],
                                  child: Text(
                                    _email(item),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: colWidths[4], child: Text(item['numero']?.toString() ?? '', style: const TextStyle(fontSize: 12))),
                                SizedBox(width: colWidths[5], child: Text(_competencia(item), style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                SizedBox(width: colWidths[6], child: Text(_categoria(item), style: const TextStyle(fontSize: 12, color: Colors.grey))),
                                SizedBox(width: colWidths[7], child: Text(_estatus(item), style: const TextStyle(fontSize: 12))),
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
                                const SizedBox(width: 8),
                                Text('Pág. ${_currentPage + 1}', style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right),
                                  onPressed: _currentPage < _pageCount - 1 ? () => _goToPage(_currentPage + 1) : null,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  height: 36,
                                  child: DropdownButton<int>(
                                    value: _currentPage,
                                    isDense: true,
                                    underline: const SizedBox(),
                                    items: List.generate(_pageCount, (i) => DropdownMenuItem(value: i, child: Text('${i + 1}', style: const TextStyle(fontSize: 13)))),
                                    onChanged: (v) { if (v != null) _goToPage(v); },
                                  ),
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
