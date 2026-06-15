import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../domain/i_servicio_push.dart';

/// Implementación de [IServicioPush] con Firebase Cloud Messaging.
class FirebasePushService implements IServicioPush {
  FirebasePushService({FirebaseFirestore? db, FirebaseMessaging? messaging})
      : _db = db ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  /// `uid` para el que ya se inicializó (evita repetir el trabajo).
  String? _uidInicializado;

  /// Suscripción a la rotación del token; se cancela al cambiar de usuario para
  /// no escribir el token nuevo en el documento del usuario anterior.
  StreamSubscription<String>? _tokenRefreshSub;

  /// Clave pública VAPID para **Web Push** (consola Firebase → Cloud Messaging →
  /// Certificados push web). Es pública, no secreta (igual que el serverClientId
  /// de Google Sign-In). En Android/iOS no se usa.
  static const _vapidKeyWeb =
      'BMJqwR3HtahNMTDzTO7AExPcLEHPF-JBqWw2aQ7vi7j9QCYfoc7w7RsvJkuoMAXe_xw6evfFzzPkuMaT-Trfpj8';

  @override
  Future<void> inicializar(String uid) async {
    if (_uidInicializado == uid) return;
    _uidInicializado = uid;
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _obtenerToken();
      if (token != null) await _guardarToken(uid, token);

      // Si el token rota, se vuelve a guardar para no perder el canal de envío.
      // Se cancela la suscripción anterior (de otro uid) para no escribir en el
      // documento equivocado tras un cambio de sesión.
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen(
        (t) => _guardarToken(uid, t).catchError(
          (Object e) => debugPrint('push: no se pudo guardar token rotado: $e'),
        ),
      );
    } catch (e) {
      _uidInicializado = null; // permite reintentar en la próxima emisión
      debugPrint('push: inicialización falló (no fatal): $e');
    }
  }

  Future<String?> _obtenerToken() {
    if (kIsWeb) return _messaging.getToken(vapidKey: _vapidKeyWeb);
    return _messaging.getToken();
  }

  Future<void> _guardarToken(String uid, String token) {
    // `fcmTokens` es un array (un usuario puede tener varios dispositivos). El
    // dueño puede escribirlo; las Functions lo leen para enviar push.
    return _db.collection('users').doc(uid).update({
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
  }
}
