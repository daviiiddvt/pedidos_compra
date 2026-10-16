import 'dart:async';
import 'package:flutter/material.dart';

import '../api_client.dart';
import '../config.dart';
import 'offline_outbox_service.dart';

/// Servicio singleton que monitoriza el estado de conexión al servidor
/// y notifica a la interfaz de usuario en tiempo real.
class ConnectionStatusService extends ChangeNotifier {
  static final ConnectionStatusService instance = ConnectionStatusService._();
  ConnectionStatusService._();

  bool _isOnline = true;
  Timer? _timer;
  bool _isChecking = false;

  bool get isOnline => _isOnline;

  void init() {
    _startPeriodicCheck();
    checkConnection();
  }

  void setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
      if (online) {
        // Al recuperar la conexión, procesa la cola Outbox en segundo plano
        OfflineOutboxService.instance.processQueue();
      }
    }
  }

  void _startPeriodicCheck() {
    _timer?.cancel();
    // Comprobación periódica cada 12 segundos
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      checkConnection();
    });
  }

  Future<bool> checkConnection() async {
    if (_isChecking) return _isOnline;
    _isChecking = true;
    try {
      final host = AppConfig.serverHost.trim();
      final apiKey = AppConfig.apiKey.trim();
      if (host.isEmpty || apiKey.isEmpty) {
        setOnline(false);
        return false;
      }

      await ApiClient.instance
          .get(
            AppConfig.endpoint('series'),
            params: {'page[size]': 1},
          )
          .timeout(const Duration(seconds: 3));

      setOnline(true);
      return true;
    } catch (_) {
      setOnline(false);
      return false;
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Widget que envuelve todas las pantallas de la aplicación para mostrar
/// el banner "Modo: Sin conexión" en la parte superior cuando no hay conexión.
class ConnectivityBannerWrapper extends StatelessWidget {
  final Widget? child;

  const ConnectivityBannerWrapper({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ConnectionStatusService.instance,
      builder: (context, _) {
        final isOnline = ConnectionStatusService.instance.isOnline;
        return Column(
          children: [
            if (!isOnline)
              Material(
                color: Colors.amber.shade900,
                elevation: 4,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 16,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Modo: Sin conexión',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }
}

