// ============================================================
//  Formateo de dinero (puro, sin Flutter)
//
//  Punto único para mostrar montos: si cambia el formato (separador
//  de miles, moneda, locale), se ajusta aquí y no en cada widget.
// ============================================================

/// Formatea un monto como `$1234`.
String dinero(int monto) => '\$$monto';

/// Formatea un monto con signo explícito: `+$50`, `-$50` o `$0`.
String dineroConSigno(int monto) {
  if (monto > 0) return '+\$$monto';
  if (monto < 0) return '-\$${monto.abs()}';
  return '\$0';
}
