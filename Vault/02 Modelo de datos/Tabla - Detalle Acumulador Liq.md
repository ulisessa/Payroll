---
tipo: tabla
tags: [modelo-datos, acumuladores, ui, temporal]
fuente: [src/Tables/Tab60028.DetalleAcumuladorLiq.al, src/Pages/Pag50174.DetalleAcumuladorLiq.al]
actualizado: 2026-10-04
---

# Tabla - Detalle Acumulador Liq. (60028)

## Propósito
**Buffer temporal** de pantalla: al abrir una línea que es un acumulador, muestra qué conceptos aportaron y cuánto. La página `Pag50174` usa `SourceTableTemporary = true`; nunca se persiste.

## PK
`Cód. Concepto` (clustered).

## Campos
`Cód. Concepto`, `Descripción Concepto`, `Importe Concepto` (importe de la línea aportante), `Porcentaje` (% aplicado de [[Tabla - Fracción Acumulador]]), `Invertir Signo`, `Importe Aportado` (resultado = importe × % con signo).

## Triggers
Ninguno.

## Quién la lee / escribe
Se arma en `Pag50174.LoadFromLiquidacion(LiqNo, CodAcumulador)` (recorre las líneas de la liquidación y las [[Tabla - Fracción Acumulador]] a la fecha de la liquidación) y se abre desde `Pag50118 Líneas Liquidación` y `Pag50159 Variables Cálculo Línea`. `SetValorUsado` contrasta el importe de la línea del acumulador con la suma de aportes: si difieren, total y detalle se calculan por caminos distintos. Ver [[acumuladores-orden-calculo]].

## Vigencias / trampas
No aplica. La suma de `Importe Aportado` explica el valor del acumulador; si un concepto aportó con orden posterior a la lectura no aparecerá en la corrida que se está mirando ([[acumuladores-orden-calculo]]).
