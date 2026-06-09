import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/i_auth_repository.dart';
import '../domain/perfil_usuario.dart';

/// Implementación de [IAuthRepository] usando Firebase Auth + Firestore.
class FirebaseAuthRepository implements IAuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(),
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;

  @override
  Stream<PerfilUsuario?> get perfilStream {
    // userChanges() (no authStateChanges()) emite también en cambios in-place
    // del usuario —como linkWithCredential / refresco de token— de modo que la
    // UI deja de ver el perfil anónimo justo tras convertir la cuenta.
    return _auth.userChanges().asyncMap((user) async {
      if (user == null) return null;
      return _fetchPerfil(user);
    });
  }

  @override
  PerfilUsuario? get perfilActual {
    final user = _auth.currentUser;
    if (user == null) return null;
    // Devuelve un perfil mínimo sincrónico; el saldo real llega por Firestore.
    return PerfilUsuario(
      uid: user.uid,
      displayName: user.displayName ?? 'Jugador',
      email: user.email ?? '',
      avatar: user.photoURL ?? '🃏',
      balance: 0,
      inviteCode: '',
      isAnonymous: user.isAnonymous,
    );
  }

  @override
  Future<PerfilUsuario> entrarAnonimo() async {
    final cred = await _auth.signInAnonymously();
    return _fetchOCrearPerfil(cred.user!, displayName: 'Jugador Demo');
  }

  @override
  Future<PerfilUsuario> registrar({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user!.updateDisplayName(displayName);
    return _fetchOCrearPerfil(cred.user!, displayName: displayName);
  }

  @override
  Future<PerfilUsuario> entrarConEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _fetchPerfil(cred.user!);
  }

  @override
  Future<PerfilUsuario> entrarConGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Login con Google cancelado');
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return _fetchOCrearPerfil(
      cred.user!,
      displayName: googleUser.displayName ?? 'Jugador',
    );
  }

  @override
  Future<PerfilUsuario> vincularConEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa para convertir.');
    final UserCredential cred;
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      cred = await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // Solo los errores de la vinculación Auth se propagan a la UI.
      throw Exception(_mensajeVinculacion(e.code));
    }
    // A partir de aquí la cuenta YA es permanente: nada debe bloquear al
    // usuario ni propagar un error que rompa el flujo de reintento.
    try {
      await cred.user!.updateDisplayName(displayName);
    } catch (e) {
      debugPrint('Conversión: no se pudo actualizar displayName en Auth: $e');
    }
    return _finalizarConversion(
      cred.user!,
      displayName: displayName,
      email: email,
    );
  }

  @override
  Future<PerfilUsuario> vincularConGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa para convertir.');
    final UserCredential cred;
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Vinculación con Google cancelada.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mensajeVinculacion(e.code));
    } catch (e) {
      // google_sign_in puede lanzar PlatformException (Play Services caído, sin
      // red, OAuth mal configurado) que no es FirebaseAuthException. La
      // cancelación del usuario ya se relanza con su propio mensaje.
      if (e.toString().contains('cancelada')) rethrow;
      throw Exception('No se pudo conectar con Google. Intenta de nuevo.');
    }
    // Cuenta ya permanente. Se copian nombre/avatar de Google al perfil dentro
    // de _finalizarConversion (que no relanza si la escritura falla).
    final linked = cred.user!;
    return _finalizarConversion(
      linked,
      displayName: linked.displayName ?? 'Jugador',
      email: linked.email ?? '',
      avatar: linked.photoURL,
    );
  }

  @override
  Future<void> salir() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Cierra la conversión tras una vinculación Auth exitosa: actualiza el perfil
  /// en Firestore y devuelve el perfil ya convertido. El bono lo reclama
  /// [_fetchPerfil] al detectar el estado «convertido pero sin bono», de modo
  /// que haya un único punto de reclamo (idempotente) y nada bloquee al usuario.
  Future<PerfilUsuario> _finalizarConversion(
    User user, {
    String? displayName,
    String? email,
    String? avatar,
  }) async {
    // linkWithCredential no toca el doc de Firestore; copiamos nombre/email/
    // avatar. Fire-and-forget: si falla, la conversión ya fue exitosa.
    try {
      await _db.collection('users').doc(user.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (avatar != null) 'avatar': avatar,
      });
    } catch (e) {
      debugPrint('Conversión: no se pudo actualizar el perfil: $e');
    }
    // La cuenta ya es permanente: si la lectura del perfil falla (red), no
    // propagamos —el perfilStream lo corregirá— y devolvemos un perfil mínimo.
    try {
      return await _fetchPerfil(user);
    } catch (e) {
      debugPrint('Conversión: error al leer perfil post-link: $e');
      return PerfilUsuario(
        uid: user.uid,
        displayName: displayName ?? user.displayName ?? 'Jugador',
        email: email ?? user.email ?? '',
        avatar: avatar ?? user.photoURL ?? '🃏',
        balance: 0,
        inviteCode: '',
        isAnonymous: false,
      );
    }
  }

  /// Reclamos de bono en vuelo, por uid, para no disparar llamadas concurrentes
  /// a la Function (el refresco de token re-emite en `userChanges()`).
  final Set<String> _bonoEnProgreso = {};

  /// Refresca el token (para que deje de ser anónimo) y reclama el bono de
  /// conversión. La Function es idempotente y nunca relanza: si falla, el bono
  /// queda pendiente y se reintenta en el próximo [_fetchPerfil].
  Future<void> _reclamarBonoConversion(User user) async {
    if (_bonoEnProgreso.contains(user.uid)) return;
    _bonoEnProgreso.add(user.uid);
    try {
      await user.getIdToken(true);
      await _functions.httpsCallable('claimConversionBonus').call<void>();
    } catch (e) {
      debugPrint('Conversión: bono pendiente, se reintentará: $e');
    } finally {
      _bonoEnProgreso.remove(user.uid);
    }
  }

  Future<PerfilUsuario> _fetchPerfil(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return _fetchOCrearPerfil(user);

    // Estado «convertido pero sin bono»: el token ya no es anónimo pero el doc
    // sigue marcado como anónimo (la Function es quien lo pone en false al
    // pagar). Se reintenta el bono y se relee el perfil ya actualizado.
    final docAnonimo = (doc.data()?['isAnonymous'] as bool?) ?? false;
    if (!user.isAnonymous && docAnonimo) {
      await _reclamarBonoConversion(user);
      final fresco = await _db.collection('users').doc(user.uid).get();
      return _fromDoc(fresco, user);
    }

    return _fromDoc(doc, user);
  }

  Future<PerfilUsuario> _fetchOCrearPerfil(
    User user, {
    String? displayName,
  }) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (doc.exists) return _fromDoc(doc, user);

    final nombre = displayName ?? user.displayName ?? 'Jugador';
    final codigo = _generarCodigo(user.uid);
    final datos = {
      'displayName': nombre,
      'email': user.email ?? '',
      'avatar': user.photoURL ?? '🃏',
      'balance': 1000, // Bono de bienvenida (en Fase 5 lo hará la Function)
      'inviteCode': codigo,
      'isAnonymous': user.isAnonymous,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
    };
    // Escritura atómica: perfil + entrada en lookup-table de códigos.
    // Si alguna de las dos falla, el batch completo se revierte y el usuario
    // no queda en un estado inconsistente (sin código de invitación visible).
    final batch = _db.batch();
    batch.set(ref, datos);
    batch.set(_db.collection('invite_codes').doc(codigo), {
      'uid': user.uid,
      'displayName': nombre,
      'avatar': user.photoURL ?? '🃏',
    });
    await batch.commit();
    return PerfilUsuario(
      uid: user.uid,
      displayName: nombre,
      email: user.email ?? '',
      avatar: user.photoURL ?? '🃏',
      balance: 1000,
      inviteCode: codigo,
      isAnonymous: user.isAnonymous,
    );
  }

  PerfilUsuario _fromDoc(DocumentSnapshot doc, User user) {
    final d = doc.data() as Map<String, dynamic>;
    return PerfilUsuario(
      uid: user.uid,
      displayName: d['displayName'] as String? ?? 'Jugador',
      email: d['email'] as String? ?? '',
      avatar: d['avatar'] as String? ?? '🃏',
      balance: d['balance'] as int? ?? 0,
      inviteCode: d['inviteCode'] as String? ?? '',
      // Fuente de verdad: el token Auth, no el campo Firestore. El doc se
      // actualiza al final de claimConversionBonus; leer Firestore aquí dejaría
      // isAnonymous: true durante la ventana post-link / pre-Function y el banner
      // de conversión reaparecería brevemente.
      isAnonymous: user.isAnonymous,
    );
  }

  String _generarCodigo(String uid) {
    final parte = uid.substring(0, 4).toUpperCase();
    return 'BJ-$parte';
  }

  /// Traduce códigos de FirebaseAuthException a mensajes en español. La
  /// presentación no debe depender de los tipos de Firebase (lección de Fase 4).
  String _mensajeVinculacion(String code) => switch (code) {
        'credential-already-in-use' ||
        'email-already-in-use' ||
        'provider-already-linked' =>
          'Ese email ya tiene una cuenta. Inicia sesión en ella, pero perderás '
              'el progreso de esta sesión de demo.',
        'account-exists-with-different-credential' =>
          'Ya existe una cuenta con ese email usando otro método de inicio de '
              'sesión. Entra con el método original (email/contraseña o Google).',
        'invalid-email' => 'Email inválido.',
        'weak-password' => 'Contraseña muy débil (mín. 6 caracteres).',
        'requires-recent-login' =>
          'La sesión de seguridad ha expirado y no es posible completar la '
              'conversión ahora. Tu progreso del demo sigue activo; puedes seguir '
              'jugando.',
        _ => 'No se pudo crear la cuenta. Intenta de nuevo.',
      };
}
