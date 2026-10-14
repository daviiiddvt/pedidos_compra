// ============================================================================
//  auth_state.dart     ESTADO GLOBAL DE LA SESIÓN (¿estamos conectados?)
// ============================================================================

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart'; 
import '../core/api_client.dart'; 
import '../core/config.dart'; 
import '../core/master_cache_service.dart';
import '../core/search/master_sync_service.dart';
import '../models/models.dart'; // 1. IMPORTANTE: Importar los modelos para reconocer User

/// AuthState: el "cerebro" de la sesión. Guarda y controla la conexión.
class AuthState extends ChangeNotifier {
  // Variables PRIVADAS (por eso llevan _). Solo se tocan desde aquí.
  bool _connected = false;
  bool _connecting = false;
  bool _mastersSyncing = false;
  String? _error;
  bool _canViewTechnicalZone = false;
  
  // 2. AÑADIR LA PROPIEDAD DEL USUARIO AQUÍ (junto a las demás variables)
  User? _currentUser;

  // --- Getters: permiten LEER los valores desde fuera, pero no cambiarlos. ---
  bool get connected => _connected;
  bool get connecting => _connecting;
  bool get mastersSyncing => _mastersSyncing;
  String? get error => _error;
  
  // Getter público para el usuario
  User? get currentUser => _currentUser;
  bool get canViewTechnicalZone => _canViewTechnicalZone;

  /// init: intenta cargar la sesión guardada al arrancar la app.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Restaurar parámetros de conexión de red guardados
      final savedHost = prefs.getString('auth_serverHost');
      final savedInstance = prefs.getString('auth_serverInstance');
      final savedVersion = prefs.getString('auth_serverVersion');
      final savedBaseUrl = prefs.getString('auth_baseUrl');
      final savedApiKey = prefs.getString('auth_apiKey');

      if (savedHost != null && savedHost.trim().isNotEmpty) {
        AppConfig.serverHost = savedHost.trim();
      }
      if (savedInstance != null && savedInstance.trim().isNotEmpty) {
        AppConfig.serverInstance = savedInstance.trim();
      }
      if (savedVersion != null && savedVersion.trim().isNotEmpty) {
        AppConfig.serverVersion = savedVersion.trim();
      }
      if (savedApiKey != null && savedApiKey.trim().isNotEmpty) {
        AppConfig.apiKey = savedApiKey.trim();
      }

