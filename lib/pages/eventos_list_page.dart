import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../widgets/acerca_de_dialog.dart';
import 'generar_dorsal_page.dart';
import 'notificar_page.dart';

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
      final eventos = await _api.getEventosActivos();
      setState(() { _eventos = eventos; _loading = false; });
    } catch (e) {
      debugPrint('Error al cargar eventos: $e');
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Eventos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Acerca de',
            onPressed: () => AcercaDeDialog.show(context),
          ),
        ],
      ),
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
                          subtitle: Row(
                            children: [
                              Text('ID: ${e['id']}'),
                              const SizedBox(width: 4),
                              InkWell(
                                child: Icon(Icons.copy, size: 14, color: Colors.grey.shade600),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: e['id'].toString()));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('ID copiado'), duration: Duration(seconds: 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => NotificarPage(
                                    idevento: int.parse(e['id'].toString()),
                                    eventoNombre: e['nombre'] ?? '',
                                  )),
                                ),
                                icon: const Icon(Icons.notifications, size: 18),
                                label: const Text('Notificar'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => GenerarDorsalPage(evento: e)),
                                ),
                                icon: const Icon(Icons.confirmation_number, size: 18),
                                label: const Text('Dorsales'),
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
