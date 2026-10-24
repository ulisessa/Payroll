---
aliases: ["La antigüedad se mide al fin del mes"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 4b151484-1884-4407-a1bb-01b9ea3741c8
actualizado: 2026-10-20
---

# La antigüedad se mide al fin del mes

`AÑOS_ANTIGUEDAD` se calcula al **fin del período** y no a la fecha de referencia de cada liquidación, para que el porcentaje de antigüedad sea el mismo en todas las liquidaciones del mes.

## Qué pasaba

La fecha de referencia de un cierre de marea es el arribo (`Job."Ending Date"`); la de una devengada o una regular, el fin de mes. Si el empleado cumple el escalón entre las dos fechas, el cierre pagaba el escalón anterior y la devengada el nuevo. En marzo de 2026: 04722 cumple los 2 años de antigüedad entre el 25 y el 31/3 (cierre 2 %, devengada 4 %; 1053 de 10.309,17 contra 20.618,34 de Meta4) y 04659 los 3 (4 % y 8 %; 20.618,34 contra 41.236,68, y su 1603 de 122.243 contra 125.189 porque depende de la antigüedad). Meta4 mostró `ANIOS_ANTIG` constante en las tres corridas del mes (2,0137 y 3,0247) y pagó el escalón nuevo en todas.

## Decisión

Los convenios no fijan el momento: SOMU lo mide al 30/6 de cada año, el acuerdo AACPyPP no lo especifica y el CCT 175/75 tampoco. El usuario decidió unificar al **fin de mes** (20/10/2026).

## Cambio

`Cod50016` `CalcAntiguedad`: usa el mayor entre `FFechaRef` y `Fecha Hasta` del período. Las liquidaciones finales y las regulares no cambian (su referencia ya es el fin de mes). `AÑOS_ANTIG_30JUN` (SOMU, al 30/6) es otra variable y no se tocó.

> [!warning] Publicado el 20/10/2026 en la versión 1.0.0.674
> Es un cambio de código: vale desde que se publicó (1.0.0.674, `scripts/Publicar.ps1`). Falta recalcular los cierres de marzo con escalón entre el arribo y el fin de mes (04722, 04659).

> [!info] Sin verificar
> No se corrió contra enero y febrero de punta a punta: sólo cambian los cierres cuyo escalón cae entre el arribo y el fin de mes, y en el paralelo de marzo no hubo otros casos con diferencia de 1053.

## Páginas de antigüedad (20/10/2026)

`Antigüedad Plantilla` (110029) y `Fases de Alta` (110028) miden contra el campo «Antigüedad al», que tomaba `WorkDate()` por defecto. Ahora el valor por defecto es el **fin del mes en curso** (`CalcDate('<CM>', WorkDate())`), la fecha con la que el motor mide la antigüedad del recibo, así que pantalla y recibo coinciden salvo que se escriba otra fecha. La ficha de empleado (`EmployeeCardExt`) también mide al fin del mes en curso y su tooltip lo dice; si en las dos páginas el usuario escribe otra fecha, `Gestión Estado Empleado`.`AvisarSiNoEsFinDeMes` avisa que lo que ve puede diferir del recibo; `Control Previo` no mide antigüedad de empleados. Requiere republicar.
