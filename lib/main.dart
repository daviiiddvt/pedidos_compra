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
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart'; // Librería que comparte datos globales.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';


// Importamos nuestras propias pantallas y clases (los archivos de la carpeta lib).
import 'core/app_log.dart'; // Logs a fichero (imprescindible en Windows).
import 'core/repositorio_pedidos.dart';
import 'core/app_lifecycle_manager.dart'; // Nuevo manager de ciclo de vida.
import 'core/search/entity_search_repository.dart'; // Repositorio local-first.
import 'core/search/local_cache_db.dart'; // Caché local (SQLite en escritorio/móvil).
import 'core/licencia/licencia.dart';
import 'core/licencia/licencia_service.dart';
import 'core/licencia/licencia_navigation_observer.dart';
import 'core/offline/offline_database.dart';
import 'core/offline/offline_outbox_service.dart';
import 'core/offline/connection_status_service.dart';
import 'screens/licencia_config_screen.dart';
import 'screens/login_screen.dart'; // Pantalla de conexión al servidor.
import 'screens/dashboard_screen.dart';
import 'screens/pedidos_list_screen.dart'; // Pantalla con la lista de pedidos.
import 'screens/pedido_detail_screen.dart'; // Pantalla con el detalle de un pedido.
import 'screens/pedido_form_screen.dart'; // Pantalla para crear/editar pedidos.
import 'screens/presupuestos_list_screen.dart';
import 'screens/presupuesto_detail_screen.dart';
import 'screens/presupuesto_form_screen.dart';
import 'screens/articulos_list_screen.dart';
import 'screens/articulo_detail_screen.dart';
import 'screens/clientes_list_screen.dart';
import 'screens/cliente_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'state/auth_state.dart'; // Estado global de la sesión (¿estamos conectados?).
import 'state/theme_settings.dart';
import 'theme/app_theme.dart'; // Colores y estilos de toda la app.

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// main() es la FUNCIÓN DE ARRANQUE: es lo PRIMERO que ejecuta Flutter.
Future<void> main() async {
  // Necesario para usar plugins antes de que esté lista la UI (sqlite etc.).
  WidgetsFlutterBinding.ensureInitialized();

  // En Windows la app es GUI (sin consola): los print se perderían. Este log
  // a fichero los hace visibles en %APPDATA%\pedidos_venta\pedidos_venta.log.
  setupFileLogging();

  // Abrimos la caché local (SQLite) ANTES de pintar la app. Sin esto, el
  // buscador de clientes/artículos falla con "LocalCacheDbSqlite no
  // inicializado" y la sincronización diferida lanza también TimeoutException.
  // Es idempotente: si ya está abierta, no hace nada.
  await localCacheDbInstance.init();
  await OfflineDatabase.instance.init();
  await OfflineOutboxService.instance.init();
  ConnectionStatusService.instance.init();
  final themeSettings = ThemeSettings();
  await themeSettings.load();
  
  final authState = AuthState();
  await authState.init();

  final licenciaService = LicenciaService();
  await licenciaService.init();

  final licenciaNavObserver = LicenciaNavigationObserver(licenciaService);

  // Si en cualquier momento el servidor da de baja la licencia, cerramos sesión y volvemos a la raíz
  licenciaService.onLicenciaRevocada = (motivo) {
    authState.desconectar();
    final nav = rootNavigatorKey.currentState;
    if (nav != null) {
      nav.popUntil((route) => route.isFirst);
      final ctx = nav.context;
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Licencia no válida o dada de baja: $motivo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  };

  // runApp(...) = "enciende la app y muestra esto en la pantalla".
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authState),
        ChangeNotifierProvider.value(value: themeSettings),
        ChangeNotifierProvider.value(value: licenciaService),
        ChangeNotifierProvider.value(value: ConnectionStatusService.instance),
        Provider(create: (_) => RepositorioPedidos()),
        Provider(create: (_) => EntitySearchRepository()),
      ],
      child: AppLifecycleManager(
        child: PedidosVentaApp(navObserver: licenciaNavObserver),
      ),
    ),
  );
}

/// PedidosVentaApp es el widget RAÍZ de toda la aplicación.
/// Es StatelessWidget (sin estado) porque su única misión es definir la
/// estética general y las rutas; no guarda ninguna variable.
class PedidosVentaApp extends StatelessWidget {
  final LicenciaNavigationObserver? navObserver;
  const PedidosVentaApp({super.key, this.navObserver});

  @override
  Widget build(BuildContext context) {
    // MaterialApp = el "caparazón" de la app. Configura título, tema y rutas.
    final themeSettings = context.watch<ThemeSettings>();
    final licService = context.read<LicenciaService>();
    final observer = navObserver ?? LicenciaNavigationObserver(licService);

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [observer],
      title: 'Pedidos de Venta', // Título (visible en la barra del navegador o Task Switcher).
      debugShowCheckedModeBanner: false, // Oculta la cinta roja "DEBUG" en la esquina.
      theme: AppTheme.light(), // Tema claro con los colores definidos en theme/app_theme.dart.
      darkTheme: AppTheme.dark(),
      themeMode: themeSettings.themeMode,
      locale: const Locale('es', 'ES'),
      supportedLocales: const [
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ConnectivityBannerWrapper(child: child),

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
        '/articulos': (context) => const ArticulosListScreen(),
        '/articulo': (context) => const ArticuloDetailScreen(),
        '/clientes': (context) => const ClientesListScreen(),
        '/cliente': (context) => const ClienteDetailScreen(),
        '/configuracion': (context) => const SettingsScreen(),
        '/licencia': (context) {
          final licService = context.read<LicenciaService>();
          return LicenciaConfigScreen(
            initialLicencia: licService.licencia ?? Licencia(),
            licenseService: licService,
            showBack: true,
          );
        },
      },
    );
  }
}

/// _RootScreen es la "pantalla portero": decide si enseñas la LICENCIA,
/// el LOGIN o la LISTA DE PEDIDOS / DASHBOARD.
///
/// El guion bajo "_" al principio del nombre significa que es PRIVADA:
/// solo se usa dentro de este archivo. Es una convención de Dart.
class _RootScreen extends StatefulWidget {
  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  bool _checkingLostData = true;

  @override
  void initState() {
    super.initState();
    _checkLostData();
  }

  Future<void> _checkLostData() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final response = await ImagePicker().retrieveLostData();
        if (!response.isEmpty && response.file != null) {
          final prefs = await SharedPreferences.getInstance();
          final pedidoId = prefs.getString('picking_photo_pedido_id');
          if (pedidoId != null) {
            await prefs.setString('recovered_photo_path', response.file!.path);
            await prefs.remove('picking_photo_pedido_id');
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/pedido/form', arguments: pedidoId.isEmpty ? null : pedidoId);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Error recovering lost data: $e');
      }
    }
    if (mounted) {
      setState(() {
        _checkingLostData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLostData && defaultTargetPlatform == TargetPlatform.android) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final licService = context.watch<LicenciaService>();
    if (!licService.isValida) {
      return LicenciaConfigScreen(
        initialLicencia: licService.licencia ?? Licencia(),
        licenseService: licService,
        showBack: false,
        onConfigured: (lic) {
          if (mounted) {
            setState(() {});
          }
        },
      );
    }

    final auth = context.watch<AuthState>();

    return auth.connected ? const DashboardScreen() : const LoginScreen();
  }
}
