import 'package:flutter/material.dart';
import '../constants/app_info.dart';
import '../services/api_service.dart';

class AcercaDeDialog extends StatefulWidget {
  const AcercaDeDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const AcercaDeDialog(),
    );
  }

  @override
  State<AcercaDeDialog> createState() => _AcercaDeDialogState();
}

class _AcercaDeDialogState extends State<AcercaDeDialog> {
  final _api = ApiService();
  Map<String, dynamic>? _apiVersion;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarVersionApi();
  }

  Future<void> _cargarVersionApi() async {
    try {
      final v = await _api.getVersion();
      if (mounted) setState(() => _apiVersion = v);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo conectar con la API');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final compatible = _apiVersion != null
        ? _esCompatible(_apiVersion!['version'] as String, AppInfo.minApiVersion)
        : null;

    return AlertDialog(
      title: Column(
        children: [
          Icon(Icons.info_outline, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(AppInfo.nombre, style: theme.textTheme.headlineSmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _item('App', AppInfo.version),
          const SizedBox(height: 8),
          _item(
            'API',
            _apiVersion != null
                ? _apiVersion!['version'] as String
                : (_error ?? 'Cargando...'),
          ),
          const SizedBox(height: 8),
          _item('API mínima', AppInfo.minApiVersion),
          const SizedBox(height: 8),
          _item('Empresa', AppInfo.empresa),
          const SizedBox(height: 12),
          Text('Desarrolladores', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          ...AppInfo.desarrolladores.map((d) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text('• $d'),
          )),
          if (compatible == false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La versión de la API no es compatible con esta versión de la app. Actualiza la app o la API.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  bool _esCompatible(String versionActual, String versionMinima) {
    final vAct = versionActual.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final vMin = versionMinima.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final a = i < vAct.length ? vAct[i] : 0;
      final m = i < vMin.length ? vMin[i] : 0;
      if (a < m) return false;
      if (a > m) return true;
    }
    return true;
  }

  Widget _item(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
