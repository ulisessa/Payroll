---
aliases: ["Novedad en cero no apagaba el concepto"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-30
---

# Novedad en cero no apagaba el concepto

> [!warning] Falla en silencio
> una novedad con todo en cero quedaba Aplicada pero la fórmula se calculaba igual; los tres modos de carga

Una novedad es **tres cosas distintas** según qué se le cargue, y el motor las distingue en
`Cod50014.MotorLiquidacion`, donde arma `TieneIncidencia`:

| Importe | Cantidad | Qué hace |
|---|---|---|
| ≠ 0 | cualquiera | el importe cargado **reemplaza** a la fórmula |
| 0 | ≠ 0 | la fórmula **valoriza** la cantidad (horas extras) |
| 0 | 0 | **cero explícito**: el concepto no paga y la fórmula ni se evalúa |

El tercer caso **no existía** hasta el 30/9/2026: la condición era `TieneIncidencia := Incid.Importe
<> 0`, así que una novedad en cero era indistinguible de "no hay novedad". La incidencia se creaba,
`MarcarNovedades` la dejaba en **Aplicada** con su `No. Liquidación`, y la fórmula calculaba igual.
Sin ningún aviso: todo decía que la novedad se había aplicado.

Apareció al querer forzar un cero en el 1023 (sueldo de feriado) del 03916, porque Meta4 no se lo
calculó. Encima el 1023 **no usa `CANT_INCIDENCIA`** —su fórmula es `BASE_FERIADO / (DIAS_MAREA +
DIAS_GP_PERIODO) * (DIAS_FERIADOS_MAREA + DIAS_FERIADOS_GUARDIA)`—, así que tampoco la cantidad lo
hubiera apagado.

Al momento del cambio había **una sola** incidencia con todo en cero en toda la base (la del 03916),
contra 209 de "sólo cantidad" y 284 con importe, así que no tocó nada más.

Es la forma de apagar un concepto para un empleado puntual sin tocar la fórmula ni el CCT. Ver
[[anticipos-como-novedades]] y [[novedad-con-proyecto-queda-huerfana]].

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- [[orden-calculo-del-lote]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
