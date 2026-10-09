---
aliases: ["Novedades pre-liquidación"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
origen: 9be8057e-0e48-430a-b6b0-cc4322f51ebc
actualizado: 2026-08-10
---

# Novedades pre-liquidación

**En una frase:** Novedades are loaded before the liquidación exists and materialize into Incidencias at calculation time

Payroll inputs have **two** entry points, and they are not interchangeable:

- **Novedad Liquidación** (Tab60034, built 2026-08-07) — loaded against a *período*, before any liquidación exists. Selector fields blank = "cualquiera": Tipo Liq. / Convenio / Categoría / Empleado / Proyecto, plus a Fecha inside the period. `Gestión Novedades Liq.` (Cod50061) materializes them as Incidencias from the motor, idempotently, on every recalculation.
- **Incidencia Liquidación** (Tab60020) — keyed by No. Liquidación, so it needs the liquidación in Borrador. Rep50044 + Cod50052 do the mass load over *existing* liquidaciones.

Design rules the user chose explicitly: novedades apply **automatically at calculation** (never a manual transfer step); an incidencia already present for that concepto is **respected** and the novedad stays Pendiente with the reason in `Motivo No Aplicada`; several novedades of one concepto **sum** into the single incidencia the PK allows. The `Desde Novedad` boolean on Tab60020 marks generated rows so recalculation can delete and rebuild only those — and Tab60020's OnModify clears it, so hand-editing a generated incidencia converts it to manual and protects the edit.

**AL gotchas this project has hit more than once:**
- `DeleteAll()` / `Modify()` without the boolean argument do **not** fire table triggers. That is why deleting generated incidencias never trips Tab60020's Borrador guard.
- **A `[TryFunction]` cannot write to the database** — it fails at runtime, not at compile time (`NavNclTryFunctionWriteException`, "no se permite MODIFY... cuando se usa como un objeto TryFunction"). To catch a failure around code that writes, use `Codeunit.Run` with a `TableNo` codeunit instead: it opens its own transaction scope, rolls back only its own work, and returns false. Precedents: Cod50052 "Gestión Incidencia Masiva" (called from a report) and Cod50069 "Ejecutor Liquidación" (so a failed calculation can still be logged).

See [[estado-empleado-effective-dated]] and [[acumuladores-orden-calculo]].

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[orden-calculo-del-lote]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
