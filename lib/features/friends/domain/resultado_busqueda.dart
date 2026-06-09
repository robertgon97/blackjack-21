/// Resultado mínimo de buscar un usuario por código de invitación.
class ResultadoBusqueda {
  const ResultadoBusqueda({
    required this.uid,
    required this.displayName,
    required this.avatar,
  });

  final String uid;
  final String displayName;
  final String avatar;
}
