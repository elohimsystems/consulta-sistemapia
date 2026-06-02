import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'generar_dorsal_page.dart';

class EventosListPage extends StatefulWidget {
  const EventosListPage({super.key});

  @override
  State<EventosListPage> createState() => _EventosListPageState();
}

class _EventosListPageState extends State<EventosListPage> {
  final _api = ApiService();
  List<dynamic>? _eventos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final eventos = await _api.getEventos();
      final ahora = DateTime.now();
      final filtrados = eventos.where((e) {
        final fechaStr = (e as Map<String, dynamic>)['fecha'];
        final activo = e['activo'] == true;
        if (fechaStr == null || !activo) return false;
        final fecha = DateTime.tryParse(fechaStr.toString());
        return fecha != null && fecha.isAfter(ahora);
      }).toList();
      setState(() { _eventos = filtrados; _loading = false; });
    } catch (e) {
      debugPrint('Error al cargar eventos: $e');
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _eventos == null || _eventos!.isEmpty
              ? const Center(child: Text('No hay eventos'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    itemCount: _eventos!.length,
                    itemBuilder: (ctx, i) {
                      final e = _eventos![i] as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          title: Text(e['nombre'] ?? 'Evento #${e['id']}'),
                          subtitle: Text('ID: ${e['id']}'),
                          trailing: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => GenerarDorsalPage(evento: e)),
                            ),
                            icon: const Icon(Icons.confirmation_number, size: 18),
                            label: const Text('Dorsales'),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
