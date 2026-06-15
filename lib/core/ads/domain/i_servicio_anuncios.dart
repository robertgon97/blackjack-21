/// Servicio de anuncios (AdMob). Abstrae el proveedor y la guarda de plataforma
/// —igual que telemetría/App Check/push— para que la UI solo pregunte si hay
/// anuncios disponibles y pida mostrar uno recompensado.
abstract interface class IServicioAnuncios {
  /// Inicializa el SDK de anuncios (solo Android/iOS). Nunca lanza.
  Future<void> inicializar();

  /// ¿Hay anuncios en esta plataforma? `false` en Web/escritorio → la UI oculta
  /// el botón de "ver anuncio".
  bool get disponible;

  /// Carga y muestra un anuncio **recompensado** asociado a [uid]. Devuelve
  /// `true` si el usuario lo vio completo; `false` si no se pudo cargar, se
  /// cerró antes, o la plataforma no soporta anuncios.
  ///
  /// La **acreditación NO la hace el cliente**: AdMob notifica a la Cloud
  /// Function `admobSsv` con la verificación firmada (SSV), que acredita los
  /// créditos al [uid]. Por eso el `uid` viaja como `userId` del anuncio.
  Future<bool> mostrarRecompensado(String uid);
}
