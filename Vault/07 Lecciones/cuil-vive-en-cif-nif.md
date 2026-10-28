---
aliases: ["CUIL vive en CIF_NIF"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, reference]
actualizado: 2026-10-04
---

# CUIL vive en CIF_NIF

El CUIL está en CIF_NIF de Final Version, no en Social Security No_ (vacío en los 4.810)

El CUIL de los empleados está en `CIF_NIF`, campo de la extensión **Final Version**
(`a423950b-02e9-4ee0-ab32-61517ce330cb`), en la tabla `…$Employee$437dbf0e-…$ext`,
formateado con guiones: `20-18131928-4`. Cargado en 4.790 de 4.810 empleados.

Los otros tres candidatos NO sirven:
- `Social Security No_` (base app) → vacío en los 4.810.
- `pat_No_ ident_ AFIP` (Final Version) → vacío en los 4.810.
- `pat_No_ documento` (Final Version) → es el **DNI**, cargado en 4.733.

**Por qué:** el 17/9/2026 buscar el CUIL por `Social Security No_` devolvió "cientos de
empleados sin CUIL" y casi dispara una tarea de carga masiva que no hacía falta. El
filtro por nombre de columna tenía CUIL, CUIT, DNI, Social y Tax, y no encontró nada:
a nadie se le ocurre buscar el CUIL argentino bajo el nombre del identificador fiscal
español. `Cod110037.AplicarFilaSincNAV` ya lo decía en un comentario.

**Cómo aplicarlo:** un campo vacío en el 100% de las filas no es un dato faltante, es la
señal de que el dato vive en otra columna — buscar en la `$ext` antes de concluir que
no se migró. Ver [[campos-extension-tabla-ext]] y [[conexion-sql-bc]].

## Relacionado

- [[campos-extension-tabla-ext]]
- [[conexion-sql-bc]]
- [[ares-topologia-bc]]
