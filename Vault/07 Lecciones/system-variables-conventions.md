---
aliases: ["System variable conventions"]
tipo: leccion
tema: formulas-evaluador
tags: [leccion, formulas-evaluador, reference]
origen: c60bb641-6f64-4ab1-9d8b-eabba2faf874
actualizado: 2026-10-04
---

# System variable conventions

**En una frase:** Reserved system-variable tokens resolved by Contexto Liquidación (Cod50016)

Reserved calc tokens are resolved by `Contexto Liquidación` (Cod50016) in the `case` on `Cód. Cálculo`. Adding one now touches **three** places, not two: the case in Cod50016, the `Opciones` StrMenu + doc comment in `Variable Sistema Liq.` (Tab60018), and the `Agregar(...)` list in `Gestión Variables Sistema` (Cod50077), which seeds the catalogue idempotently for a fresh company. A token missing from Cod50016's case now raises a warning instead of silently valuing zero.

Marea/franco-related tokens:
- `DIAS_PROYECTO` / `DIAS_PUERTO` — navigation / port (boundary) days of the marea in the billing window (AM/PM rule). `DIAS_MAREA` is their sum.
- `DIAS_ENROLAMIENTO` — calendar days enrolled across the WHOLE marea in states flagged `Devenga Francos` (base for franco accrual).
- `DIAS_FRANCOS_PERIODO` — calendar days in a Tipo Estado=Francos state within the period.
- `PAGO_FRANCOS_FIFO`, `FRANCOS_CONSUMIDOS`, `SALDO_FRANCOS` — delegate to Gestión Francos (Cod50053), passing FLiqNo to exclude the current liq from FIFO netting.

Tokens with `Ñ` (`AÑOS_ANTIGUEDAD`, `DIAS_HAB_AÑO`, `DIAS_ALTA_AÑO`): renamed from the `ANIOS`/`ANIO` spelling on 2026-08-25. **The data-side rename was done by hand, deliberately — no upgrade codeunit exists and none is needed.** Don't flag its absence as an incomplete migration.

Parameter suffix cascade: the `Sufijo Empleado` / `Sufijo CCT` / `Sufijo Convenio` flags on `Parámetro` (Tab60016) are **obsolete** — the cascade no longer branches on them. `Claves Parámetro Liq.` (Cod50071) is the single owner: it builds every candidate (`CÓD_<EMP>` → `CÓD_<CONVENIO>_<CATEGORÍA>` → `CÓD_<CONVENIO>` → `CÓD`) and the most specific one with a loaded value wins. `Resolver` works off a preloaded map; `ResolverEnTabla` hits `Parámetro Vigente` for callers without one. Reserved param base codes: `COEF_FRANCOS`, `VALOR_FRANCO`. See [[francos-fifo-ledger]].

## Relacionado

- [[variable-sistema-hay-que-sembrarla]]
- [[variables-rotas-valen-cero]]
- Tema: `formulas-evaluador` (ver [[_Convenciones del vault]])
