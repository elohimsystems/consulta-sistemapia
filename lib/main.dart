import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'pages/eventos_list_page.dart';
import 'pages/buscar_dorsal_page.dart';

void main() {
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SistemaPIA',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      routes: {
        '/eventos': (context) => const EventosListPage(),
      },
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        if (uri.path == '/') {
          return MaterialPageRoute(builder: (_) => const BuscarDorsalPage());
        }
        final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (pathSegments.length == 1) {
          final id = int.tryParse(pathSegments[0]);
          if (id != null) {
            return MaterialPageRoute(builder: (_) => BuscarDorsalPage(idevento: id));
          }
        }
        return MaterialPageRoute(builder: (_) => const EventosListPage());
      }
    );
  }
}
