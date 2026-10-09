---
aliases: ["Novedad con proyecto queda huérfana"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# Novedad con proyecto queda huérfana

> [!warning] Falla en silencio
> Una novedad con proyecto explícito sólo entra en la liquidación de ESE proyecto; si el empleado no tuvo una, no se aplica y no avisa

El motor da **precedencia a la novedad sobre la fórmula** (Cod50014): si hay incidencia toma su
importe y saltea la fórmula con `if (not CreateLine)`. Por eso los conceptos que se cargan a mano
—4803, 4813, 4823, 8850, 4115— están **sin fórmula a propósito**, ver [[anticipos-como-novedades]].
Y por eso darle fórmula a un concepto que además tiene novedades **no duplica**: la novedad gana.

**Pero una novedad con `No. Proyecto` cargado sólo entra en la liquidación de ese proyecto.** Si el
empleado no tuvo liquidación de ese proyecto en el período, la novedad queda sin aplicar, con
`Estado` en 0 y **sin motivo**: no hay ningún aviso.

El testigo es el **legajo 00794 en enero de 2026**: tiene **cinco novedades de 8850 por 140.000 cada
una = 700.000**, que es exactamente lo que descontó Meta4, y BC no descontó nada. Las cinco están
atadas a `PP-119-000307` y su liquidación de enero es `PN-119-NOMINA` — estuvo todo el mes en
guardia de puerto, así que el proyecto de marea nunca llegó. En el mismo recibo su novedad de 4823
tiene el **proyecto en blanco** y sí se aplicó.

**Alcance en enero de 2026:**

    sin proyecto: entran en cualquier liquidación    368 novedades  142 empleados   63.055.532,51
    con proyecto, y hay liquidación de ese proyecto  172 novedades   86 empleados  106.468.491,33
    con proyecto, pero NO hay liquidación            95 novedades   29 empleados   10.493.921,21

Las 95 huérfanas son casi todas de recupero: **8850 con 64 novedades de 17 empleados por 3.650.000**,
más 8830, 8893, 8870 y 4683.

**El proyecto viene de la migración**: los anticipos salen de `M4T_CTA_CTE_ANTICIPOS` y ANP/ANL/ANH
traen proyecto — ver [[anticipos-cta-cte-meta4]]. Meta4 **no lo usa como filtro duro**: al 00794 le
descontó los 700.000 igual.

## Corregido el 28/9/2026 en el motor, no en los datos

Se tocó `ProyectoAplica` (Cod50061). Vaciar el proyecto de las 95 huérfanas habría servido hoy y se
habría roto mañana: al publicar `CrearSinProyecto` aparecen liquidaciones que hoy no existen, y una
novedad sin proyecto entraría en la equivocada. La regla ahora distingue tres casos:

    el proyecto de la novedad es el de esta liquidación     -> entra
    hay OTRA liquidación del empleado con ese proyecto      -> no entra: es de aquélla
    no hay ninguna liquidación de ese proyecto              -> HUÉRFANA: sigue por el camino
                                                               de la novedad SIN proyecto

El tercer caso **no elige "la primera que se calcule"** —criterio que este mismo archivo descarta por
escrito— sino que degrada al camino ya existente: lo decide el **historial de estados** de esa fecha,
que sabe qué estaba haciendo la persona. Se reusa una regla documentada en vez de inventar un
desempate nuevo, y la guarda de doble cobro de `NovedadAplica` sigue cubriendo el resto.

El auxiliar nuevo es `ExisteLiquidacionDelProyecto(EmpNo, Período, Proyecto)`. Con empleado en blanco
—novedad colectiva— pregunta por el de la liquidación, porque la pregunta es si a **esa** persona le
corresponde.

## Relacionado

- [[lote-tipo-liq-en-blanco]]
- [[novedad-en-cero-no-apagaba-el-concepto]]
- [[novedad-estado-apunta-a-proyecto-sin-liquidar]]
- [[novedad-tipo-liq-y-fecha-se-pelean]]
- [[novedades-pre-liquidacion]]
- [[orden-calculo-del-lote]]
- Tema: `motor-calculo` (ver [[_Convenciones del vault]])
