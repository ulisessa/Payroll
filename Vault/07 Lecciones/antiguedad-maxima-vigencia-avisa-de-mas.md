---
aliases: ["Aviso de parámetro desactualizado que grita de más"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-30
---

# Aviso de parámetro desactualizado que grita de más

el aviso de parámetro desactualizado salía en todas las liquidaciones por dos causas distintas

`Parámetro."Antigüedad Máxima Vigencia"` es el opt-in del aviso "el valor podría estar
desactualizado". Al 30/9/2026 dejaba ~31.000 avisos en el registro de proceso de enero, todos
falsos, por **dos causas distintas** que conviene no confundir:

**1. "no tiene ningún valor cargado"** — `LoadParametros` recorre TODOS los parámetros en TODAS las
liquidaciones, no sólo los que usan sus conceptos. Un parámetro cargado por convenio o por par no
resuelve para el empleado que queda fuera de ese alcance, y eso es lo normal: la fórmula lo envuelve
en `IFZERO`. Pero el aviso salía igual, una vez por liquidación: 4.683 de COEF_GUARDIA_PUERTO
(existe sólo para 175/75 y 729/15), 5.481 de PRECIO_PUERTO_CAL, 4.174 de PRECIO_PUERTO_LAN.
Corregido en `Cod50016.CheckVigenciaDesactualizada`: sólo avisa si la BASE no tiene **ninguna**
versión vigente a la fecha (`FBasesConFilas`, que se arma en `BuildParametroCache`).

**2. Una fórmula que no retrocede** deja la fecha límite en el presente o el futuro, y ahí ninguna
versión puede estar al día. COEF_GUARDIA_PUERTO estaba en `+1M` (2.532 avisos) y
SALARIO_ASEG_LAN/CAL tenían un apóstrofe suelto, `0x27` (6.404 cada uno). Ahora hay un `OnValidate`
en el campo que rechaza toda fórmula no negativa.

**Encoding de DateFormula en SQL**: signo + dígitos + un byte de unidad, `0x05` = M (mes). `-1M` es
`0x2D3105`. Confirmado contra TOPE_SIPA y PRECIO_PUERTO, que se cargan mes a mes.

Ojo: **el Nivel 1 de una fila con convenio y sin categoría es correcto** —`NivelDeFila` da 1 para
empleado o convenio y 2 sólo para convenio+categoría—. Lo que sí está desprolijo son 142 filas con
Nivel 0 que deberían ser 1 o 2: son anteriores al campo y el árbol las muestra planas. Hay un
`RecalcularNiveles` en `Claves Parámetro Liq.` para eso.

Ver [[get-con-menos-argumentos]] y [[un-valor-una-fuente]].

## Relacionado

- [[get-con-menos-argumentos]]
- [[un-valor-una-fuente]]
- [[atributos-tipados]]
- [[dos-parametros-mismo-nombre]]
- [[fuente-datos-apunta-por-numero]]
