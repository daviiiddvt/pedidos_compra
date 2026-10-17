// ============================================================================
//  login_screen.dart  —  PANTALLA DE CONEXIÓN (primer contacto con VELNEO)
// ============================================================================
//
//  ¿Qué es?
//  --------
//  Es la primera pantalla que ve el usuario (mientras no esté conectado).
//  Muestra dos campos:
//     1) URL del servidor (la dirección donde vive el API de VELNEO).
//     2) API Key (la clave que permite entrar).
//  Y un botón "Conectar" que prueba la conexión.
//
//  Si conecta bien → la app salta sola a la lista de pedidos (gracias al
//  estado global AuthState: al cambiar "connected" a true, main.dart redibuja).
//
//  CONCEPTOS FLUTTER QUE APARECEN:
//  - StatefulWidget: un widget "con memoria". Aquí la memoria son los campos
//    de texto (_server, _apiKey). Se usa stateful porque el usuario escribe.
//  - TextEditingController: "el hilo" que conecta un campo de texto con su valor.
//  - Scaffold: el esqueleto básico de una pantalla (fondo, barra, cuerpo).
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart'; // Para llamar a auth.conectar(...).
import '../core/config.dart'; // Para rellenar los campos con los valores actuales.
import '../core/licencia/licencia_service.dart';
import '../theme/app_theme.dart'; // Colores.
import '../widgets/campo_form.dart'; // Nuestro widget de campo de texto reutilizable.

