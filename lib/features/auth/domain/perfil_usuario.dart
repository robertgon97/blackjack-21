/// Modelo de perfil de usuario (capa domain — sin Firebase ni Flutter).
class PerfilUsuario {
  const PerfilUsuario({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.avatar,
    required this.balance,
    required this.inviteCode,
    required this.isAnonymous,
    this.creadoEn,
  });

  final String uid;
  final String displayName;
  final String email;
  final String avatar;

  /// Saldo de créditos. En la Fase 3 el cliente lo lee; solo Functions lo escriben.
  final int balance;
  final String inviteCode;
  final bool isAnonymous;

  /// Fecha de creación de la cuenta ("miembro desde"). Es `null` en el perfil
  /// mínimo derivado del token y justo tras crear la cuenta (el `createdAt` de
  /// Firestore es un `serverTimestamp` que aún no se ha releído).
  final DateTime? creadoEn;

  PerfilUsuario copyWith({
    String? displayName,
    String? email,
    String? avatar,
    int? balance,
    String? inviteCode,
    bool? isAnonymous,
    DateTime? creadoEn,
  }) {
    return PerfilUsuario(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      balance: balance ?? this.balance,
      inviteCode: inviteCode ?? this.inviteCode,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
