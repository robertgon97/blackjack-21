# Política de seguridad

Gracias por ayudar a mantener **Blackjack 21** seguro para todos sus jugadores.

## Versiones con soporte

Solo recibe correcciones de seguridad la última versión publicada en la rama `main`
(la que se despliega a producción: Web en GitHub Pages, APK/AAB de las releases y las
Cloud Functions). Las versiones anteriores no reciben parches.

| Versión            | ¿Recibe parches de seguridad? |
| ------------------ | :---------------------------: |
| Última en `main`   |              ✅               |
| Releases anteriores |              ❌               |

## Cómo reportar una vulnerabilidad

**Por favor, no abras un issue público ni un pull request para reportar una
vulnerabilidad.** Hacerlo expondría el fallo antes de que exista una corrección.

Usa el canal **privado** de GitHub:

1. Entra a la pestaña **Security** del repositorio.
2. Abre **Report a vulnerability** (sección *Advisories*).
3. Describe el problema con el mayor detalle posible.

Para que el reporte sea accionable, incluye cuando puedas:

- Una descripción del fallo y del impacto (qué se puede lograr explotándolo).
- Los pasos para reproducirlo (o una prueba de concepto).
- La parte afectada: app Flutter (Android/Web/Windows/iOS), Cloud Functions
  (`functions/`), reglas de Firestore (`firestore.rules`) o configuración de Firebase.
- Cualquier mitigación temporal que conozcas.

## Qué esperar

- **Acuse de recibo:** intentaremos confirmar la recepción en un plazo de **72 horas**.
- **Seguimiento:** te mantendremos al tanto del avance mientras se investiga y corrige.
- **Divulgación coordinada:** publicaremos un *security advisory* una vez que el parche
  esté desplegado. Si lo deseas, se te dará crédito por el hallazgo.

## Ámbito

Son especialmente relevantes los reportes sobre:

- **Integridad del saldo y la economía del juego:** cualquier forma de alterar
  `users/{uid}.balance` saltándose las Cloud Functions, o de manipular el resultado de
  una ronda (juego solo o salas multijugador).
- **Reglas de Firestore (`firestore.rules`):** lectura o escritura no autorizada de datos
  de otros usuarios.
- **Autenticación y cuentas:** suplantación, escalada de privilegios o fugas de datos
  entre cuentas.
- **Secretos:** exposición de claves, tokens o credenciales en el código o el historial.

> **Nota:** `lib/firebase_options.dart` está commiteado a propósito. Las claves de
> configuración del cliente Firebase (`apiKey`, `appId`, etc.) son **públicas por diseño**
> y no constituyen secretos de servidor; la protección real recae en las reglas de
> Firestore, App Check y las Cloud Functions. No es necesario reportarlo.

Gracias por la divulgación responsable.
