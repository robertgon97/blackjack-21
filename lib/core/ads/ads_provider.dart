import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_factory_stub.dart' if (dart.library.io) 'ads_factory_io.dart';
import 'domain/i_servicio_anuncios.dart';

/// Servicio de anuncios según la plataforma: en Web se elige la fábrica stub
/// (no-op, sin importar google_mobile_ads); en móvil/escritorio la real.
final servicioAnunciosProvider =
    Provider<IServicioAnuncios>((ref) => crearServicioAnuncios());
