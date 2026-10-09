---
aliases: ["Tipo Liq. y Fecha se pelean"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Tipo Liq. y Fecha se pelean

> [!warning] Falla en silencio
> con Tipo Liq. y Fecha cargados y en desacuerdo, la novedad no entra en ninguna liquidación; desde el 3/10/2026 el tipo explícito gana

`Cód. Tipo Liq.` y `Fecha` en una novedad **contestan la misma pregunta** —en cuál de las
liquidaciones del mes entra— y cuando se contradicen, antes no entraba en **ninguna**: el tipo la
sacaba de las demás y la fecha la sacaba de la suya.

El caso: el legajo **00898** en enero de 2026, con Tipo Liq. `REGULAR` y fecha **31/01**. Su Regular
cubre del 1 al 4 y sus vacaciones del 5 al 31, así que la de Vacaciones la rechazaba por tipo y la
Regular por fecha. Sus **153.483,80** de cuota alimentaria no los cobraba nadie, con Estado 0 y sin
ningún aviso.

Desde el 3/10/2026 `NovedadAplica` (Cod50061) **saltea el filtro de fecha cuando la novedad nombra
un Tipo Liq.**:

```al
if (Nov.Fecha <> 0D) and (Nov."Cód. Tipo Liq." = '') then
    if (Nov.Fecha < RangoDesde) or (Nov.Fecha > RangoHasta) then
        exit(false);
```

Es la misma excepción que ya tenía el proyecto unas líneas más arriba —"un proyecto cargado a mano
sigue ganando"—: un selector puesto a mano es una decisión, no una inferencia, y la fecha de estas
novedades suele venir estampada de la migración con el último día del mes para todas.

**Por qué es seguro**: ningún empleado tiene dos liquidaciones del **mismo tipo** en un período
—verificado sobre toda la tabla—, así que un tipo explícito resuelve siempre a una sola y la fecha
nunca haría de desempate. Y la regla de "ya entró en otra liquidación del mismo empleado" sigue
abajo, intacta.

**Alcance**: 130 novedades nombran un Tipo Liq. y **todas** tienen fecha. En enero, sólo una estaba
siendo rechazada por este choque; en las otras la fecha caía dentro por casualidad.

**Ojo con el caso parecido pero distinto**: una novedad **sin** Tipo Liq. y con fecha fuera de toda
cobertura sigue rechazándose, y ahí casi siempre el problema es otro —una liquidación con cobertura
en blanco—. Ver [[cuatro-conceptos-sin-disparar]], donde 8 de 10 casos eran eso.

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-con-proyecto-queda-huerfana]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedades-pre-liquidacion]]
- [[orden-calculo-del-lote]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
