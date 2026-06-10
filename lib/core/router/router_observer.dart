import 'package:flutter/material.dart';

import '../telemetria/domain/i_servicio_telemetria.dart';

/// Registra cada navegación como pantalla en Analytics y como breadcrumb
/// en Crashlytics para facilitar la reconstrucción del camino al crash.
class TelemetriaRouterObserver extends NavigatorObserver {
  TelemetriaRouterObserver(this._telemetria);

  final IServicioTelemetria _telemetria;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _registrar(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _registrar(newRoute);
  }

  void _registrar(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    _telemetria.pantalla(name);
    _telemetria.log('nav: $name');
  }
}
