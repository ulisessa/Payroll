---
aliases: ["Acumuladores y Orden Cálculo"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
origen: 9be8057e-0e48-430a-b6b0-cc4322f51ebc
actualizado: 2026-08-10
---

# Acumuladores y Orden Cálculo

> [!note] Verificar: Al 2026-10-04 el importe ya lleva su signo (no hay `Abs`) y el campo es `Invertir Signo`, no `Restar`. Ver [[Divergencias entre documentación vieja y código]].

Un importe de acumulador que sale demasiado bajo, sin error, casi siempre es un problema de `Orden Cálculo`.

> [!warning] Un acumulador "bajo" sin error casi siempre es un aporte con Orden Cálculo posterior a la lectura. El detalle de Pag50174 se recalcula al final y muestra el conjunto completo, por lo que no delata el problema.

## Qué pasa

Cuando un concepto que lee un acumulador (BASE_IG4, BASE_FERIADO…) produce un importe **demasiado bajo y sin error**, hay que revisar primero `Orden Cálculo`: fue la causa real las dos veces que apareció (agosto de 2026).

El acumulador se suma **a medida que los conceptos corren en orden de Orden Cálculo**, así que un concepto que lo lee ve el subtotal *hasta su propia posición*, no el total. Todo aporte cuyo Orden Cálculo sea mayor que el del lector falta en silencio. En la UI es invisible porque el drill-down del acumulador (Pag50174) se **recalcula al final desde todas las filas de Línea Liquidación**, por lo que siempre muestra el conjunto completo: el detalle y el valor que usó el lector son dos números distintos por construcción.

## Cómo detectarlo

Sumar la columna *Importe Aportado* del drill-down y compararla con el valor de la variable en la línea que lee. Una brecha limpia y grande = problema de orden.

## Segunda trampa, mismo síntoma al revés (acumulador demasiado alto)

El motor guarda cada importe de línea con `Abs()`, de modo que el signo que un concepto lleva a un acumulador vive **únicamente** en la marca `Restar` de su fila de `Fracción Acumulador`, **por acumulador**, nunca derivado del Tipo Concepto. El mismo concepto puede legítimamente restar en un acumulador y sumar en otro (4415 "Absorción art. 36" hace exactamente eso: resta en BASE_FERIADO, sumaba en BASE_IG4 por una fila sin tildar). Pag50174 ahora muestra "Aportes que suman / que restan" por separado, resaltado cuando nada resta.

## Controles que existen para el problema de orden

- **Estático**: página "Control Orden Acumuladores" (Cod50067) compara, por acumulador, el orden del último aportante contra el del primer lector. Corre sin liquidar nada; correrlo después de tocar Orden Cálculo, fórmulas o Fracción Acumulador.
- **Runtime**: Cod50014 `RegistrarLecturasAcumuladores` / `VerificarOrdenAporte` avisan por el canal existente `AcumularAdvertencias`, cubriendo lecturas indirectas vía `@CÓDIGO` que el escaneo de texto no ve.

## Relacionado

- [[novedades-pre-liquidacion]]
- [[conceptos-tres-vigencias]]
- [[concepto-negativo-despues-de-sus-consumidores]]
- [[control-precedencia-formulas]]
