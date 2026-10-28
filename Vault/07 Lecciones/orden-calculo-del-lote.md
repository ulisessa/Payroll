---
aliases: ["Orden de cálculo del lote"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Orden de cálculo del lote

**En una frase:** un lote salía en orden de No. y eso cambia importes; y que List de AL no tiene Sort()

El cálculo por lotes recolectaba el alcance con un `FindSet` pelado, así que las liquidaciones salían
en orden de **No.**, que es el de creación. **Ese orden decide importes**, porque varias cosas leen lo
que ya está liquidado:

- El **tope de SIPA** sobre el SAC devengado se agota en el mes: la primera consume el tope y la
  segunda no debe aportar (ver [[tope-sac-por-liquidacion]]).
- **Ganancias** resta `YTD_RETENIDO_ANUAL`, que es lo retenido en las liquidaciones anteriores.
- Los **francos** se consumen FIFO contra los lotes que haya en ese momento.

Con una liquidación creada después de la que la precede en el mes —pasa seguido al rehacer una—, el
lote la calculaba primero y el reparto salía distinto del de calcularlas a mano.

`RecolectarNumerosEnOrdenDeCalculo` (Cod50076) ordena por **empleado + período + Orden del Tipo de
Liquidación + No.**, y sólo la usa `Calcular`: Reabrir, Aprobar y Eliminar siguen con la vieja, que
no depende del orden. Se ordena con una clave de texto y no con `SetCurrentKey` porque **el Orden no
es un campo de Liquidación sino de Tipo Liquidación**, y no se puede pedir a la base que ordene por
un campo de otra tabla. El `Format(10000 + Orden)` rellena a cinco dígitos para que "2" no caiga
después de "10".

**Dos trampas de AL que costaron una compilación cada una:**

- **`List of [Text]` NO tiene `Sort()`.** Tiene Add, Get, Set, Contains y poco más. Hay que ordenar
  a mano; quedó un insertion sort en `OrdenarClaves`.
- En ese sort, `while (j >= 1) and (Items.Get(j) > Actual)` **revienta con j = 0**, porque
  [[al-sin-cortocircuito]]: el `Get(0)` se evalúa igual. El while quedó partido con un `break`
  adentro.

Lo que NO se puede tocar acá: un `SetFilter` sobre un campo después de un `SetSelectionFilter`
reemplaza el filtro de la página y ensancha la selección sola, así que el alcance se recorre entero y
se filtra registro por registro.

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
