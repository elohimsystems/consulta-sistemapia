import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String _companyUrl = 'https://www.elohimsystems.com';

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final cfg = await _api.getConfig();
      if (mounted && cfg['companyUrl'] != null && cfg['companyUrl'].toString().isNotEmpty) {
        setState(() => _companyUrl = cfg['companyUrl'].toString());
      }
    } catch (e) {
      debugPrint('Error al cargar configuración remota: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Column(
        children: [
          Image.asset(
            'assets/images/logo_sistemapia.png',
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.info_outline, size: 48, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 8),
          Text(AppInfo.nombre, style: theme.textTheme.headlineSmall),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _item('Versión', AppInfo.version),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 80,
                child: Text('Empresa', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final url = Uri.parse(_companyUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    AppInfo.empresa,
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Desarrolladores', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          ...AppInfo.desarrolladores.map((d) => Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Text('• $d'),
          )),
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
