---
aliases: ["El Devengado tapaba días que no le tocan"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-04
---

# El Devengado tapaba días que no le tocan

El Devengado cubría el mes entero en vez del tramo de su marea, y un día tapado no lo reclama nadie: los días de guardia previos al embarque se perdían sin hueco visible

`Liquidación.Cobertura` recortaba contra las fechas del proyecto **sólo si el tipo liquidaba al
arribo**. El **Cierre de Marea** lo hace y sus coberturas son correctas (87 de 90); el **Devengado**
corre sobre mareas igual pero se dispara solo, así que salía por ese `exit` y se quedaba con el
período entero. Sus **90 liquidaciones de enero de 2026 cubrían 2.425 días de más**: el devengado de
una marea que empezó el 25 tapaba desde el 1.

**Y un día tapado no lo reclama nadie.** El control de cobertura lo ve cubierto y no pide otra
liquidación, así que los días previos al embarque —guardia en puerto, francos— se quedaban sin pagar,
sin hueco visible y sin error. El 03062 tiene tres recibos en Meta4 (mareas 5, 6 y 7) y BC sólo dos:
el de la marea 5, del 1 al 2 de enero, pagaba 2 días de puerto, el feriado del 1/1 y 13.447,87 de
antigüedad que en BC no aparecían en ningún lado.

Corregido el 29/9/2026: la condición pasa a ser `CubreSoloElProyecto`, que mira el **Tipo Proyecto**
del tipo de liquidación —`Productivo` son los de marea: Cierre y Devengado— en vez del disparador.

**Por qué:** un hueco de cobertura se ve; un día tapado por el documento equivocado, no. Es la forma más
silenciosa de perder plata que apareció en esta migración.

**Cómo aplicarlo:** después de publicar hay que **recalcular las coberturas ya guardadas**:
`CompletarCoberturas` sólo llena las que están en blanco, así que las 90 existentes conservan el valor
viejo hasta que se recalculen. Y conviene revisar qué liquidaciones nuevas pide el control una vez
destapados los días: de los 2.425, la mayoría son de navegación —los recoge el cierre de su propia
marea— pero quedan **81 tramos de guardia en puerto** que necesitan una Regular. Relacionado:
[[cobertura-en-tramos]], [[cuando-corresponde-una-liquidacion]].

## Relacionado

- [[cobertura-en-tramos]]
- [[cuando-corresponde-una-liquidacion]]
- [[acumuladores-orden-calculo]]
- [[concepto-negativo-despues-de-sus-consumidores]]
- [[conceptos-tres-vigencias]]
