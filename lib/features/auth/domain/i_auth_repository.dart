import 'perfil_usuario.dart';

/// Contrato de autenticación. La capa data implementa esta interfaz;
/// la presentación y el domain solo conocen esta abstracción.
abstract interface class IAuthRepository {
  /// Stream del perfil autenticado; emite `null` cuando no hay sesión.
  Stream<PerfilUsuario?> get perfilStream;

  /// Último perfil conocido (sincrónico).
  PerfilUsuario? get perfilActual;

  /// Inicia sesión anónima (modo demo).
  Future<PerfilUsuario> entrarAnonimo();

  /// Registro con email y contraseña.
  Future<PerfilUsuario> registrar({
    required String email,
    required String password,
    required String displayName,
  });

  /// Login con email y contraseña.
  Future<PerfilUsuario> entrarConEmail({
    required String email,
    required String password,
  });

  /// Login con Google.
  Future<PerfilUsuario> entrarConGoogle();

  /// Cierra la sesión actual.
  Future<void> salir();
}