      if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
        AppConfig.parseAndSetBaseUrl(savedBaseUrl.trim());
      } else if (AppConfig.serverInstance.isNotEmpty) {
        AppConfig.baseUrl = AppConfig.buildBaseUrl();
      }

      final hasSession = prefs.getBool('auth_connected') ?? false;
      if (hasSession) {
        final baseUrl = prefs.getString('auth_baseUrl') ?? AppConfig.baseUrl;
        final apiKey = prefs.getString('auth_apiKey') ?? AppConfig.apiKey;
        final userJson = prefs.getString('auth_currentUser');
        final canViewTech = prefs.getBool('auth_canViewTechnicalZone') ?? false;

        if (baseUrl.isNotEmpty && apiKey.isNotEmpty && userJson != null) {
          AppConfig.baseUrl = baseUrl;
          AppConfig.apiKey = apiKey;
          ApiClient.instance.setApiKey(apiKey);
          _currentUser = User.fromJson(jsonDecode(userJson));
          _canViewTechnicalZone = canViewTech;
          _connected = true;
          
          debugPrint('[AUTH] Sesión restaurada de SharedPreferences para ${_currentUser?.name}');
          Future.microtask(() => _startMasterSync());
        }
      }
    } catch (e) {
      debugPrint('[AUTH] Error al restaurar sesión: $e');
      _connected = false;
    }
    notifyListeners();
  }

  /// Guarda los parámetros de conexión de red en SharedPreferences
  Future<void> saveNetworkConfig({
    required String host,
    required String instance,
    required String version,
    required String apiKey,
    required String baseUrl,
  }) async {
    AppConfig.serverHost = host.trim();
    AppConfig.serverInstance = instance.trim();
    AppConfig.serverVersion = version.trim();
    AppConfig.apiKey = apiKey.trim();
    AppConfig.baseUrl = baseUrl.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_serverHost', AppConfig.serverHost);
    await prefs.setString('auth_serverInstance', AppConfig.serverInstance);
    await prefs.setString('auth_serverVersion', AppConfig.serverVersion);
    await prefs.setString('auth_baseUrl', AppConfig.baseUrl);
    await prefs.setString('auth_apiKey', AppConfig.apiKey);
    notifyListeners();
  }

  /// conectar: intenta establecer la conexión con el servidor VELNEO.
  Future<bool> conectar({
    required String baseUrl,
    required String apiKey,
    required String username,
    required String password,
    String? host,
    String? instance,
    String? version,
  }) async {
    _connecting = true;
    _error = null;
    PedidosService.clearTechnicalZoneCache();
    notifyListeners();

    try {
      if (host != null && host.trim().isNotEmpty) {
        AppConfig.serverHost = host.trim();
      }
      if (instance != null) {
        AppConfig.serverInstance = instance.trim();
      }
      if (version != null && version.trim().isNotEmpty) {
        AppConfig.serverVersion = version.trim();
      }

      AppConfig.baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), '');
      AppConfig.apiKey = apiKey;

      ApiClient.instance.setApiKey(apiKey);

      // Llamada de prueba al API. Si falla, salta al catch.
      await PedidosService.checkConnection();
      _currentUser = await PedidosService.authenticateUser(
        username: username,
        password: password,
      );
      final roleLower = _currentUser!.role.toLowerCase();
      final isAdmin = roleLower == 'administrador' || roleLower == 'admin';
      final isRoleComercial = roleLower == 'comercial';
      
      bool isContactComercial = false;
      if (isRoleComercial) {
        isContactComercial = true;
      } else if (_currentUser!.contactId.isNotEmpty) {
        try {
          isContactComercial = await PedidosService.esContactoComercial(
            _currentUser!.contactId,
          );
        } catch (_) {
          isContactComercial = false;
        }
      }

      if (!isAdmin && !isContactComercial) {
        throw ApiException('Tu usuario no tiene permisos para acceder a la aplicación.');
      }

      if (isRoleComercial) {
        _canViewTechnicalZone = true;
      } else if (isAdmin && isContactComercial) {
        _canViewTechnicalZone = true;
      } else {
        _canViewTechnicalZone = false;
      }
      debugPrint(
        '[AUTH] Permiso zona técnica: canViewTechnicalZone=$_canViewTechnicalZone '
        '(rol=$roleLower, contactId=${_currentUser!.contactId})',
      );
      _connected = true;
      Future.microtask(() => _startMasterSync());

      // Guardar sesión y configuración de red completa
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_connected', true);
      await prefs.setString('auth_baseUrl', AppConfig.baseUrl);
      await prefs.setString('auth_apiKey', AppConfig.apiKey);
      await prefs.setString('auth_serverHost', AppConfig.serverHost);
      await prefs.setString('auth_serverInstance', AppConfig.serverInstance);
      await prefs.setString('auth_serverVersion', AppConfig.serverVersion);
      if (_currentUser != null) {
        await prefs.setString('auth_currentUser', jsonEncode(_currentUser!.toJson()));
      }
      await prefs.setBool('auth_canViewTechnicalZone', _canViewTechnicalZone);

      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'No se pudo conectar al servidor.';
      _connected = false;
      _canViewTechnicalZone = false;
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
    _canViewTechnicalZone = false;
    PedidosService.clearTechnicalZoneCache();
    MasterCacheService().invalidateAll();
    MasterSyncService.instance.stop();
    ApiClient.instance.setApiKey('');
    
    // Limpiar sesión guardada
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('auth_connected');
      // prefs.remove('auth_baseUrl');
      // prefs.remove('auth_apiKey');
      prefs.remove('auth_currentUser');
      prefs.remove('auth_canViewTechnicalZone');
    });
    
    notifyListeners();
  }
}