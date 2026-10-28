---
aliases: ["Una liquidación sin días propios no se calcula"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-19
---

# Una liquidación sin días propios no se calcula

si el reparto de tramos le saca todos los días a una liquidación porque otra ya los liquidó, el motor falla en vez de pagar de nuevo

> [!warning] Sin tramos, `AjustarCabeceraAlEnvolvente` no toca la cabecera: la liquidación conserva el período entero y los conceptos se calculan sobre esa ventana. Una Regular a la que la Final le sacó todos los días pagaba igual los 27 días de GP del 1083.

Caso de marzo de 2026: 04486 y 04513 se dieron de baja el 31/3. Tenían Final y además Regular, las dos con el mes entero (1083 por 1,96 M duplicado). En enero y febrero había Regulares sin tramos pero vacías (haberes en cero), por eso nadie lo vio.

## Qué se cambió (19/10/2026)

1. **Control** (`ValidarDiasPropios`, Cod50014): tras `Recalcular` de tramos, si la liquidación quedó con cero días y otra del empleado en el período ya reclamó días, error `ErrDiasYaLiquidados` con los números de las otras. Sólo para tipos que reclaman días: no aplica a los de arribo (traen su viaje recortado), a los que tienen `Meses` (el aguinaldo se paga encima) ni a los que no entran en la corrida completa (anticipo, reliquidación, históricos).
2. **Prioridad por Orden del tipo** (`ReclamaAntes`, Cod110054): una liquidación sólo ve los días de otras con igual o menor Orden. Antes dependía de cuál se calculó última: recalcular la Final después de la Regular la dejaba sin días y el control nuevo la habría bloqueado.
3. **Creación** (`HayExclusionDePersona`, Cod50018): la baja el último día del mes cuenta aunque el estado `BAJ` arranque el día siguiente. La Regular no se crea para quien tiene Final.

## Cómo corregir lo que ya existe

La Regular existente de 04486 y 04513 en marzo no se arregla sola: al recalcularla va a fallar con el nuevo error. Eliminarla.

Ver [[cobertura-en-tramos]], [[cobertura-devengado-tapa-dias]] y [[cuando-corresponde-una-liquidacion]].

## El lote la descarta en vez de dejarla en Borrador (20/10/2026)

Faltaba una pieza: el control evita pagar dos veces, pero "Crear y calcular" tomaba el error como un cálculo roto y dejaba la liquidación en Borrador, sin líneas, a la vista como un pendiente falso («una que falló no se descarta: no se sabe si está vacía porque no corresponde o porque se rompió»). Caso: las Regulares de marzo de 04139 (su DEVENGADOS ya cubría del 22 al 31/3) y de 04360 (sus VACACIONES, del 2 al 31/3), creadas el 20/10 después de esas liquidaciones; BC ya coincidía con Meta4 sin ellas.

**Cambio** (`Cod50014` `SinDiasPropios`, público, sobre la misma `NoLeQuedanDias` que usa `ValidarDiasPropios`; `Cod50018` `CalcularYDescartarSiVacia`): antes de calcular una liquidación nueva, el lote pregunta si le quedan días. Si no, la borra sin calcular, sin consumir número de serie y sin dejar un fallo en el registro de procesos (cuenta como descartada). El motor sigue negándose a calcular una a mano. Sólo aplica al lote «Crear y calcular»; el «Crear» a secas no calcula y no distingue el caso.

Los dos borradores existentes se eliminaron con `scripts/EliminarBorradoresRegular04139y04360.sql` (cabeceras vacías; las 8 filas de `Registro Proceso Liq.` se dejaron como historial).

> [!warning] Publicado el 20/10/2026 en la versión 1.0.0.675, sin probar
> El cambio de código compila (1917 KB) y está publicado (1.0.0.675). No se probó con un lote real: el primer «Crear y calcular» con un empleado así es la prueba.
