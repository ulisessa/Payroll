---
aliases: ["Conceptos: tres vigencias independientes"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
origen: 9be8057e-0e48-430a-b6b0-cc4322f51ebc
actualizado: 2026-08-11
---

# Conceptos: tres vigencias independientes

La fórmula de un concepto, su distribución en acumuladores y sus restricciones por CCT son tres historiales de vigencia independientes.

Un concepto de liquidación no se versiona como una unidad. Tres tablas llevan su propia `Vigencia Desde` y el motor resuelve cada una **independientemente de las otras**:

| Aspect | Table | Engine resolution |
|---|---|---|
| Formula, orden, tipo, flags | `Concepto Liquidación` (Tab60007) | latest version <= FechaRef (`BuildLatestVersionCache`) |
| Accumulator distribution | `Fracción Acumulador` (Tab60017) | per (concepto, acumulador), latest <= FechaRef (`BuildFractionCache`) |
| CCT restrictions | `Concepto CCT Vigente` (Tab60019) | latest <= FechaRef (`CCTAplicaAConcepto`) |

**This is deliberate and worth keeping** — changing a formula in 2026 must not force redeclaring a distribution that didn't change. Do not "fix" it by slaving the child tables to the concept's version.

The consequence that bites: creating a new concept vigencia carries none of the others forward, and that is *correct* — the engine keeps applying the previous distribution/CCT. Both subpages on the Concepto card therefore list **all** vigencias (fixed 2026-08-11; the Fracciones one used to filter by the concept's exact date and showed empty while the engine still distributed). Fracciones marks the in-force rows with a `Vigente` column computed with the engine's own rule.

All four gaps found in that analysis were fixed the same day:
- `CopiarEn` (Tab60007) now copies CCT rows (it copied none — and "no rows" means "applies to every convenio", so a copy of a convenio-restricted concept used to pay the whole payroll) and copies fracciones of **all** vigencias, not just the one being viewed.
- `InitAccumulators` (Cod50016) and `EnsureConceptCaches` (Cod50014) now resolve `Es Acumulador`/`Activo` on the **version in force at FechaRef**, matching `WriteAccumulatorLines`.
- `Línea Liquidación."Vigencias Distribución"` (Text[250], `ACUM:AAAAMMDD|…`, same shape as `Fuente Parámetros`) stamps which fracción vigencia applied per accumulator.

**`Activo` was replaced by `Vigencia Hasta` (Tab60007 field 12, 2026-08-11.)** The boolean could not discontinue a concept: the engine filtered `Activo` *before* picking the version, so an inactive version became invisible and the engine fell back to the previous active one and kept running it. A date has no ordering to get wrong — the interval is part of the selection predicate.

Rules that follow, all enforced in Tab60007:
- Resolution goes through `VigenteA(FechaRef)` / `FiltrarVigentesA(FechaRef)` — the only two places the rule lives. `Activo` is still checked inside `VigenteA`, *after* the version is chosen, and goes away when the field is retired.
- Versions auto-chain (inserting one closes the previous the day before) but **only if the previous is open**. A gap is legitimate and deliberate — close a concept in March, need it again in July — so overlap is an error, never a silent correction.
- Closing a vigencia is blocked only if it lands *before* a non-Borrador liquidación that used that version (directional; moving it forward always passes). Uses Tab60012 key K6.
- `SetFilter` on a blank date needs `'''''|>=%1'`, not `%1` over 0D — 0D substitutes as empty text and yields a broken filter.

Migration is not automatable: existing `Activo = false` rows mean "invisible", which has no date equivalent. Page 110006 "Versiones Inactivas a Revisar" diagnoses each one instead.

Still open: the CCT vigencia is not stamped on the line — only the distribution is. And `Concepto CCT Vigente` is the one table that genuinely needs its own `Vigencia Hasta`, because its payload *is* the row's existence (a fracción expresses "lost it" with `Porcentaje = 0`; a CCT row cannot express absence).

See [[acumuladores-orden-calculo]].

## Relacionado

- [[acumuladores-orden-calculo]]
- [[cobertura-devengado-tapa-dias]]
- [[cobertura-en-tramos]]
- [[concepto-negativo-despues-de-sus-consumidores]]
