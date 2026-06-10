# Plan: Perfil, progresión y leaderboards

> Documento vivo. Continúa el [plan maestro](00-app-multiplataforma.md). Cubre un hueco detectado:
> **no existe una feature de perfil**. Hoy solo hay un `PerfilUsuario` básico (nombre, avatar, saldo,
> código de invitación) y una `HistorialPage` de movimientos suelta en `wallet/`; no hay estadísticas
> de juego, ni niveles, ni logros, ni rankings. Estas fases lo completan con el "sabor" de una app de
> juego (progresión + competencia + enganche), en fases **pequeñas y autónomas**.

## Estado actual (qué hay y qué falta)

| Pieza | Estado |
|---|---|
| `PerfilUsuario` (uid, nombre, email, avatar, saldo, inviteCode, isAnonymous) | ✅ existe (en `auth/domain`) |
| `HistorialPage` — movimientos de saldo (`transactions`) | ✅ existe (en `wallet/`) |
| Feature `profile/` (pantalla de perfil dedicada) | ❌ no existe |
| Estadísticas de juego (manos, victorias, rachas…) | ❌ no existe |
| Niveles / XP / logros (el `stats.js` legacy nunca se migró) | ❌ no existe |
| Leaderboards / tops | ❌ no existe (solo se menciona "leaderboard" en Fase 7) |

## Decisión transversal — Anti-trampa (server-side)

Las estadísticas que cuentan para **niveles, logros y leaderboards** se escriben en **Cloud Functions**
(igual que el saldo), nunca desde el cliente. Encaja con `playerAction`, que ya resuelve las manos en
el servidor.

**Modo solo (jugador vs sistema) es client-side**, así que sus partidas **no cuentan** para rankings
ni logros oficiales (serían trampeables). Opciones para el modo solo: stats locales separadas y
"solo informativas", o no contarlas. Decisión por defecto: **solo el multijugador alimenta la
progresión oficial**; el modo solo puede mostrar stats locales etiquetadas como tales.

## Modelo de datos (propuesta, a confirmar al implementar)

- `users/{uid}.stats` (objeto, escrito por Functions): `manosJugadas`, `ganadas`, `perdidas`,
  `empates`, `blackjacks`, `mayorGanancia`, `rachaActual`, `mejorRacha`, `totalApostado`,
  `totalGanado`, `xp`, `nivel`.
- `users/{uid}/achievements/{logroId}` o un mapa `users/{uid}.logros`: logros desbloqueados + fecha.
- `leaderboards/{periodo}/entries/{uid}` (p. ej. `periodo = 2026-W24`): agregado semanal escrito por
  Functions al resolver; un **scheduled function** abre/cierra el periodo cada semana.
- Reutiliza la red social ya existente (`friendships`) para el **top entre amigos**.

---

## Fase 12 — Perfil y estadísticas

**Objetivo:** una pantalla de perfil de verdad, con las estadísticas de juego del usuario.

**Alcance:**
- Nueva feature `lib/features/profile/` (domain · data · presentation), respetando capas.
- Pantalla de perfil: cabecera (avatar y nombre **editables**, código de invitación, tipo de cuenta,
  "miembro desde"), saldo y acceso al **historial de movimientos** (enlaza la `HistorialPage` existente).
- **Estadísticas de juego** persistidas: `playerAction` acumula las stats en `users/{uid}.stats` dentro
  de la misma transacción de resolución. La UI las muestra (manos, % victoria, blackjacks, mayor
  ganancia, racha actual/mejor, total apostado/ganado).
- Ruta `/perfil` y entrada desde la barra de estado.

**No incluye:** niveles/logros (Fase 13) ni rankings (Fase 14).
**Plataformas:** todas (es Firestore + UI).
**Cierre:** stats reales tras jugar manos multijugador; pantalla de perfil navegable; ficha
`docs/features/perfil.md`. Sinergia: estos mismos eventos los registra Analytics (Fase 8).
**Dependencias:** ninguna dura; idealmente tras la Fase 5 (ya hecha).

---

## Fase 13 — Progresión (niveles + logros)

**Objetivo:** dar sensación de avance con el `stats.js` legacy migrado.

**Alcance:**
- Migrar `legacy-web/js/stats.js` (NIVELES, LOGROS, `nivelActual`) a `profile/domain/` como **lógica
  pura testeable** (sin Firebase), con sus tests.
- **XP y niveles:** la Function otorga XP al jugar/ganar; el nivel se deriva de la XP. Barra de
  progreso en el perfil.
- **Logros/insignias** desbloqueables: primer blackjack, 100 manos, racha de 5, "millonario", etc.
  Se evalúan server-side al resolver y se guardan; la UI muestra una galería de logros (con bloqueados
  en gris). Al desbloquear, un aviso/toast (y push si la Fase 7 ya está).

**Plataformas:** todas.
**Cierre:** subir de nivel y desbloquear un logro reales; tests de la lógica de niveles/logros; ficha
`docs/features/progresion.md`.
**Dependencias:** Fase 12 (stats persistidas).

---

## Fase 14 — Leaderboards y enganche

**Objetivo:** competencia y retención (lo "chévere").

**Alcance:**
- **Leaderboards semanales** (se reinician cada semana): por ganancias netas, por manos ganadas y por
  mejor racha. Agregación en `leaderboards/{periodo}` escrita por Functions; **scheduled function**
  para abrir/cerrar el periodo semanal.
- **Top entre amigos** (usa `friendships`) y **top global**; mostrar la **posición del usuario**
  ("estás #14 esta semana").
- **Enganche tipo juego:**
  - **Bono por login diario** (racha diaria) — Function idempotente por día, como el bono de conversión.
  - **Misiones diarias/semanales** ("gana 3 manos hoy", "haz un blackjack") con recompensa.
  - Con push (Fase 7): "subiste de nivel", "tu racha diaria expira pronto", "bajaste del top 10".

**Plataformas:** todas (la programación semanal vive en Functions, no en el cliente).
**Cierre:** un leaderboard semanal poblado y consultable, top de amigos, y el bono diario funcionando;
ficha `docs/features/leaderboards.md`.
**Dependencias:** Fase 12 (stats). El bono diario reutiliza el patrón de `claimConversionBonus`.

---

## Resumen de fases

| Fase | Contenido | Anti-trampa | Depende de |
|------|-----------|-------------|------------|
| 12 | Perfil + estadísticas de juego (server-side) | Functions escriben stats | — |
| 13 | Progresión: niveles/XP + logros (migra `stats.js`) | Functions otorgan XP/logros | Fase 12 |
| 14 | Leaderboards semanales + top amigos + bono diario + misiones | agregación y reset en Functions | Fase 12 |

## Nota sobre prioridad y orden

Los números son orientativos: estas fases de **producto** (perfil/progresión) pueden priorizarse
**antes** que las de infraestructura (App Distribution/Test Lab) según convenga. El perfil tiene
**sinergia con Analytics (Fase 8)**: los mismos eventos de juego que alimentan las stats se registran
como eventos de Analytics, así que conviene planificar ambas cerca.
