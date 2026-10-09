---
aliases: ["Dos parámetros con el mismo nombre"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, reference]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-27
---

# Dos parámetros con el mismo nombre

Dos Parámetro con el mismo Nombre Variable: gana el último por código y pone el token en cero para quien no lo tenga cargado

Entre dos **Parámetro** el choque se resuelve al revés que en [[parametro-y-atributo-mismo-nombre]]:
ahí el atributo queda mudo porque `LoadAtributos` pregunta `if not Ctx.ContainsKey(...)`. El loop de
parámetros no pregunta nada:

```al
if not Ctx.ContainsKey(Param."Nombre Variable") then
    Ctx.Add(Param."Nombre Variable", Valor)
else
    Ctx.Set(Param."Nombre Variable", Valor);   // pisa siempre
```

Recorre `Parámetro` por su clave primaria —`Código`— así que **gana el último en orden alfabético**.
Y lo peor no es cuál gana: si el que gana no tiene vigencia para ese empleado, `ResolverCodigoEfectivo`
no encuentra clave, `Valor := 0`, y el `Set` **borra el valor que el otro acababa de cargar bien**.

Pasó con `BASICO` y `BASICO_MENSUAL` (27/9/2026), los dos declarando `Nombre Variable = BASICO`:

- `BASICO_MENSUAL` gana por alfabético y estaba cargado **sólo por empleado** (51 vigencias).
- Los que lo tenían cobraban bien: 372/04 y FA liquidaban `1003 Sueldo` sin problema.
- Los oficiales tenían `BASICO` por convenio+categoría (175/75 y 768/19) y les quedaba en **cero**
  en toda fórmula que lo lea: 1003, 1055, 1803/1813/1893, 2103, 2704, 3553, 4743.

**La solución no fue renombrar sino fusionar.** `Claves Parámetro Liq.` ya cascadea
`COD_<empleado>` → `COD_<convenio>_<categoría>` → `COD_<convenio>` → `COD`, y su propio comentario
dice que un parámetro puede tener a la vez valor general, excepción por convenio y otra por empleado.
`BASICO_MENSUAL` no era un parámetro distinto: era el **nivel por empleado de `BASICO`**. Mover sus
vigencias a `BASICO_<empleado>` y borrar el parámetro deja una sola fuente por valor, que es la regla
que el usuario pide (ver [[avoid-tables-principle]]).

**El control existía a medias.** `ExigirLibre` (Cod110051) sí compara Parámetro contra Parámetro, así
que un alta nueva queda frenada. Pero `OcupadoPorOtro` —el helper que usa `Duplicados()`, la función
para encontrar lo **ya cargado**— no chequeaba la tabla Parámetro: el caso más probable era el único
ciego. Arreglado el 27/9/2026, junto con extender `Duplicados()` a las cuatro tablas y colgarlo de una
acción en la lista de Parámetros ("Revisar Nombres de Variable Duplicados").

Para buscarlo a mano:

```sql
SELECT [Nombre Variable], COUNT(*), STRING_AGG([Código], ' | ')
FROM [ArbuTest$Parámetro$<ext>] WHERE [Nombre Variable] <> ''
GROUP BY [Nombre Variable] HAVING COUNT(*) > 1;
```

## Relacionado

- [[parametro-y-atributo-mismo-nombre]]
- [[avoid-tables-principle]]
- [[antiguedad-maxima-vigencia-avisa-de-mas]]
- [[atributos-tipados]]
- [[fuente-datos-apunta-por-numero]]
