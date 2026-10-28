---
tipo: concepto
tags: [motor, tope-sipa, aportes, acumuladores]
fuente: [PROPUESTA_TOPE_SIPA_PERIODO.md, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Tables/Tab60018.VariableSistemaLiq.al]
actualizado: 2026-10-04
---

# Tope SIPA

Los aportes de seguridad social con tope (jubilación, ley 19.032, obra social y su adicional) se calculan
como `MIN(base, TOPE_SIPA) × porcentaje`. El **tope es mensual**, pero los **acumuladores son por
liquidación**: un empleado con varias liquidaciones en el mismo mes (Regular + Vacaciones + Cierres de
marea + Devengados) aplica el tope entero **en cada una**, salvo que la fórmula se coordine con lo ya
liquidado. No hay "lógica de tope" en AL: es **configuración** (parámetros `TOPE_SIPA`, `TOPE_SIPA_OS`,
`PCT_*`, acumuladores `BASE_SS_TRAB`/`BASE_OS_TRAB`, fórmulas de los conceptos 6000-6037) más dos
variables de sistema genéricas que dan el "ya liquidado".

## Herramientas del motor

| Variable (Cód. Cálculo) | Qué devuelve | Uso |
|---|---|---|
| `PERIODO_ACUM` + `Cód. Acumulador` | importe del acumulador ya liquidado en **otras** liquidaciones del **mismo código de período**, excluyendo Borrador y la actual | las `MES_BASE_*` (p. ej. `MES_BASE_SS_TRAB`, `MES_BASE_SS_VAC`) |
| `PERIODO_CONCEPTO` + `Cód. Concepto` | lo ya liquidado de **un** concepto en el **mes** (todos los períodos del mes: `...B`, `...C`) | "lo ya retenido" sin acumulador dedicado |

Patrón de uso documentado en el propio código (`CalcImportePeriodoPorAcumulador`):

```
MIN(BASE_SS_TRAB, MAX(0, TOPE_SIPA - BASE_SS_YA_LIQUIDADA)) * PCT_JUB
```

> [!warning] `PERIODO_ACUM` es por código de período; `PERIODO_CONCEPTO` es por mes
> Si un mes tiene dos períodos (`MENS072026` y `MENS072026B`), `PERIODO_ACUM` no ve las liquidaciones del
> otro período, y `PERIODO_CONCEPTO` sí (usa `Período Liquidación.CodigosDelMismoMes()`). Fue el motivo
> por el que existe `PERIODO_CONCEPTO`. Los períodos hoy son `aaaamm` ([[periodos-aaaamm]]).

Ambas **excluyen** la liquidación en curso por partida doble: por su número (vale al recalcular una ya calculada, cuyas líneas siguen en la base) y por estado `Borrador` (las creadas y sin calcular no consumieron tope). Cachean el histórico por liquidación (`CargarAcumHistorico`).

## El problema de fondo: no es estable ante recálculo

La coordinación con `MES_BASE_*` (restar a las otras suponiendo que cada una es la última en calcularse) es correcta en la **primera pasada y en orden**, pero no al **recalcular**. Con dos liquidaciones de bases `V` y `S` en el mes y `S + V > TOPE`:

| Momento | Aporte VAC | Aporte mensual | Total |
|---|---|---|---|
| primera pasada, VAC primero | `MIN(V, TOPE)` | `MIN(S, TOPE−V)` | `MIN(V+S, TOPE)` correcto |
| se recalcula la VAC | `MIN(V, TOPE−S)` | `MIN(S, TOPE−V)` | `2·TOPE−S−V` **retiene de menos** |

En enero de 2026, 86 de 284 legajos tenían dos o más liquidaciones que no son de vacaciones en el mes (el patrón `PUE + MAR + EMB` se repite): el caso expuesto es la mayoría.

Por eso el **orden de cálculo de las liquidaciones** importa: ver [[orden-calculo-del-lote]] (el lote ordena por empleado + período + `Orden` del tipo + `No.`) y [[Recálculo en cadena]].

## Propuesta: tope sobre el acumulado del período (`PROPUESTA_TOPE_SIPA_PERIODO.md`)

> [!note] Estado: propuesta
> Es un documento de diseño. Desde el repo **no se puede verificar** si se aplicó (la configuración vive
> en datos): ninguna fuente AL ni script nombra `JUB_LIQUIDADO`. Verificar en la base antes de afirmar
> que está en producción.

