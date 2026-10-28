---
aliases: ["La hora de ingreso a puerto del proyecto contradice los estados"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
actualizado: 2026-10-14
---

# La hora de ingreso a puerto del proyecto contradice los estados

> [!warning] Un día de puerto contra un día de navegación: un sueldo de puerto vale el doble.

BC decide si el día de arribo es puerto o navegación con la **hora de ingreso a puerto del proyecto** (antes del mediodía es puerto, después navegación). Meta4 y los estados migrados lo marcan con el estado `PL`. En las proyectos cerrados de enero a marzo de 2026 las dos fuentes coinciden siempre: hora de la mañana con `PL` el último día, hora de la tarde con `NV`.

**La excepción es el proyecto `PP-802-000007`** (HF802, marea 7): hora de ingreso 16:00 (tarde) pero los 30 tripulantes tienen `PL` el 12/2 y Meta4 paga ese día como puerto. Resultado: BC paga 12 días de navegación y ninguno de puerto, Meta4 11 y 1. La diferencia es de un día entre sueldo de navegación y de puerto por persona, 9 mil pesos netos de bruto con el adicional, y se repite en los 26 de 729/15 que cobran en ese cierre.

**Falta decidir:** Meta4 no guarda la hora (la tabla `M4T_HIST_EST_BUQUE` sólo trae el estado), así que no hay un valor para cargar. La corrección es de dato maestro: poner en el proyecto una hora de mañana. No se aplicó porque habría que inventar la hora.

## Relacionado

- [[feriado-divide-por-30-fijo]]
