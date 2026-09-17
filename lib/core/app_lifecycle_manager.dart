import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'order_repository.dart';

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
      // Clear cache here
      final repository = Provider.of<OrderRepository>(context, listen: false);
      repository.clearCache();
      print("Application detached, cache cleared.");
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
