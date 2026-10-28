---
aliases: ["El grossing-up tapa los errores"]
tipo: leccion
tema: controles-auditoria
tags: [leccion, controles-auditoria, project]
actualizado: 2026-10-04
---

# El grossing-up tapa los errores

En una liquidación con neto garantizado el neto siempre sale bien; el error aparece como un bruto distinto

> [!warning] En una liquidación con neto garantizado el neto siempre sale bien: comparar el bruto y la base, nunca el neto.

En las liquidaciones con grossing-up el neto es una **restricción**, no un resultado: el motor itera el complemento hasta alcanzarlo. Eso significa que **cualquier error en impuesto o aportes deja el neto correcto** y se manifiesta como un bruto que no coincide.

**Por qué:** invita a buscar el problema donde no está. Con el 90016 la diferencia se veía en `COMPLEMENTO_GU`, que era lo único que se movía, y el defecto estaba en la deducción de cónyuge (ver [[familiar-alta-impuesto]]). Además el error y su efecto aparecen **con el mismo importe en dos lugares** —246.940 menos de impuesto y 246.940 menos de bruto— y parecen dos problemas cuando son uno.

**Cómo aplicarlo:** comparar contra Meta4 **el bruto y la base imponible**, nunca el neto. Y descomponer la base paso a paso (remuneración → SAC prorrateado → aportes → deducciones), porque sólo una de las líneas tiene diferencia propia: las demás son el eco que introduce el complemento al reacomodarse.

El control decisivo es resolver el punto fijo a mano sacando la causa sospechada: si `C` cae exactamente en el sueldo de Meta4, no queda nada más que explicar.

Corolario: la auditoría importa el doble acá. `DeleteLineas` borraba el `Detalle Ganancias` en cada iteración y dejaba a estas liquidaciones —justo las que más falta hace auditar— sin el desglose de deducciones.

## Relacionado

- [[familiar-alta-impuesto]]
- [[comparar-columna-contra-total]]
- [[control-precedencia-formulas]]
