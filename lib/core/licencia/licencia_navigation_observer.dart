import 'package:flutter/material.dart';
import 'licencia_service.dart';

/// Observer que detecta cada transición de ventana/pantalla en la aplicación
/// y solicita verificar si la licencia sigue activa o ha sido dada de baja en el servidor.
class LicenciaNavigationObserver extends NavigatorObserver {
  final LicenciaService licenciaService;

  LicenciaNavigationObserver(this.licenciaService);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute && route.settings.name != '/licencia') {
      licenciaService.comprobarBajaSiProcede();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute && previousRoute?.settings.name != '/licencia') {
      licenciaService.comprobarBajaSiProcede();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute && newRoute.settings.name != '/licencia') {
      licenciaService.comprobarBajaSiProcede();
    }
  }
}