/// LoginScreen es la "pantalla de presentación": pregunta cómo conectarse.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// _LoginScreenState: la "memoria" de la pantalla (los datos que vive aquí).
class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _instanceCtrl;
  late final TextEditingController _versionCtrl;
  late final TextEditingController _manualUrlCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;

  bool _mostrarConfig = false;
  bool _modoManual = false;

  /// initState: se ejecuta UNA vez, justo cuando la pantalla nace.
  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(
      text: AppConfig.serverHost.isNotEmpty ? AppConfig.serverHost : AppConfig.defaultHost,
    );
    _instanceCtrl = TextEditingController(text: AppConfig.serverInstance);
    _versionCtrl = TextEditingController(
      text: AppConfig.serverVersion.isNotEmpty ? AppConfig.serverVersion : AppConfig.defaultVersion,
    );
    _apiKeyCtrl = TextEditingController(text: AppConfig.apiKey);
    _usernameCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();

    final currentBase = AppConfig.baseUrl.trim();
    _manualUrlCtrl = TextEditingController(text: currentBase);

    // Si la URL por defecto tiene XXXX, o está vacía, o no hay instancia, mostramos la configuración de red.
    if (currentBase.contains('XXXX') || currentBase.isEmpty || AppConfig.serverInstance.trim().isEmpty) {
      _mostrarConfig = true;
    }

    _hostCtrl.addListener(_onParamChanged);
    _instanceCtrl.addListener(_onParamChanged);
    _versionCtrl.addListener(_onParamChanged);
  }

  void _onParamChanged() {
    if (!_modoManual) {
      setState(() {
        _manualUrlCtrl.text = AppConfig.buildBaseUrl(
          host: _hostCtrl.text,
          instance: _instanceCtrl.text,
          version: _versionCtrl.text,
        );
      });
    }
  }

  String get _currentUrl {
    if (_modoManual) {
      return _manualUrlCtrl.text.trim();
    }
    return AppConfig.buildBaseUrl(
      host: _hostCtrl.text,
      instance: _instanceCtrl.text,
      version: _versionCtrl.text,
    );
  }

  /// dispose: se ejecuta cuando la pantalla muere. Libera la memoria de los
  /// controllers (buena práctica: siempre que creamos uno, lo limpiamos).
  @override
  void dispose() {
    _hostCtrl.removeListener(_onParamChanged);
    _instanceCtrl.removeListener(_onParamChanged);
    _versionCtrl.removeListener(_onParamChanged);
    _hostCtrl.dispose();
    _instanceCtrl.dispose();
    _versionCtrl.dispose();
    _manualUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// _conectar: lo que pasa al pulsar el botón "Conectar".
  Future<void> _conectar(AuthState auth) async {
    final finalUrl = _currentUrl;
    if (!_modoManual && _instanceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, indica la instancia de datos')),
      );
      return;
    }

    final ok = await auth.conectar(
      baseUrl: finalUrl,
      apiKey: _apiKeyCtrl.text.trim(),
      username: _usernameCtrl.text.trim(),
      password: _passwordCtrl.text,
      host: _hostCtrl.text.trim(),
      instance: _instanceCtrl.text.trim(),
      version: _versionCtrl.text.trim(),
    );

    // Si falló y la pantalla sigue viva (mounted), enseñamos el error.
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Error de conexión')),
      );
    }
  }

  /// build: DIBUJA la pantalla. Se llama cada vez que el estado cambia.
  @override
  Widget build(BuildContext context) {
    // watch: nos suscribimos al estado de sesión y de licencia.
    final auth = context.watch<AuthState>();
    final licService = context.watch<LicenciaService>();
    final licHost = licService.licencia?.serverHost.trim();

    return Scaffold(
      body: SafeArea( // Evita que el contenido choque con los bordes/navegación.
        child: Center( // Todo centrado horizontal y vertical.
          child: SingleChildScrollView( // Si la pantalla es pequeña, permite scroll.
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460), // Ancho máximo (mejor en PC).
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Hijos a lo ancho.
                children: [
                  // ---- Logo "PV" (Pedidos de Venta) ----
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'TecERP',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Separador vertical (vacío).

                  // ---- Título ----
                  Text(
                    'TecERP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ---- Subtítulo ----
                  Text(
                    'Conecta con tu servidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ---- La "tarjeta" con el formulario ----
                  Card(
                    elevation: 4, // Sombra.
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mostrarConfig) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Conexión de red',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _modoManual = !_modoManual;
                                      if (!_modoManual) {
                                        AppConfig.parseAndSetBaseUrl(_manualUrlCtrl.text);
                                        _hostCtrl.text = AppConfig.serverHost;
                                        _instanceCtrl.text = AppConfig.serverInstance;
                                        _versionCtrl.text = AppConfig.serverVersion;
                                      }
                                    });
                                  },
                                  icon: Icon(_modoManual ? Icons.tune : Icons.edit_note, size: 16),
                                  label: Text(
                                    _modoManual ? 'Modo guiado' : 'URL manual',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (_modoManual) ...[
                              // Campo URL del servidor manual completo
                              CampoForm(
                                key: const ValueKey('serverUrl'),
                                label: 'URL del servidor (completa)',
                                controller: _manualUrlCtrl,
                                placeholder: 'https://tecerp.nunsys.com:4331/...',
                                keyboardType: TextInputType.url,
                              ),
                            ] else ...[
                              // Modo guiado parametrizado
                              CampoForm(
                                key: const ValueKey('serverHost'),
                                label: 'Servidor (Host)',
                                controller: _hostCtrl,
                                placeholder: 'https://tecerp.nunsys.com:4331',
                                keyboardType: TextInputType.url,
                              ),
                              if (licHost != null && licHost.isNotEmpty && licHost != _hostCtrl.text) ...[
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: InkWell(
                                    onTap: () {
                                      _hostCtrl.text = licHost;
                                      _onParamChanged();
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy, size: 13, color: Theme.of(context).colorScheme.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Usar host de licencia ($licHost)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(context).colorScheme.primary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Instancia
                              CampoForm(
                                key: const ValueKey('serverInstance'),
                                label: 'Instancia de datos',
                                controller: _instanceCtrl,
                                placeholder: 'Ej: TECMICRO_PRUEBAS_AD_AVANZADO',
                              ),
                              const SizedBox(height: 12),

                              // Versión
                              CampoForm(
                                key: const ValueKey('serverVersion'),
                                label: 'Versión de la API',
                                controller: _versionCtrl,
                                placeholder: 'v1',
                              ),
                            ],
                            const SizedBox(height: 12),

                            // Campo API Key
                            CampoForm(
                              key: const ValueKey('apiKey'),
                              label: 'API Key',
                              controller: _apiKeyCtrl,
                              placeholder: 'Clave de la API',
                            ),
                            const SizedBox(height: 14),
                            const Divider(),
                            const SizedBox(height: 14),
                          ],
                          const Text(
                            'Autenticación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          CampoForm(
                            key: const ValueKey('username'),
                            label: 'Usuario',
                            controller: _usernameCtrl,
                            placeholder: 'Usuario',
                          ),
                          const SizedBox(height: 14),

                          CampoForm(
                            key: const ValueKey('password'),
                            label: 'Contraseña',
                            controller: _passwordCtrl,
                            placeholder: 'Contraseña',
                            obscureText: true,
                          ),
                          const SizedBox(height: 20),

                          // Botón "Conectar". Mientras conecta está deshabilitado
                          // y muestra un "rueda giratoria" (spinner) blanco.
                          ElevatedButton(
                            onPressed:
                                auth.connecting ? null : () => _conectar(auth),
                            child: auth.connecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white,
                                    ),
                                  )
                                : const Text('Conectar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _mostrarConfig = !_mostrarConfig;
                          });
                        },
                        icon: Icon(_mostrarConfig ? Icons.expand_less : Icons.settings_outlined),
                        label: Text(_mostrarConfig ? 'Ocultar red' : 'Ajustes de red'),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/licencia'),
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Licencia'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  // ---- Nota informativa al pie ----
                  Text(
                    'Contacta con soporte si tienes dudas sobre tu configuración.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                        color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}