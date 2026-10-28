---
aliases: ["La genérica nueva pisa a la específica vieja"]
tipo: leccion
tema: parametros-vigencias
tags: [leccion, parametros-vigencias]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-10-13
---

# La genérica nueva pisa a la específica vieja

Desde el 13/10/2026 la resolución de parámetros ordena **primero por fecha**: entre las claves
candidatas con valor cargado gana la de `Vigencia Desde` mayor, y la especificidad sólo desempata.

## Qué resolvía el cambio

El `COEF_TANGONERO` de `729/15` valía 0,3 desde el 1/1/2026. En febrero pasó a 1 para todos, y se
cargó una fila **genérica** —sin convenio— con vigencia 1/2/2026 y valor 1. No pasó nada: el motor
siguió devolviendo 0,3.

Con la regla vieja la cascada iba de la más específica a la menos y se quedaba con **la primera que
existiera**, sin mirar la fecha. La fila genérica era el *valor por defecto de los alcances sin fila
propia*, nunca un override. Así no había forma de expresar «desde febrero esto vale para todos» más
que repitiéndolo en cada fila específica — y la fila que se cargaba no daba error ni aviso.

Medido contra Meta4, el 0,3 de febrero estaba mal en el 100 % de los casos: los 128 empleados de
tierra con 0,3 difieren todos, siempre por el factor exacto 1/0,3. En enero, en cambio, los 115 con
0,3 coincidían **115 de 115**. El coeficiente cambió de verdad.

## El precio de la regla, que hay que conocer

**Una fila específica vieja pierde contra una genérica nueva aunque nadie haya querido pisarla.**
«Vieja» pasa a leerse como «superada», y una fila que no necesitó tocarse en años queda expuesta.

Al medir el cambio antes de publicarlo apareció exactamente eso: `PCT_ANTIG_372/04` tenía vigencia
**2023-01-12** con 0,01 y la genérica `PCT_ANTIG` tenía 2026-01-01 con 0,25. Con la regla nueva la
genérica le ganaba y **multiplicaba por 25 la antigüedad** de 13 empleados — a pesar de que 0,01 es
el valor correcto, verificado contra Meta4 en 11 de 11 en enero.

Se arregló **fechando la fila específica** —una vigencia nueva al 1/1/2026 con el mismo 0,01, que
empata con la genérica y gana por especificidad—, no volviendo atrás con la regla. Es una fila de
protección: no cambia ningún importe ni antes ni después.

## Cómo medirlo antes de tocar nada

La pregunta es «¿qué claves cambian de ganador?», y se contesta simulando las candidatas sobre los
contextos reales de las liquidaciones. Sobre 244.180 combinaciones (todo empleado × parámetro de
todas las liquidaciones calculadas) cambiaban **260**, en 2 parámetros: `COEF_TANGONERO` —lo buscado—
y `PCT_ANTIG` —el daño colateral—.

> [!warning] Dos trampas al escribir esa medición, las dos pisadas
> **Una fila de EMPLEADO también tiene el convenio en blanco**, y es la más específica de todas, no
> la menos. Sin filtrar por `No. Empleado` el control acusaba 22 `BASICO_<legajo>` contra
> `BASICO_130/75_EC01`, que ni siquiera compiten: son ramas distintas del árbol de candidatas.
>
> **Hay que comparar la vigencia EFECTIVA de cada clave —el MAX de sus filas—, no fila contra fila.**
> La fila de 2023 de `PCT_ANTIG_372/04` sigue existiendo y siempre va a ser anterior a la genérica de
> 2026; lo que decide es la última vigencia de la clave.

El script quedó en el scratchpad de la sesión (`simular_regla_fecha.sql`, de sólo lectura).

## Dónde está

`Claves Parámetro Liq.`.`Resolver` / `ResolverConEjes` / `ResolverEnTablaConEjes` (`Cod50071`). Los
dos primeros reciben ahora el mapa de vigencias además del de valores; `Cod50016.LoadParametros` se
lo pasa. `Test Claves Parámetro Liq.` (`Cod110069`) afirma la regla con 7 casos — era la función más
central del motor y no tenía ninguna prueba.

## Relacionado

- [[Parámetros y vigencias]]
- [[dos-parametros-mismo-nombre]]
- [[un-valor-una-fuente]]
- [[escala-antiguedad-meta4]]
