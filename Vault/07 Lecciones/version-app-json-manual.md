---
aliases: ["Versión de app.json a mano"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, feedback]
origen: 6fef786a-9ac7-4101-a78d-2cb1c395ef37
actualizado: 2026-08-22
---

# Versión de app.json a mano

**En una frase:** No tocar "version" en app.json; el usuario la incrementa a mano antes de publicar

No incrementar el campo `version` de `app.json`. El usuario lo hace a mano cuando decide publicar.

**Por qué:** compilar con `alc.exe` no cambia la versión, así que varios builds distintos terminan
compartiendo número si nadie la toca — y eso ya causó confusión real: `1.0.0.383` se recompiló cuatro
veces con código distinto y no había forma de saber qué estaba instalado en BC. El usuario prefiere
controlar ese momento él.

**Cómo aplicarlo:** compilar todas las veces que haga falta sin tocar `app.json`. Si un cambio necesita
republicarse para verse —sobre todo los del control add-in, que además el navegador cachea— decirlo
en la respuesta y dejar que él suba la versión. Ver [[al-compile-command]].

## Relacionado

- [[progreso-singleinstance-sucio]]
- [[rad-json-removed-peligroso]]
- [[rangos-licencia-objetos]]
- [[report-sin-layout-compila]]
- [[setselectionfilter-tabla-temporal]]
- [[symbolos-final-version-tienen-fuente]]
- Tema: `desarrollo-al` (ver [[_Convenciones del vault]])