Cada liquidación calcula el aporte sobre el **acumulado del período** y descuenta **lo ya retenido**:

```
aporte = MAX(0, MIN(base_del_período, TOPE) * PCT − ya_retenido_en_el_período)
```

Es independiente del orden e idempotente ante recálculo (lo ya retenido es un hecho registrado). Lo que propone cargar, **todo como configuración**:

1. **Acumuladores nuevos** (sin fórmula): `JUB_LIQUIDADO`, `L19032_LIQUIDADO`, `OS_LIQUIDADO`, `ADIC_OS_LIQUIDADO`.
2. **Fracciones al 100 %**: 6000 y 6003 → `JUB_LIQUIDADO`; 6010 y 6013 → `L19032_LIQUIDADO`; 6030 y 6035 → `OS_LIQUIDADO`; 6032 y 6037 → `ADIC_OS_LIQUIDADO`.
3. **Variables de sistema** `PERIODO_ACUM` (`MES_JUB_LIQUIDADO`, `MES_L19032_LIQUIDADO`, `MES_OS_LIQUIDADO`, `MES_ADIC_OS_LIQUIDADO`).
4. **Fórmulas como vigencia nueva** (no editar la vigente: las liquidaciones calculadas deben poder reproducirse), por ejemplo 6000: `round(MAX(0, MIN(BASE_SS_TRAB + BASE_SS_VAC + MES_BASE_SS_TRAB + MES_BASE_SS_VAC, TOPE_SIPA) * PCT_JUB - MES_JUB_LIQUIDADO), 0.0001)`, con la condición de la variante regular ampliada con `AND (BASE_SS_VAC = 0)`.

Qué **no** cambia: cuota sindical (sin tope), contribuciones patronales (sin tope desde 2008) y los conceptos de **SAC** (medio tope sobre la mejor remuneración; ver [[tope-sac-por-liquidacion]]).

### Problemas adyacentes que registra el documento (sin resolver)

1. `BASE_SS` y `BASE_OS` son códigos **borrados** que siguen recibiendo fracciones (147 y 137 conceptos): ese importe no entra a ninguna base. `scripts/LimpiarFraccionesHuerfanas.sql` **borra sin reapuntar**. Ver el peligro en [[Acumuladores y fracciones]].
2. `gen_config.ps1` regenera el problema (su `$ACC_NAMES` lista `BASE_SS` y `BASE_OS`).
3. `IMPO_CNT_SS`: 149 fracciones a un acumulador que no existe como concepto.
4. 7030 (contribución patronal obra social) lee sólo `BASE_OS_TRAB`: en vacaciones da cero.
5. 6012 (ley 19.032 SAC) lee `BASE_SS_TRAB / 12` en vez de `BASE_SAC`.
6. 6037 usa la fórmula semilla de 2023 (lee la base del aguinaldo, sin `/100 * FAM_ADIC_OS`).

> [!warning] El punto 7 del documento está desactualizado
> Dice que el motor fija por nombre `DIAS_VAC_INICIO`, `NETO_GU` y `BASE_IG4` (`Cod50014:1791-1793`, `1756-1759`, `198-199`). **Ya no**: el neto garantizado sale de `Config. RRHH."Cód. Concepto Neto Garantizado"` y los haberes gravados de `"Cód. Acum. Haberes Gravados"` (TabExt52001), y `DIAS_VAC_INICIO` desapareció del motor. Las referencias de línea del documento ya no coinciden. Ver [[Grossing-up y tipo de cambio]] y [[Divergencias entre documentación vieja y código]].

## Cómo auditarlo en un caso

1. Sumar el **mes**: `PERIODO_ACUM`/`PERIODO_CONCEPTO` de la liquidación más el aporte propio no puede superar `TOPE × PCT`.
2. Mirar el **orden en que se calcularon** las liquidaciones del mes ([[Ciclo de cálculo de una liquidación]], validación cronológica).
3. Ver el detalle de variables de la línea del aporte: `MES_*` y `BASE_*` usados ([[Detalle del cálculo y trazabilidad]]).

## Relacionado

[[Variables de sistema]] · [[Acumuladores y fracciones]] · [[cuota-sindical-deducida-dos-veces]] · [[sindical-sac-base-equivocada]]
