# Feature: <nombre>

> Copia este archivo a `docs/features/<nombre>.md` al crear la feature y rellénalo. Mantenlo al día
> cuando la feature cambie. Borra estas líneas de instrucción.

## Propósito

Una o dos frases: qué problema resuelve esta feature para el usuario.

## Reglas de negocio

Enlaza a los documentos de `reglas-negocio/` que apliquen y resume aquí las reglas específicas de esta
feature (incluidos límites y validaciones).

- Regla 1
- Regla 2

## Modelo de datos tocado

Qué colecciones/campos de Firestore lee o escribe (enlaza a
[`../arquitectura/modelo-datos.md`](../arquitectura/modelo-datos.md)).

## Estructura del código

```
features/<nombre>/
├── domain/        ← entidades + interfaces (qué hace, sin Flutter/Firebase)
├── data/          ← repositorios (implementación con Firebase/servicios)
└── presentation/  ← páginas, widgets y providers de Riverpod
```

Archivos y responsabilidades clave:
- `domain/...` —
- `data/...` —
- `presentation/...` —

## Dependencias externas

Paquetes o servicios (LiveKit, AdMob, etc.) y si están detrás de una abstracción en `domain`.

## Cloud Functions relacionadas

Lista las Functions que esta feature invoca y qué validan (enlaza a
[`../arquitectura/seguridad.md`](../arquitectura/seguridad.md)).

## Casos borde

- Caso 1 → comportamiento esperado
- Caso 2 → comportamiento esperado

## Cómo probarlo

- Tests automáticos (`flutter test`): qué cubren.
- Prueba manual: pasos para verificarlo end-to-end (incluyendo multi-dispositivo si aplica).
