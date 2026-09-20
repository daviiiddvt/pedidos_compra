// ============================================================================
//  auth_state.dart     ESTADO GLOBAL DE LA SESIÓN (¿estamos conectados?)
// ============================================================================

import 'package:flutter/foundation.dart';
import '../api_service.dart'; 
import '../core/api_client.dart'; 
import '../core/config.dart'; 
import '../core/master_cache_service.dart';
import '../core/search/master_sync_service.dart';
import '../models.dart'; // 1. IMPORTANTE: Importar los modelos para reconocer User

/// AuthState: el "cerebro" de la sesión. Guarda y controla la conexión.
class AuthState extends ChangeNotifier {
  // Variables PRIVADAS (por eso llevan _). Solo se tocan desde aquí.
  bool _connected = false;
  bool _connecting = false;
  bool _mastersSyncing = false;
  String? _error;
  
  // 2. AÑADIR LA PROPIEDAD DEL USUARIO AQUÍ (junto a las demás variables)
  User? _currentUser;

  // --- Getters: permiten LEER los valores desde fuera, pero no cambiarlos. ---
  bool get connected => _connected;
  bool get connecting => _connecting;
  bool get mastersSyncing => _mastersSyncing;
  String? get error => _error;
  
  // Getter público para el usuario
  User? get currentUser => _currentUser;

  /// conectar: intenta establecer la conexión con el servidor VELNEO.
  Future<bool> conectar({
    required String baseUrl,
    required String apiKey,
    required String username,
    required String password,
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
      _currentUser = await PedidosService.authenticateUser(
        username: username,
        password: password,
      );
      _connected = true;
      Future.microtask(() => _startMasterSync());

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

  Future<void> _startMasterSync() async {
    if (_mastersSyncing) return;

    _mastersSyncing = true;
    notifyListeners();

    try {
      // Solo se precargan maestros pequeños y ligeros; clientes/artículos se
      // sincronizan de forma diferida en segundo plano (MasterSyncService) y se
      // buscan bajo demanda desde los selectores para no saturar memoria ni red.
      await MasterCacheService().syncSessionMasters();
      MasterSyncService.instance.ensureStarted();
    } catch (_) {
      // La sincronización no debe bloquear la sesión ni romper la navegación.
    } finally {
      _mastersSyncing = false;
      notifyListeners();
    }
  }

  /// desconectar: cierra la sesión.
  void desconectar() {
    _connected = false;
    _mastersSyncing = false;
    _currentUser = null; // 4. LIMPIAR EL USUARIO AL DESCONECTAR POR SEGURIDAD
    MasterCacheService().invalidateAll();
    MasterSyncService.instance.stop();
    ApiClient.instance.setApiKey('');
    notifyListeners();
  }
}