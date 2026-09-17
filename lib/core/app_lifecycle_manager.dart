import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'order_repository.dart';
import '../state/auth_state.dart';

class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({super.key, required this.child});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // Forzar limpieza de seguridad
      final repository = Provider.of<OrderRepository>(context, listen: false);
      final authState = Provider.of<AuthState>(context, listen: false);
      
      repository.clearCache();
      authState.desconectar();
      
      debugPrint("Application detached: Cache y sesión limpiadas por seguridad.");
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}