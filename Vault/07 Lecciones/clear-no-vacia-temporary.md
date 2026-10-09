---
aliases: ["CLEAR no vacía un Record TEMPORARY"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, reference]
actualizado: 2026-10-04
---

# CLEAR no vacía un Record TEMPORARY

CLEAR sobre un Record TEMPORARY no borra las filas; hace falta RESET + DELETEALL

> [!warning] CLEAR sobre un Record TEMPORARY limpia campos y filtros pero no las filas.

`CLEAR(Rec)` limpia los valores de los campos (al InitValue), los filtros, la clave
—la vuelve a la primaria— y la compañía. **No elimina las filas** de una tabla
temporal. Para vaciarla: `Rec.RESET; Rec.DELETEALL;` — el RESET primero, porque
DELETEALL borra sólo lo comprendido por los filtros vigentes.

Documentación: [CLEAR](https://learn.microsoft.com/en-us/dynamics-nav/clear-function) ·
[DeleteAll](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/methods-auto/record/record-deleteall-method)

**Por qué:** es un error silencioso y acumulativo. Una tabla temporal usada como memoria
entre llamadas (dedupe de avisos, cachés) sigue llena en la corrida siguiente y la
lógica que la consulta decide sobre datos viejos.

**Cómo aplicarlo:** sólo muerde en variables **globales** o en single-instance. Un
temporal declarado como local nace vacío en cada invocación, así que ahí el CLEAR es
redundante pero inocuo — no hay que salir a corregirlos. Ojo también con el inverso:
nunca `CLEAR` a un temporal que se está usando como acumulador si lo que se quiere es
sólo reposicionar el cursor; para eso va `RESET`, y para limpiar campos sin perder
filas, `INIT`.

## Relacionado

- [[al-compile-command]]
- [[al-sin-cortocircuito]]
- [[avoid-tables-principle]]
