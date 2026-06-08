import 'package:flutter/material.dart';

/// Raíz de la aplicación Blackjack 21.
///
/// Por ahora es un placeholder: muestra la pantalla de inicio mientras se
/// implementa la UI completa en la Fase 2 (autenticación + navegación con
/// go_router + Riverpod).
class BlackjackApp extends StatelessWidget {
  const BlackjackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blackjack 21',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B5E20)),
        useMaterial3: true,
      ),
      home: const _PantallaInicio(),
    );
  }
}

class _PantallaInicio extends StatelessWidget {
  const _PantallaInicio();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '♠',
              style: TextStyle(fontSize: 80, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Blackjack 21',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fase 2: UI en desarrollo...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
