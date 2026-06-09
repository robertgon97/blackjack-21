import 'package:cloud_firestore/cloud_firestore.dart';
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
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final GoogleSignIn _googleSignIn;

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
  Future<void> salir() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

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
      isAnonymous: d['isAnonymous'] as bool? ?? user.isAnonymous,
    );
  }

  String _generarCodigo(String uid) {
    final parte = uid.substring(0, 4).toUpperCase();
    return 'BJ-$parte';
  }
}
