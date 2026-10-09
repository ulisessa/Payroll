---
tipo: concepto
tags: [motor, convenio, categoria, par-cct]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Enums/Enum50327.ParCCTLiq.al]
actualizado: 2026-10-04
---

# Par convenio-categoría por concepto

Todo el cálculo se resuelve con un **par (convenio, categoría)**: él decide el valor de los parámetros
(cascada `COD_<convenio>_<categoría>`), el `PCT_ESCALA` y la restricción por CCT de cada concepto.
Hay **dos pares** posibles en una liquidación.

## El par de la cabecera (encuadre del empleado)

En cada cálculo, `Convenio Categoría Liq.`.`ParDeEntidad` resincroniza `Liq."Cód. Convenio"` y
`Liq."Cód. Categoría"` desde los **atributos del empleado a `FechaRef`** (su encuadre con historial). Si no
hay atributos cargados a esa fecha se respeta lo que la liquidación ya traía (en una base a medio migrar:
el par de la ficha). Antes salía de la asignación al proyecto y una marea liquidaba **todos** sus
conceptos con la categoría del embarque. Ver [[atributos-tipados]] y [[puesto-vs-categoria-cct]].

## El par alterno: `Par CCT a Usar` del concepto

`Concepto Liquidación."Par CCT a Usar"` (enum `Par CCT Liq.`):

| Valor | Ordinal | Significado |
|---|---|---|
| `Entidad` | 0 | el del empleado (por defecto: un concepto que nadie tocó se comporta como siempre) |
| *(libre)* | 1 | era "el de la asignación al proyecto"; **eliminado el 18/9/2026** junto con los campos de convenio/categoría de `Personal Proyecto`. **No reutilizar el 1** |
| `Puesto` | 2 | el **puesto** con el que el empleado navega |

`Puesto` trae el **par entero**, convenio incluido (`ParCCT.ParDePuesto`), y se usa tal cual: un oficial de 768/19 que navega de Pesca tiene el puesto `FE01`, que es de otro convenio, y "cruzar" convenio de cabecera con categoría de puesto da `(768/19, FE01)`, un par inexistente que no rompe nada y devuelve ceros. Si el empleado **no tiene puesto vigente** a `FechaRef`, el concepto se evalúa con el par de la cabecera. Se usa para lo que se **paga por el embarque** (producción de marea) y no por el encuadre.

## Cómo lo aplica el motor

`AplicarParDeConcepto` (Cod50014) corre **antes** de las comprobaciones del concepto —incluida la restricción por CCT, que también tiene que mirar el par alterno— y devuelve `ConvenioEval`/`CategoriaEval`:

1. Si el concepto es `Entidad`, o el par del puesto no existe, o coincide con el de la cabecera → no cambia nada (`false`).
2. Si no: `CtxBuilder.UsarParCCT(convenio, categoría, Ctx)` recarga **sólo los parámetros** y `PCT_ESCALA`, y `Evaluador.UpdateContext`.
3. Al cerrar el cuerpo del bucle (cualquiera sea el camino: fórmula, incidencia, no aplica) `RestaurarParBase` vuelve al par original, para que el resto no se entere.

La **línea** se estampa con el par **con el que se calculó** (`ConvenioEval`/`CategoriaEval`): es el comprobante de su propio cálculo; si guardara el de la cabecera, un importe de producción quedaría documentado con otra categoría.

`UsarParCCT` guarda lo que está en el contexto antes de irse y mantiene **dos ranuras** (par del empleado y par alterno): después del primer cambio, todo el resto es memoria. Sin esto cada concepto marcado costaba dos reconstrucciones completas de la cascada.

## Trampas

> [!warning] `@CÓDIGO` ignora el par del concepto referenciado
> Re-evalúa con el par de **quien llama**. Para respetar el `Par CCT a Usar` del otro hay que leerlo con
> `#CÓDIGO` (y su `Orden Cálculo` debe ser menor). Visto el 18/9/2026 en el legajo 04649: la misma
> fórmula dio 46.571.665,92 (par ESP/FE01) y 32.098.728,96 (par 768/19/OF01), sin aviso. Ver
> [[arroba-ignora-el-par-del-concepto]].

> [!warning] Un parámetro homónimo de una fuente la pisa tras el cambio de par
> `UsarParCCT` no vuelve a correr las fuentes; si un parámetro tiene el mismo nombre que una fuente,
> a partir del cambio gana el parámetro. Ver [[tc-comprador-parametro-fantasma]] y
> [[Contexto de liquidación y variables]].

- `TipoEmpleadoDe` (qué población es) usa **siempre** el convenio de la cabecera: que un concepto se valorice bajo otro CCT no convierte a la persona en otra cosa.
- Las **variables de sistema** no se recalculan con el par alterno (sólo `PCT_ESCALA`): ninguna otra depende del par, y recalcular `LoadVariablesSistema` duplicaría las filas de `Detalle Ganancias Liq.`.
- Los **avisos de parámetros** se silencian en la recarga (`FSilenciarAvisosParam`) para no repetir.
- La caché de par se limpia en `Init`: es por liquidación.

## Relacionado

[[Parámetros y vigencias]] · [[Aplicabilidad de un concepto a una liquidación]] · [[Ciclo de cálculo de una liquidación]] · [[conceptos-tres-vigencias]]

**Tablas relacionadas:** [[Tabla - Personal Proyecto]] · [[Tabla - Convenio Colectivo]] · [[Tabla - Categoría CCT]]
