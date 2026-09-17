// ============================================================================
//  auth_state.dart     ESTADO GLOBAL DE LA SESIÓN (¿estamos conectados?)
// ============================================================================

import 'package:flutter/foundation.dart';
import '../api_service.dart'; 
import '../core/api_client.dart'; 
import '../core/config.dart'; 
import '../models.dart'; // 1. IMPORTANTE: Importar los modelos para reconocer User

/// AuthState: el "cerebro" de la sesión. Guarda y controla la conexión.
class AuthState extends ChangeNotifier {
  // Variables PRIVADAS (por eso llevan _). Solo se tocan desde aquí.
  bool _connected = false;
  bool _connecting = false;
  String? _error;
  
  // 2. AÑADIR LA PROPIEDAD DEL USUARIO AQUÍ (junto a las demás variables)
  User? _currentUser;

  // --- Getters: permiten LEER los valores desde fuera, pero no cambiarlos. ---
  bool get connected => _connected;
  bool get connecting => _connecting;
  String? get error => _error;
  
  // Getter público para el usuario
  User? get currentUser => _currentUser;

  /// conectar: intenta establecer la conexión con el servidor VELNEO.
  Future<bool> conectar({
    required String baseUrl,
    required String apiKey,
  }) async {
    _connecting = true;
    _error = null;
    notifyListeners();

    try {
      AppConfig.baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
      AppConfig.apiKey = apiKey;

      ApiClient.instance.setApiKey(apiKey);

      // Llamada de prueba al API. Si falla, salta al catch.
      await PedidosService.checkConnection();

      // Todo correcto -> conectado.
      _connected = true;
      
      // 3. INSTANCIAR EL USUARIO AQUÍ (Después de confirmar que el API funciona)
      // Nota: En un caso real, aquí harías una llamada a tu API para obtener los datos del comercial.
      // Por ahora, simulamos que ha entrado un Comercial con permisos restringidos.
      _currentUser = const User(
        id: '1', 
        name: 'Comercial Demo', 
        role: 'Comercial', 
        assignedCustomerIds: ['10', '15'] // Solo verá pedidos de los clientes 10 y 15
      );

      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'No se pudo conectar al servidor.';
      _connected = false;
      return false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// desconectar: cierra la sesión.
  void desconectar() {
    _connected = false;
    _currentUser = null; // 4. LIMPIAR EL USUARIO AL DESCONECTAR POR SEGURIDAD
    ApiClient.instance.setApiKey('');
    notifyListeners();
  }
}