// ============================================================
//  Panel de ajustes: edita las reglas de la mesa (ConfigJuego)
// ============================================================

import 'package:flutter/material.dart';

import '../../domain/modelos.dart';

/// Hoja inferior para cambiar las variantes de casa. Trabaja sobre una copia
/// local y la entrega por [onGuardar] al confirmar.
class PanelAjustes extends StatefulWidget {
  final ConfigJuego config;
  final ValueChanged<ConfigJuego> onGuardar;

  const PanelAjustes({
    super.key,
    required this.config,
    required this.onGuardar,
  });

  @override
  State<PanelAjustes> createState() => _PanelAjustesState();
}

class _PanelAjustesState extends State<PanelAjustes> {
  late ConfigJuego _config;

  @override
  void initState() {
    super.initState();
    _config = widget.config;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Reglas de la mesa',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              _filaBarajas(),
              _filaPagoBlackjack(),
              _switch(
                'H17: crupier pide con 17 suave',
                _config.crupierPideEn17Suave,
                (v) => setState(
                  () => _config = _config.copyWith(crupierPideEn17Suave: v),
                ),
              ),
              _switch(
                'Empuje en 22 (crupier 22 = empate)',
                _config.empujeEn22,
                (v) =>
                    setState(() => _config = _config.copyWith(empujeEn22: v)),
              ),
              _switch(
                'Permitir rendirse',
                _config.permitirRendirse,
                (v) => setState(
                  () => _config = _config.copyWith(permitirRendirse: v),
                ),
              ),
              const Divider(),
              _switch(
                'Modo entrenamiento (avisa errores)',
                _config.modoEntrenamiento,
                (v) => setState(
                  () => _config = _config.copyWith(modoEntrenamiento: v),
                ),
              ),
              _switch(
                'Mostrar conteo Hi-Lo',
                _config.mostrarConteo,
                (v) => setState(
                  () => _config = _config.copyWith(mostrarConteo: v),
                ),
              ),
              _switch(
                'Mostrar probabilidad de pasarse',
                _config.mostrarProbabilidad,
                (v) => setState(
                  () => _config = _config.copyWith(mostrarProbabilidad: v),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton(
                  onPressed: () {
                    widget.onGuardar(_config);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaBarajas() {
    return Row(
      children: [
        const Expanded(child: Text('Barajas en el shoe')),
        Text('${_config.numBarajas}'),
        SizedBox(
          width: 180,
          child: Slider(
            value: _config.numBarajas.toDouble(),
            min: 1,
            max: 8,
            divisions: 7,
            label: '${_config.numBarajas}',
            onChanged: (v) => setState(
              () => _config = _config.copyWith(numBarajas: v.round()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filaPagoBlackjack() {
    final es32 = _config.pagoBlackjack == 1.5;
    return Row(
      children: [
        const Expanded(child: Text('Pago de blackjack')),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: true, label: Text('3:2')),
            ButtonSegment<bool>(value: false, label: Text('6:5')),
          ],
          selected: {es32},
          onSelectionChanged: (s) => setState(
            () =>
                _config = _config.copyWith(pagoBlackjack: s.first ? 1.5 : 1.2),
          ),
        ),
      ],
    );
  }

  Widget _switch(String texto, bool valor, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(texto),
      value: valor,
      onChanged: onChanged,
    );
  }
}
