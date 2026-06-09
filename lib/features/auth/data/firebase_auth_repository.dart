import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    return _auth.authStateChanges().asyncMap((user) async {
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
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      final cred = await user.linkWithCredential(credential);
      await cred.user!.updateDisplayName(displayName);
      // El nombre editado en el formulario reemplaza al del demo.
      await _db.collection('users').doc(user.uid).update({
        'displayName': displayName,
        'email': email,
      });
      return _finalizarConversion(cred.user!);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mensajeVinculacion(e.code));
    }
  }

  @override
  Future<PerfilUsuario> vincularConGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay sesión activa para convertir.');
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
      final cred = await user.linkWithCredential(credential);
      final linked = cred.user!;
      // linkWithCredential actualiza Firebase Auth pero NO el doc de Firestore;
      // se copia el nombre/avatar de Google al perfil. Es fire-and-forget: si
      // falla, la conversión ya fue exitosa y el usuario puede editarlo después.
      try {
        await _db.collection('users').doc(user.uid).update({
          'displayName': linked.displayName ?? 'Jugador',
          'email': linked.email ?? '',
          if (linked.photoURL != null) 'avatar': linked.photoURL,
        });
      } catch (_) {
        // Ignorado a propósito (ver comentario arriba).
      }
      return _finalizarConversion(linked);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mensajeVinculacion(e.code));
    }
  }

  @override
  Future<void> salir() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Tras vincular: refresca el token (para que ya no sea anónimo), invoca la
  /// Function que acredita el bono y devuelve el perfil actualizado.
  Future<PerfilUsuario> _finalizarConversion(User user) async {
    // Refresco obligatorio: sin esto el token en caché sigue siendo anónimo y
    // la Function rechaza la llamada con failed-precondition.
    await user.getIdToken(true);
    try {
      await _functions.httpsCallable('claimConversionBonus').call<void>();
    } on FirebaseFunctionsException catch (e) {
      // La conversión Auth ya fue exitosa; si el bono falla el cliente puede
      // reintentar (la Function es idempotente). No bloqueamos al usuario.
      throw Exception(_mensajeBono(e.code, e.message));
    }
    return _fetchPerfil(user);
  }

  Future<PerfilUsuario> _fetchPerfil(User user) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return _fetchOCrearPerfil(user);
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
        'invalid-email' => 'Email inválido.',
        'weak-password' => 'Contraseña muy débil (mín. 6 caracteres).',
        'requires-recent-login' =>
          'La sesión de seguridad ha expirado y no es posible completar la '
              'conversión ahora. Tu progreso del demo sigue activo; puedes seguir '
              'jugando.',
        _ => 'No se pudo crear la cuenta. Intenta de nuevo.',
      };

  String _mensajeBono(String? code, String? message) => switch (code) {
        'failed-precondition' =>
          'La cuenta no es elegible para el bono de conversión.',
        'not-found' => 'Perfil de usuario no encontrado.',
        _ =>
          'No se pudo acreditar el bono: ${message ?? code ?? 'desconocido'}',
      };
}
