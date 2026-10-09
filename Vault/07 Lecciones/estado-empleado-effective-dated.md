---
aliases: ["Estado Empleado con historial por vigencia"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
origen: c60bb641-6f64-4ab1-9d8b-eabba2faf874
actualizado: 2026-08-07
---

# Estado Empleado con historial por vigencia

Estado Empleado es un historial contiguo y mixto (empleado y buque) con Fecha Fin mantenida por la tabla. (El cuerpo conserva el texto técnico original, en inglés.)

The `Estado Empleado` table (Tab60000) is a **contiguous dated history with a stored `Fecha Fin`** (field 4, restored 2026-08-07 after a period without it — the user considered its removal an unnecessary change). Blank Fecha Fin = open state. **There are never gaps**: the table triggers keep `Fecha Fin` = next state's Fecha Inicio − 1 (`SincronizarContiguidad`), and editing Fecha Fin by hand pushes the next state's Fecha Inicio to Fecha Fin + 1 (`EmpujarSiguienteEstado`). Only the last state can be closed with no successor (a Baja) — that is the one case where an employee ends up with no state, and `GetEstadoEntidad` (Cod50017) returns false past that date. A Vacaciones state proposes Fecha Fin = Fecha Inicio + LCT days − 1, editable.

Read the end through `Rec.FechaFinEfectiva()`, never the raw field: it returns the stored Fecha Fin, falling back to the derived next-start−1 (or 31/12/9999) for rows written before the field existed. Cod50062 backfills existing data once per company via an Upgrade Tag.

It is **mixed entity**: `Tipo Entidad` (Enum 50317: Empleado/Buque) discriminates; field 1 (caption "Cód. Entidad") holds the employee no. OR the vessel code (= Global Dimension 1 value; there is no vessel master). Lookups go through `Gestión Estado Empleado` (Cod50017): `GetEstadoEntidad`, `SetEstadoEntidad`, `GetEstado`/`SetEstado` (employee overloads).

The **"Fin Efectivo"** boolean on Fuente Datos Liquidación (Tab60015) still exists and still works — it derives an interval end as the next row's start − 1 for effective-dated tables without a Fecha Fin. Sources over Estado Empleado can now instead point "No. Campo Fecha Fin" at the real field; that is data configuration, not code.

Vessel states cascade to employees via `SetEstadoBuque`: a **productive→improductive** vessel transition (productive = state's `Devenga Francos` flag on Cód. Estado Empleado / Tab60003) advances each related employee to their OWN current state's `Estado Siguiente` (e.g. embarcado → Francos), effective day-after-arrival. Batch loading via Pag50191 "Buques" and an Employee List action. Cód. Estado Empleado has: `Ámbito` (Enum 50318), `Estado Siguiente` (transition chain), `Devenga Francos`, `Tipo Estado` (Enum 50308: Normal/Alta/Baja/Vacaciones/Francos). Antigüedad = Alta→Baja periods by Fecha Inicio. See [[francos-fifo-ledger]] and [[novedades-pre-liquidacion]].

## Relacionado

- [[francos-fifo-ledger]]
- [[novedades-pre-liquidacion]]
- [[algo-parte-estados-en-dos]]
- [[fases-bc-contra-meta4]]
- [[gp-devenga-francos-pero-es-improductivo]]
