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
  });

  final String uid;
  final String displayName;
  final String email;
  final String avatar;

  /// Saldo de créditos. En la Fase 3 el cliente lo lee; solo Functions lo escriben.
  final int balance;
  final String inviteCode;
  final bool isAnonymous;

  PerfilUsuario copyWith({
    String? displayName,
    String? email,
    String? avatar,
    int? balance,
    String? inviteCode,
    bool? isAnonymous,
  }) {
    return PerfilUsuario(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      balance: balance ?? this.balance,
      inviteCode: inviteCode ?? this.inviteCode,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }
}
