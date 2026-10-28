---
aliases: ["La baja vive en la fase, no en la ficha"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
actualizado: 2026-10-09
---

# La baja vive en la fase, no en la ficha

El disparador de la Liquidación Final preguntaba por un campo que está vacío en los 4.810

> [!warning] `Employee."Termination Date"` está en **cero en toda la base**. Las bajas se cargan en `Fase Alta Empleado."Fecha Baja"`, que tiene **9.351** fechas. Un disparador que pregunte por la ficha nunca se cumple, y "no se dio de baja" es una respuesta perfectamente válida: no hay error, no hay aviso, simplemente no sale nada.

La Liquidación Final estaba completa y bien cableada —tipo activo, `Disparador = BajaEmpleado`, `EsBajaEmpleado` consultado en los cuatro caminos del lote, incluso la vía sin proyecto— y **no salió para nadie**: siete empleados y 20,9 M sólo en enero de 2026.

```al
// lo que había
if Emp."Termination Date" = 0D then
    exit(false);
```

El argumento del comentario original era razonable —«la fase dice si PERTENECÍA, la ficha si DEJÓ de pertenecer»— y el dato le dio la contra. **La fase es además el lugar correcto**: un empleado entra y sale varias veces, cada ciclo es una fase con su alta y su baja, y la ficha sólo podría guardar la última.

Y hay que preguntar por **cualquier fase cerrada dentro del período, no por la vigente**: quien se fue el 9/1 y volvió el 9/2 tiene su baja en una fase que ya no es la actual.

## No toda baja es una desvinculación

De los nueve con fecha de baja en enero, Meta4 liquidó final —su `Tipo Imputación 14`— a **siete**. Los dos que no:

| | Motivo | Qué era |
|---|---|---|
| uno | `BAJ-0` | alta y baja **el mismo día**, con reingreso el 29/1: una corrección |
| otro | `BAJ-12` | repite las mismas fechas todos los años: contrato de temporada |

**El motivo discrimina los nueve casos sin un solo error.** La regla alternativa que probé —«se fue y no volvió dentro del mes»— deja entrar al `BAJ-12`, que no volvió y tampoco cobró final.

Como no hay dónde poner una bandera —`Grounds for Termination` está **vacía** y el campo de la fase es un `Code[20]` libre—, la lista vive en Config. RRHH como **expresión de filtro** (`BAJ-1`, o `BAJ-1|BAJ-2`). En blanco cuenta cualquier baja, así que **hay que sembrarla**: sin eso el primer cálculo después de publicar fabrica dos finales de más.

> [!note] Un segundo `SetFilter` sobre el mismo campo pisa al primero
> Al escribir el arreglo puse `SetRange("Fecha Baja", desde, hasta)` y debajo un `SetFilter("Fecha Baja", '<>%1', 0D)` para descartar las fases abiertas. El segundo **reemplaza** al primero: el rango de fechas se perdía entero y la consulta devolvía cualquier baja de cualquier época. Las fases abiertas ya quedan afuera solas, porque su fecha en blanco es `0D` y ningún período real la contiene.

## Cómo verificarlo sin esperar al cálculo

El control es cruzar la regla contra el `Tipo Imputación 14` de Meta4, en las dos direcciones:

1. a quién alcanza la regla y **no** tiene TI=14 → estaría fabricando finales de más;
2. quién tiene TI=14 y la regla **no** alcanza → se estaría perdiendo uno.

Con el filtro en `BAJ-1` las dos listas salen vacías.

## Relacionado

- [[cuando-corresponde-una-liquidacion]]
- [[tres-capas-fase-estado-asignacion]]
- [[antiguedad-suma-de-fases]]
- [[bucle-modifica-campo-filtrado]]
- [[variables-rotas-valen-cero]]

## La baja también tiene que ser un ESTADO (migrado el 9/10/2026)

Que el disparador leyera la fase correcta no alcanzaba. El historial de **estados** seguía cortándose el día de la baja, y el motor decide por estados: un dado de baja no tenía estado al cierre del período, así que no se le armaba ninguna liquidación. En enero de 2026 eso dejó **ocho empleados y 21,0 M de bruto** que Meta4 sí pagó.

Se materializaron **9.301 estados de baja**, uno por fase cerrada, con el código del motivo (`BAJ-*`). La regla de fechas, confirmada con RRHH: `FEC_BAJA` es el **último día** de la relación, así que el estado vigente cierra **el día de la baja** y el de baja arranca **al día siguiente**. Medido: de los 9.301, **8.313 tienen estado previo y los 8.313 terminan exactamente ese día**; los otros 988 no tenían ninguno. Cero huecos de más de un día, cero solapes.

Se saltearon 24: 19 por reingreso al día siguiente (no hay hueco que llenar) y 5 porque ya había un estado ocupando el tramo.

> [!note] El `BAJ-0` se migra igual aunque no deba generar liquidación final
> Son dos cosas distintas: el **estado** cierra el historial —que es lo que se viene a arreglar— y **quién cobra final** lo decide después el filtro de `Estado Tipo Liq.`, que puede excluirlo. Dejar 562 empleados sin estado porque su baja no paga final sería repetir el agujero en chiquito.

**La regla de negocio que lo completa:** una baja **no lleva Regular** — la liquidación final **es** su regular. Por eso las 7 Regulares de enero que quedaron en Borrador sin una sola línea no hay que calcularlas: hay que dejar de crearlas.

Eso se configura en `Estado Tipo Liq.`, y el campo `Cód. Estado` ya admite filtros (`BAJ*`), con `Empieza en la Ventana` para distinguir al que se da de baja **dentro** del período de los 4.445 que arrastran una baja vieja.
