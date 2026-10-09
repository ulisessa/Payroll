---
aliases: ["xRec no es confiable con add-ins"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
origen: e3f9aae3-7094-4531-89d7-60a5aeb34498
actualizado: 2026-09-08
---

# xRec no es confiable con add-ins

> [!warning] Falla en silencio
> En el OnModify de una tabla, xRec llega con el valor NUEVO si el Modify vino de un evento de control add-in; comparar contra xRec para detectar cambios falla en silencio

Cuando el `Modify` se dispara desde el evento de un **control add-in**, el `xRec` que recibe el `OnModify` de la tabla **ya trae el valor nuevo**, no el anterior. Cada evento del add-in es un viaje cliente→servidor y BC reconstruye el estado de la página con `Rec` y `xRec` sincronizados; el código AL asigna el campo *después* de esa sincronización, así que al llegar al `Modify` los dos son iguales.

Confirmado con debugger el 2026-09-08 en `Pag50145.ConceptoLiqCard` → `GuardarTextoDeEditor` → `Rec.Modify(true)`.

**Por qué:** cualquier lógica que use `xRec` para decidir "¿cambió esto?" se saltea sin error ni aviso. Le pasó a `Cod50070.RegistrarModificacion`: el historial de fórmulas dejó de escribir alrededor del 2026-08-22, cuando el editor con IntelliSense pasó a ser la vía habitual de edición. No fallaba nada — la guarda `if (Fórmula = ConceptoAnterior.Fórmula) ... then exit` simplemente no veía diferencia. Costó una tarde entera de diagnóstico porque el síntoma (nada en el historial) es idéntico al de la agrupación por ventana y al del `Delete` cuando se vuelve al texto original, y porque el Change Log de BC **sí** registraba las modificaciones —lo escribe el `OnDatabaseModify` global, que corre incluso con `Modify(false)`, así que prueba que la fila se tocó pero no que el trigger de tabla haya corrido—.

**Cómo aplicarlo:** no comparar contra `xRec` en el `OnModify` de una tabla que se edita desde la ficha con el editor de fórmulas. El `OnModify` corre **antes** de escribir la fila, así que la versión almacenada todavía es la anterior: leerla con un `Get` sobre un `Record` aparte y comparar contra eso, cayendo de vuelta a `xRec` si el `Get` falla. Está resuelto así en `Cod50070.RegistrarModificacion`. Sonda barata para saber si un `OnModify` corre: forzar una validación que ya viva en ese trigger (en `Concepto Liquidación`, poner `Vigencia Hasta` anterior a `Vigencia Desde` y ver si salta `ErrIntervaloInvertido`). Ver [[conceptos-tres-vigencias]] y [[al-sin-cortocircuito]].

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rad-json-removed-peligroso]]
- [[rangos-licencia-objetos]]
- [[report-sin-layout-compila]]
- [[setselectionfilter-tabla-temporal]]
- [[symbolos-final-version-tienen-fuente]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
