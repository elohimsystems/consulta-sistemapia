import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ConfigMailPage extends StatefulWidget {
  const ConfigMailPage({super.key});

  @override
  State<ConfigMailPage> createState() => _ConfigMailPageState();
}

class _ConfigMailPageState extends State<ConfigMailPage> {
  final _api = ApiService();
  List<dynamic>? _providers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  Future<void> _cargarProveedores() async {
    setState(() => _loading = true);
    try {
      final providers = await _api.getMailProviders();
      setState(() {
        _providers = providers;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar proveedores: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar proveedores: $e')),
        );
      }
    }
  }

  Future<void> _activarProveedor(int id, String nombre) async {
    try {
      await _api.activarMailProvider(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Proveedor "$nombre" activado correctamente')),
        );
      }
      _cargarProveedores();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al activar proveedor: $e')),
        );
      }
    }
  }

  Future<void> _eliminarProveedor(int id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Desea eliminar el proveedor "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _api.deleteMailProvider(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proveedor eliminado')),
          );
        }
        _cargarProveedores();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _probarEnvio(int? id, String nombre) async {
    final emailController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Probar correo: $nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ingrese la dirección de correo a donde se enviará el mensaje de prueba:'),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo de destino',
                border: OutlineInputBorder(),
                hintText: 'ejemplo@tudominio.com',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar Prueba'),
          ),
        ],
      ),
    );

    if (ok == true && emailController.text.trim().isNotEmpty) {
      final targetEmail = emailController.text.trim();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enviando correo de prueba...')),
      );

      try {
        final res = await _api.testMailProvider(id: id, email: targetEmail);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  res['success'] == true ? Icons.check_circle : Icons.error,
                  color: res['success'] == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(res['success'] == true ? 'Prueba Exitosa' : 'Error en Prueba'),
              ],
            ),
            content: Text(res['message']?.toString() ?? ''),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar prueba: $e')),
        );
      }
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? provider]) {
    final isEdit = provider != null;
    final nombreCtrl = TextEditingController(text: provider?['nombre'] ?? '');
    final hostCtrl = TextEditingController(text: provider?['host'] ?? 'sandbox.smtp.mailtrap.io');
    final portCtrl = TextEditingController(text: (provider?['port'] ?? 2525).toString());
    final userKeyCtrl = TextEditingController(text: provider?['userKey'] ?? '');
    final passSecretCtrl = TextEditingController(text: provider?['passSecretMasked'] ?? '');
    final fromEmailCtrl = TextEditingController(text: provider?['fromEmail'] ?? 'dorsales@tudominio.com');
    final fromNameCtrl = TextEditingController(text: provider?['fromName'] ?? 'Sistema PIA');
    bool secure = provider?['secure'] == true;
    bool activo = provider?['activo'] == true;
    bool obscurePass = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Editar Proveedor' : 'Nuevo Proveedor de Correo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre del Proveedor *', hintText: 'Ej: Mailtrap Sandbox'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: hostCtrl,
                  decoration: const InputDecoration(labelText: 'Servidor SMTP (Host)', hintText: 'sandbox.smtp.mailtrap.io'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: portCtrl,
                        decoration: const InputDecoration(labelText: 'Puerto'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        const Text('SSL/TLS (465):', style: TextStyle(fontSize: 12)),
                        Switch(
                          value: secure,
                          onChanged: (v) => setDialogState(() => secure = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: userKeyCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario SMTP / Key'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passSecretCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Contraseña / Secret Token',
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fromEmailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo Remitente (fromEmail) *'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: fromNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre Remitente (fromName)'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Establecer como Proveedor Activo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  value: activo,
                  onChanged: (v) => setDialogState(() => activo = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                final fromEmail = fromEmailCtrl.text.trim();
                if (nombre.isEmpty || fromEmail.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nombre y Correo Remitente son requeridos')),
                  );
                  return;
                }

                final data = <String, dynamic>{
                  'nombre': nombre,
                  'driver': 'smtp',
                  'host': hostCtrl.text.trim(),
                  'port': int.tryParse(portCtrl.text.trim()) ?? 587,
                  'secure': secure,
                  'userKey': userKeyCtrl.text.trim(),
                  'passSecret': passSecretCtrl.text.trim(),
                  'fromEmail': fromEmail,
                  'fromName': fromNameCtrl.text.trim(),
                  'activo': activo,
                };

                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await _api.updateMailProvider(int.parse(provider['id'].toString()), data);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Proveedor actualizado')),
                      );
                    }
                  } else {
                    await _api.createMailProvider(data);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Proveedor creado')),
                      );
                    }
                  }
                  _cargarProveedores();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar: $e')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Correos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarProveedores,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_read, color: Colors.blue, size: 36),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Proveedores de Correo',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Selecciona y gestiona el servicio activo de correo para el envío de dorsales y notificaciones.',
                                  style: TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _mostrarFormulario(),
                            icon: const Icon(Icons.add),
                            label: const Text('Nuevo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_providers == null || _providers!.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No hay proveedores registrados. Haz clic en "Nuevo" para agregar uno.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else
                    ...(_providers!.map((item) {
                      final p = item as Map<String, dynamic>;
                      final id = int.parse(p['id'].toString());
                      final esActivo = p['activo'] == true;
                      final nombre = p['nombre']?.toString() ?? 'Proveedor #$id';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: esActivo ? Colors.green : Colors.grey.shade300,
                            width: esActivo ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    esActivo ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: esActivo ? Colors.green : Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    nombre,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: esActivo ? Colors.green.shade900 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (esActivo)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'ACTIVO',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Host: ${p['host'] ?? 'N/A'}:${p['port'] ?? 587} | SSL: ${p['secure'] == true ? 'Sí' : 'No'}',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              Text(
                                'Remitente: ${p['fromName'] ?? ''} <${p['fromEmail'] ?? ''}>',
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                              ),
                              if ((p['userKey'] ?? '').isNotEmpty)
                                Text(
                                  'Usuario: ${p['userKey']}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!esActivo)
                                    ElevatedButton.icon(
                                      onPressed: () => _activarProveedor(id, nombre),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Activar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => _probarEnvio(id, nombre),
                                    icon: const Icon(Icons.send, size: 16),
                                    label: const Text('Probar'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    tooltip: 'Editar',
                                    onPressed: () => _mostrarFormulario(p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    tooltip: 'Eliminar',
                                    onPressed: () => _eliminarProveedor(id, nombre),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    })),
                ],
              ),
            ),
    );
  }
}
