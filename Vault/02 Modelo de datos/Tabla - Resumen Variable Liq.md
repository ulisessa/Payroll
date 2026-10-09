---
tipo: tabla
tags: [modelo-datos, transaccional, recibo]
fuente: [src/Tables/Tab60024.ResumenVariableLiq.al]
actualizado: 2026-10-04
---

# Tabla - Resumen Variable Liq. (60024)

## Propósito
**Variables a nivel de liquidación** (no de línea) guardadas al terminar el cálculo, para auditar y para imprimir en el recibo (días trabajados, obra social, sindicato, fechas…). Es la versión "por liquidación" de [[Tabla - Detalle Variable Línea Liq]].

## PK
`No. Liquidación` + `Nombre Variable` (clustered).

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` (1) | → `Liquidación."No."` | |
| `Nombre Variable` (2) | Code[30] | |
| `Etiqueta` (3) | Text[100] | Etiqueta de recibo (de la fuente/variable) |
| `Valor` (4) | Decimal | La proyección **numérica** con que calculó la fórmula |
| `Valor Texto` (6) | Text[250] | El valor **original** cuando la fuente declara un tipo no numérico (p. ej. "126205 - OSECAC") |
| `Mostrar en Recibo` (5) | Boolean | Copiado de la fuente al guardar, para que el recibo imprima sólo lo destinado a eso |

## Procedimiento
`ValorParaMostrar()`: `Valor Texto` si existe; si no, `Format(Valor, 0, '<Precision,2:2><Standard Format,0>')`.

## Triggers
Ninguno.

## Quién la lee / escribe
Escribe `Cod50014.MotorLiquidacion` (usa una copia temporal y luego persiste); lee `Cod110028.ControlMareaExcelLiq`, `Cod50081.ControlMareaLiq`. Página `Pag50177 Resumen Variable Liq Sub`. Alimentada por [[Tabla - Fuente Datos Liquidación]] y [[Tabla - Variable Sistema Liq]] con `Mostrar en Recibo`.

## Vigencias
No tiene.

## Trampas conocidas
Con **dos** valores conviviendo (`Valor` y `Valor Texto`) hay que acordarse de que son dos preguntas distintas: con qué se calculó y qué hay que imprimir. Ver [[atributos-tipados]].
