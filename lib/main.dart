// ============================================================================
//  main.dart  —  PUNTO DE ENTRADA DE LA APLICACIÓN
// ============================================================================
//
//  ¿Qué es esto?
//  -------------
//  Todo programa Flutter arranca en un archivo llamado "main.dart".
//  Aquí no hay lógica de negocio (no se calcula nada de pedidos):
//  este archivo solo se encarga de:
//     1) Arrancar la aplicación.
//     2) Crear el "estado global" (la sesión de login).
//     3) Definir las rutas (las "direcciones" de cada pantalla).
//
//  PENSARLO ASÍ: Si la app fuera una casa, este archivo es la puerta de
//  entrada. Todo lo demás (pantallas, widgets, servicios) son las habitaciones.
//
//  CONCEPTOS DE FLUTTER QUE APARECEN AQUÍ (explicados sin tecnicismos):
//  - Widget      : un "ladrillo" de la interfaz. Botones, textos, pantallas,
//                  cajas, etc. TODO en Flutter es un widget.
//  - MaterialApp : el "contenedor gigante" que organiza la app entera.
//  - StatelessWidget : un widget que se dibuja una vez y no cambia solo.
//  - Provider    : "mochila" que comparte datos entre pantallas sin tener que
//                  pasarlos de mano en mano.
// ============================================================================

import 'package:flutter/material.dart'; // Librería estándar de Flutter (interfaz).
import 'package:provider/provider.dart'; // Librería que comparte datos globales.

// Importamos nuestras propias pantallas y clases (los archivos de la carpeta lib).
import 'core/order_repository.dart';
import 'core/app_lifecycle_manager.dart'; // Nuevo manager de ciclo de vida.
import 'core/search/entity_search_repository.dart'; // Repositorio local-first.
import 'screens/login_screen.dart'; // Pantalla de conexión al servidor.
import 'screens/dashboard_screen.dart';
import 'screens/pedidos_list_screen.dart'; // Pantalla con la lista de pedidos.
import 'screens/pedido_detail_screen.dart'; // Pantalla con el detalle de un pedido.
import 'screens/pedido_form_screen.dart'; // Pantalla para crear/editar pedidos.
import 'screens/presupuestos_list_screen.dart';
import 'screens/presupuesto_detail_screen.dart';
import 'screens/presupuesto_form_screen.dart';
import 'state/auth_state.dart'; // Estado global de la sesión (¿estamos conectados?).
import 'theme/app_theme.dart'; // Colores y estilos de toda la app.

/// main() es la FUNCIÓN DE ARRANQUE: es lo PRIMERO que ejecuta Flutter.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // runApp(...) = "enciende la app y muestra esto en la pantalla".
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        Provider(create: (_) => OrderRepository()),
        Provider(create: (_) => EntitySearchRepository()),
      ],
      child: const AppLifecycleManager(
        child: PedidosVentaApp(),
      ),
    ),
  );
}

/// PedidosVentaApp es el widget RAÍZ de toda la aplicación.
/// Es StatelessWidget (sin estado) porque su única misión es definir la
/// estética general y las rutas; no guarda ninguna variable.
class PedidosVentaApp extends StatelessWidget {
  const PedidosVentaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp = el "caparazón" de la app. Configura título, tema y rutas.
    return MaterialApp(
      title: 'Pedidos de Venta', // Título (visible en la barra del navegador o Task Switcher).
      debugShowCheckedModeBanner: false, // Oculta la cinta roja "DEBUG" en la esquina.
      theme: AppTheme.light(), // Tema claro con los colores definidos en theme/app_theme.dart.

      // initialRoute: ¿qué pantalla se muestra al abrir la app? La "/".
      initialRoute: '/',

      // routes = el "mapa de rutas" de la app. Cada ruta tiene una "dirección"
      // (el texto entre comillas) y la pantalla que debe abrir.
      // Los parámetros se pasan con .arguments cuando se navega (pushNamed).
      routes: {
        // Ruta raíz: decide automáticamente Login o Dashboard según la sesión.
        '/': (context) => _RootScreen(),
        '/home': (context) => const DashboardScreen(),
        '/pedidos': (context) => const PedidosListScreen(),
        '/cmr': (context) => const CmrComingSoonScreen(),

        // Ruta de DETALLE: pedidoId se recibe como argumento.
        '/pedido': (context) =>
            PedidoDetailScreen(pedidoId: (ModalRoute.of(context)!.settings.arguments)),

        // Ruta de FORMULARIO (crear/editar): también recibe el id, puede ser null.
        '/pedido/form': (context) => PedidoFormScreen(
              pedidoId: (ModalRoute.of(context)!.settings.arguments),
            ),
        '/presupuestos': (context) => const PresupuestosListScreen(),
        '/presupuesto': (context) => PresupuestoDetailScreen(
              presupuestoId: ModalRoute.of(context)!.settings.arguments,
            ),
        '/presupuesto/form': (context) => PresupuestoFormScreen(
              presupuestoId: ModalRoute.of(context)!.settings.arguments,
            ),
      },
    );
  }
}

/// _RootScreen es la "pantalla portero": decide si enseñas el LOGIN
/// o la LISTA DE PEDIDOS mirando el estado global de la sesión.
///
/// El guion bajo "_" al principio del nombre significa que es PRIVADA:
/// solo se usa dentro de este archivo. Es una convención de Dart.
class _RootScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // context.watch<AuthState>() = "mira el estado global de la sesión".
    // Al usar watch (no read), esta pantalla se REDIBUJA sola cuando cambia.
    final auth = context.watch<AuthState>();

    // Si estamos conectados → dashboard principal. Si no → pantalla de login.
    return auth.connected ? const DashboardScreen() : const LoginScreen();
  }
}