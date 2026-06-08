import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/firestore_wallet_repository.dart';
import '../domain/i_wallet_repository.dart';
import '../domain/transaccion.dart';

final walletRepositoryProvider = Provider<IWalletRepository>(
  (_) => FirestoreWalletRepository(),
);

/// Saldo en tiempo real del usuario autenticado.
final saldoProvider = StreamProvider<int>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref.watch(walletRepositoryProvider).saldoStream(perfil.uid);
});

/// Historial de transacciones del usuario autenticado.
final transaccionesProvider = StreamProvider<List<Transaccion>>((ref) {
  final perfil = ref.watch(perfilStreamProvider).valueOrNull;
  if (perfil == null) return const Stream.empty();
  return ref
      .watch(walletRepositoryProvider)
      .transaccionesStream(perfil.uid);
});
