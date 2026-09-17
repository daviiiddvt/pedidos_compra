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
  // Los dos "muñecos" que guardan lo escrito en los campos de texto.
  late final TextEditingController _server; // Lo escrito en "URL del servidor".
  late final TextEditingController _apiKey; // Lo escrito en "API Key".
  late final TextEditingController _username;
  late final TextEditingController _password;

  /// initState: se ejecuta UNA vez, justo cuando la pantalla nace.
  /// Aquí rellenamos los campos con lo que ya haya en la configuración
  /// (así, si AppConfig.baseUrl ya trae algo, el campo sale relleno).
  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: AppConfig.baseUrl);
    _apiKey = TextEditingController(text: AppConfig.apiKey);
    _username = TextEditingController();
    _password = TextEditingController();
  }

  /// dispose: se ejecuta cuando la pantalla muere. Libera la memoria de los
  /// controllers (buena práctica: siempre que creamos uno, lo limpiamos).
  @override
  void dispose() {
    _server.dispose();
    _apiKey.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// _conectar: lo que pasa al pulsar el botón "Conectar".
  Future<void> _conectar(AuthState auth) async {
    // Le pedimos al estado global que intente conectar con los datos escritos.
    // trim() quita espacios sobrantes al principio y al final.
    final ok = await auth.conectar(
      baseUrl: _server.text.trim(),
      apiKey: _apiKey.text.trim(),
      username: _username.text.trim(),
      password: _password.text,
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
    // watch: nos suscribimos al estado de sesión. Si "connecting" cambia,
    // esta pantalla se repinta sola (por ejemplo, para mostrar el spinner).
    final auth = context.watch<AuthState>();

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
                      'PV',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16), // Separador vertical (vacío).

                  // ---- Título ----
                  const Text(
                    'Pedidos de Venta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ---- Subtítulo ----
                  const Text(
                    'Conecta con tu servidor VELNEO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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
                          const Text(
                            'Conexión',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Campo URL del servidor (reutilizamos nuestro widget).
                          CampoForm(
                            label: 'URL del servidor',
                            controller: _server,
                            placeholder: 'http://localhost:39543/v1',
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 14),

                          CampoForm(
                            label: 'Usuario',
                            controller: _username,
                            placeholder: 'Usuario de Velneo',
                          ),
                          const SizedBox(height: 14),

                          CampoForm(
                            label: 'Contraseña',
                            controller: _password,
                            placeholder: 'Contraseña de Velneo',
                            obscureText: true,
                          ),
                          const SizedBox(height: 14),

                          // Campo API Key.
                          CampoForm(
                            label: 'API Key',
                            controller: _apiKey,
                            placeholder: 'Clave de la API',
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

                  // ---- Nota informativa al pie ----
                  Text(
                    'Ajusta la URL y API Key en lib/core/config.dart o aquí mismo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
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