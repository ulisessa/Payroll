---
tipo: referencia
tags: [motor, conceptos, recibo, totales]
fuente: [src/Enums/Enum50300.TipoConceptoLiq.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Reports/Rep50041.ReciboDeSueldo.al, src/Tables/Tab60012.LineaLiquidacion.al, src/Enums/Enum50309.GrupoCostoLaboralLiq.al]
actualizado: 2026-10-04
---

# Tipos de concepto y su efecto en el recibo

`Concepto Liquidación."Tipo Concepto"` (enum `Tipo Concepto Liq.`, 50300) dice **qué es** la línea. El
**signo** del importe es independiente: lo lleva el propio `Importe` ([[Tabla - Línea Liquidación]]).

| Ordinal | Valor | Lado | Entra a… |
|---|---|---|---|
| 0 | `Haber Remunerativo` | haber | Total Haberes (suma) |
| 1 | `Haber No Remunerativo` | haber | Total Haberes (suma) |
| 2 | `Descuento Empleado` | descuento | Total Descuentos |
| 3 | `Contribución Patronal` | patronal | Total Contribuciones (fuera del neto) |
| 4 | `Retención` | descuento | Total Descuentos |
| 5 | `Seguridad Social` | descuento | Total Descuentos |
| 6 | `Informativo` | — | ningún total |
| 7 | *(libre, quemado)* | — | era `Deducción Remunerativa`; **no reutilizar**: líneas viejas pueden guardarlo |

> [!danger] El ordinal 7 no se reasigna
> `Tipo Concepto` está desnormalizado en `Línea Liquidación`: una línea vieja sin recalcular guarda el 7 y
> reasignarlo la haría aparecer como otra cosa. Un haber remunerativo negativo se expresa hoy con
> `Haber Remunerativo` e importe negativo.

## Totales de la liquidación (`UpdateTotals`)

Sólo cuentan las líneas con **`Es Devengo = false`** (las de devengo de francos —días, importe 0— no entran):

```
Total Haberes        = Σ Haber Remunerativo + Σ Haber No Remunerativo
Total Descuentos     = Σ Descuento Empleado + Σ Retención + Σ Seguridad Social
Total Contribuciones = Σ Contribución Patronal
Neto a Pagar         = Total Haberes − Total Descuentos
```

`CalcNetoDesdeBD` (grossing-up) usa los mismos grupos. Como las sumas son **con signo**, ni `UpdateTotals` ni `CalcNetoDesdeBD` tuvieron que cambiar al eliminar el `Abs`. Los `Informativo` (incluidas las líneas de acumuladores) **no** mueven el neto: por eso el concepto del neto garantizado debe ser informativo ([[Grossing-up y tipo de cambio]]).

## Qué NO decide el tipo

- **A qué acumuladores aporta** un concepto: sale **sólo** de `Fracción Acumulador`. El motor no mira `Tipo Concepto` para acumular. La `GUIA-LIQUIDACION.md` dice que el tipo "define cómo se acumula": **no es así en el código** (ver [[Divergencias entre documentación vieja y código]]). Un haber 100 % no remunerativo no aporta a `BASE_SS` porque **no tiene esa fracción**, no por su tipo.
- **Si el concepto corre**: eso lo deciden `Aplica A`, `Tipos Liq. Aplicables`, la restricción por convenio y la `Condición` ([[Aplicabilidad de un concepto a una liquidación]]). Única excepción: los `Informativo` **no se restringen** por "Sólo Conceptos Declarados" del tipo de liquidación (ver esa nota).

## Campos del concepto que la línea copia

`PrepararLineaConcepto` copia al momento de calcular, para que el recibo y las comparaciones sean reproducibles aunque el concepto cambie después:

| Campo de la línea | Origen (`Concepto Liquidación`) |
|---|---|
| `Tipo Concepto` | `Tipo Concepto` |
| `Grupo Costo Laboral` | `Grupo Costo Laboral` (enum: ` `, Sindical, Seguridad Social, Obra Social, INSSJP, ART, SCVO) |
| `Imprime en Recibo` | `Imprime en Recibo` (por defecto **sí**) |
| `Es Devengo` | `Es Devengo` |
| `Nombre Impresión`, `Descripción Concepto` | idem |
| `Cantidad` / `Unidad Cantidad` | `Variable Cantidad` (nombre **o expresión**), o la cantidad de la incidencia, o los días del devengo de francos |
| `Base Cálculo` | `Variable Base` (nombre o expresión) o el valor unitario de la incidencia |
| `Fórmula Aplicada`, `Vigencia Concepto`, `Cód. Convenio`/`Cód. Categoría` | fórmula, versión y par con los que se calculó |

`Variable Cantidad` y `Variable Base` se resuelven con un evaluador **aparte** y **tolerante**: son lo que *muestra* el recibo, no lo que se paga; una expresión mal escrita queda en 0 sin cortar la liquidación. Por eso su sintaxis se valida al cargarlas.

## Recibo de sueldo (`Rep50041`)

La banda de líneas imprime sólo `Importe <> 0` **y** `Imprime en Recibo = true`, ordenada por `Orden Cálculo, No. Línea`. Cada línea sale en una columna según su tipo:

- **Haberes** (`LinImporteHaber`): `Haber Remunerativo` y `Haber No Remunerativo`, con columnas separadas para remunerativo y no remunerativo.
- **Descuentos** (`LinImporteDescuento`): `Descuento Empleado`, `Retención`, `Seguridad Social`.
- **Contribuciones** (`LinImporteContrib`): `Contribución Patronal`.
- El importe **va con su signo**: un haber que corrige hacia abajo se imprime negativo en la columna de haberes.
- Grupo de la línea (`LinGrupo`): Contribuciones Patronales (1), Remunerativo (2), No Remunerativo (3) y **todo lo demás cae en «Descuentos» (4)**.
- El **costo laboral** (sindical, seguridad social, obra social, INSSJP, ART, SCVO, empleador vs. trabajador) se arma con `Grupo Costo Laboral` y el tipo.

> [!warning] Un `Informativo` con `Imprime en Recibo = true` y `Importe <> 0` cae en el grupo «Descuentos»
> (rama `else` de `LinGrupo`), con cero en las tres columnas de importe. Las líneas de acumuladores ya
> salen con `Imprime en Recibo = false` (`WriteAccumulatorLines`). Para un informativo propio, apagar el
> flag. No se revisó el layout `.rdl` para ver cómo se muestra.

Además del cuerpo de líneas, el recibo imprime las variables del `Resumen Variable Liq.` marcadas `Mostrar en Recibo` (fuentes de datos, variables de sistema y atributos que lo pidan) y el detalle de Ganancias. Ver [[Detalle del cálculo y trazabilidad]]. Para el diseño del recibo y sus variantes, ver las notas de la carpeta de interfaz y reportes.

## Roles especiales (`Rol Franco`)

| Rol | Efecto en el motor |
|---|---|
| `Ninguno` | normal |
| `Devengo` | la fórmula devuelve **días**; la línea guarda `Cantidad = días` e `Importe = 0` (sólo cantidad; se valoriza al consumir). Se usa con `Es Devengo = true` |
| `Consumo` | la fórmula devuelve **días**; el motor genera **una línea por lote** valorada FIFO; un pedido mayor al saldo es error |

Ver [[francos-fifo-ledger]] y [[Ciclo de cálculo de una liquidación]].

## Relacionado

[[Acumuladores y fracciones]] · [[Tabla - Concepto Liquidación]] · [[Aplicabilidad de un concepto a una liquidación]] · [[Versionado de conceptos y fórmulas]]
