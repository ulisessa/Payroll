---
aliases: ["Francos: libro FIFO"]
tipo: leccion
tema: francos
tags: [leccion, francos, project]
origen: c60bb641-6f64-4ab1-9d8b-eabba2faf874
actualizado: 2026-10-04
---

# Francos: libro FIFO

> [!note] Verificar: Al 2026-10-04 el precio sale de la categoría de la **liquidación que paga** (`ParQuePagaElFranco`); del lote sólo se toma la pesquería. Ver [[Valor del franco]].

Los francos compensatorios son un libro FIFO no fungible construido sobre Línea Liquidación. (Parte del cuerpo conserva el texto técnico original, en inglés.)

Francos compensatorios accrue during productive mareas and are paid when enjoyed. They are **FIFO and non-fungible**: each accrued day is sealed with the convenio/categoría it was earned under and paid at THAT category's value, not the employee's current one.

**No new table** — the ledger IS `Línea Liquidación` (Tab60012, has No. Empleado, Cód. Convenio, Cód. Categoría, Cantidad, Fecha Liquidación). Franco lines are identified by the concept's `Rol Franco` enum (50319: Ninguno/Devengo/Consumo) on Concepto Liquidación.

- **Devengo** (in Cierre Marea): concept with Es Devengo=true, Rol Franco=Devengo, cantidad = `REDONDEAR(COEF_FRANCOS * DIAS_ENROLAMIENTO + 1)`. COEF_FRANCOS = Parámetro Sufijo Convenio (0,52 for CCT 768/19, 0,50 for 729/15).
- **Devengo Cantidad**: for Rol Franco=Devengo the motor (Cod50014) puts the formula result (días) into `Cantidad` and zeroes `Importe` (lot valued only when consumed).
- **Consumo** (monthly liq, employee in Tipo Estado=Francos): concept with Rol Franco=Consumo, Fórmula = `DIAS_FRANCOS_PERIODO` (días a consumir). The motor does NOT emit a single line — it calls `Gestión Francos.CalcularConsumoDesglosado` and expands into **one línea per lot category** (FIFO), each with Cantidad=días, Importe=días×VALOR_FRANCO(categoría del lote), Cód. Categoría/Convenio = the lot's. So the recibo shows the per-category price breakdown. `PAGO_FRANCOS_FIFO`/`FRANCOS_CONSUMIDOS` system vars are no longer needed for the concept (kept for optional display).

**Francos state bounded by balance**: francos are enjoyed in port (no project) — the payment rides on a **Regular** liquidation created per-employee for those in a Francos state (`CrearRegularEmpleadosEnFrancos`, motor skips project validation when No. Proyecto=''). Before calculating, the motor calls `Gestión Estado Empleado.AjustarEstadoFrancos`: if the franco balance runs out on/before the period end, it inserts the Francos state's `Estado Siguiente` (e.g. Francos→Órdenes) at `Fecha Inicio + SaldoFrancosAFecha`, so DIAS_FRANCOS_PERIODO counts only covered days and the rest falls into the next state. `SaldoFrancosAFecha` = accrued(≤fecha) − consumed(<fecha), stable across the period's own consumption.

FIFO valuation done by `Gestión Francos` (Cod50053): walks Devengo lots oldest-first, nets prior Consumo, values each slice via reserved parameter `VALOR_FRANCO_<CONVENIO>_<CATEGORÍA>` (Sufijo CCT) at pay date. See [[system-variables-conventions]] and [[estado-empleado-effective-dated]].

**El lote no guarda plata: guarda convenio y categoría.** `Gestión Francos.ValorFrancoDia` busca el parámetro `VALOR_FRANCO_<convenio>_<categoría>` vigente **a la fecha de pago**, así que el diseño ya paga el franco al valor del día en que se toma —el criterio de Meta4, confirmado por el usuario el 23/9/2026—. El campo `Valor Franco Estimado` del saldo inicial es informativo y **no** es lo que paga.

Sin el parámetro `ValorFrancoDia` devuelve **0 en silencio**: el 1063 sale con la cantidad correcta y el importe en cero. En enero 2026 eran 35 empleados y 493 días pagados a cero, y el síntoma se lee como "los días de franco no entran al cálculo" cuando en realidad entran perfecto.

De dónde sale el valor en Meta4: `PR_FRANCO` de `M4T_ACUMULADO_RL3`. En **oficiales** es constante por categoría (OF01 162.725 · OF02 141.500 · OF03 127.350 · OF04 120.275 en enero 2026, iguales en 175/75, 768/19 y ESP) y se cargó así. En **marinería no lo explica la categoría**: la misma convive con hasta cuatro precios, y tampoco lo explican el buque ni la categoría del lote. La escala va de a 3.797,04 —53.158,67 son 14 unidades, 56.955,67 son 15, 60.752,73 son 16, 64.549,80 son 17—, así que sigue un índice que no es la categoría: casi seguro el **puesto**, que no está migrado (ver [[puesto-vs-categoria-cct]]). Quedan 62 empleados y 2.849 días sin valor.

## Relacionado

- [[system-variables-conventions]]
- [[estado-empleado-effective-dated]]
- [[puesto-vs-categoria-cct]]
- [[a-cuenta-futuros-aumentos-francos]]
- [[franco-porcentaje-por-pesqueria]]
