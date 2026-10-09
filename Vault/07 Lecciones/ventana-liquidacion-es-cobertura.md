---
aliases: ["Ventana de liquidación = cobertura"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Ventana de liquidación = cobertura

**En una frase:** La ventana de cálculo es Cobertura Desde/Hasta de la liquidación, no el período

Una liquidación de **cierre de marea** vive dentro de un período mensual pero cubre
sólo sus días: `Cobertura Desde/Hasta` en la tabla `Liquidación`. El motor tomaba el
inicio del **período** (`Periodo."Fecha Desde"`) como `FPeriodoFechaDesde`, así que
toda variable de período —`DIAS_GP_PERIODO`, francos, vacaciones y **cualquier
Fuente de Datos**— veía días anteriores al embarque.

Corregido el 17/9/2026 en `Cod50016.ContextoLiquidacion.Init`, que ahora recibe
`CoberturaDesde` y la usa cuando viene distinta de `0D`. El límite superior no hizo
falta tocarlo: `Fecha Liquidación = Cobertura Hasta` en las 156 liquidaciones que
tienen cobertura.

**Por qué:** el 17/9/2026 el legajo 03753 cobró tres días de sueldo de puerto en vez de
uno. Los dos de más eran guardia en puerto del 1 y 2 de enero, en `PN-128-NOMINA`,
mientras la marea iba del 3/1 al 29/1 — y esos días **ya los pagaba la liquidación
REGULAR de la nómina**, así que se contaban dos veces.

**Cómo aplicarlo:** las Fuentes de Datos distinguen su alcance por el nombre —
`*_PERIODO` no filtra por proyecto, `*_MAREA` y `PROD_*` filtran por `{JOB_NO}`— y
el motor no valida que una fórmula de marea no use una variable de período: la única
defensa es la convención. Ver [[atributos-tipados]] y [[acumuladores-orden-calculo]].

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
