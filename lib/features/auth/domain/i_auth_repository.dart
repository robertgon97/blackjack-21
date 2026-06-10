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

  /// Convierte la cuenta anónima actual en permanente vinculando email/contraseña
  /// (account linking). Conserva el mismo `uid` y acredita el bono de conversión.
  /// Lanza una excepción con mensaje en español si la vinculación falla.
  Future<PerfilUsuario> vincularConEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Convierte la cuenta anónima actual en permanente vinculando Google.
  /// Conserva el mismo `uid` y acredita el bono de conversión.
  Future<PerfilUsuario> vincularConGoogle();

  /// Cierra la sesión actual.
  Future<void> salir();
}
