---
aliases: ["Antigüedad: suma de fases"]
tipo: leccion
tema: conceptos-haberes
tags: [leccion, conceptos-haberes, project]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-28
---

# Antigüedad: suma de fases

La antigüedad de BC (suma de tramos trabajados) coincide con Meta4; lo único que diverge es el corte del 30/6 del Art. 32

**El modelo de BC es el correcto y no hay que tocarlo.** Validado el 27/9/2026 contra la columna
`ANIOS_ANTIG` de Meta4 —su propia antigüedad en años, la que usa para pagar, ya importada en
`Hist. Liq. Meta4`—, sobre los 330 que Meta4 pagó en enero:

    suma de los tramos trabajados (lo que hace BC)  ->  314 coinciden, 16 dentro del año, 0 se van de un año
    corrido desde la primera alta                   ->  140 coinciden, 113 se van de un año
    corrido desde Employment Date                   ->  128 coinciden, 120 se van de un año

Y en los de **4 o más fases —los relevos— la suma da 6,70 contra 6,73 de Meta4**, mientras que
corrido daría 10,60. Los huecos entre campañas NO cuentan.

**`Antigüedad Reconocida` (campo 52002, `Employee$ext`) está en cero a propósito y así debe quedar.**
El 27/9/2026 la cargué para 195 empleados creyendo que Meta4 contaba corrido desde
`M4T_FASES_ALTA.FEC_ANTIGUEDAD`; al recalcular enero las diferencias CRECIERON y hubo que revertir.
`FEC_ANTIGUEDAD` es la primera alta, no la antigüedad que Meta4 paga.

**El error de método que lo causó:** validé la fórmula contra `FEC_ANTIGUEDAD`, que es de donde
salía la fórmula — circular. La validación buena es contra lo que Meta4 **paga**.

## Lo que sí diverge: el corte del 30 de junio

`PCT_ANTIG_SOMU` evalúa la escala con **`AÑOS_ANTIG_30JUN`** —Art. 32 del CCT: la antigüedad que se
paga todo el año es la que se tenía al 30/6— mientras que `PCT_ANTIG_OFICIALES` usa
`AÑOS_ANTIGUEDAD`, la corriente. **Meta4 no aplica el corte**: su `PORC_ANTIG` coincide con el tramo
de la antigüedad corriente en 216 de 230, y con el del 30/6 en sólo 175.

El corte le da un porcentaje menor a **45 empleados**, y en los 45 el porcentaje corriente es el de
Meta4. El testigo es el 00291: 2 años al 30/6 contra 3,12 corrientes, 4% contra el 8% de Meta4.

**La escala en sí está bien**: 2-4-8-10-12-14-18 y 25 desde los 10 años, idéntica a la de Meta4 para
729/15. 372/04 tiene otra escala (1-2-3) y hay oficiales con valores sueltos.

**Resuelto el 27/9/2026 con dos vigencias de fórmula, no con un `IF` adentro:**

    2023-01-12 a 2026-06-30 : escala sobre AÑOS_ANTIGUEDAD   (la corriente) -> coincide con Meta4
    2026-07-01 en adelante  : escala sobre AÑOS_ANTIG_30JUN  (Art. 32, como estaba)

`Concepto Liquidación` tiene clave **Código + Vigencia Desde** y el motor resuelve con
`FiltrarVigentesA` (`Vigencia Desde <= FechaRef`) + `FindLast`; `BuildLatestVersionCache` filtra por
fecha **antes** de quedarse con la última, así que una vigencia futura no contamina un cálculo viejo.
Meter la fecha adentro de la fórmula —`IF(MES_ANUAL >= 7, ...)` repetido en las ocho ramas— era poner
una regla de calendario donde ya hay un mecanismo de calendario. **Es el primer concepto de la base
con dos vigencias**, así que conviene mirar una liquidación de enero y otra de julio.

## La BASE del cálculo: distinta por convenio

Los años y el porcentaje son una cosa; sobre qué importe se aplican es otra, y **no es la misma para
los dos convenios**. Así quedó 1053 el 28/9/2026:

    Oficiales (175/75, 768/19)  ->  PRECIO_NAV / 30 * días * #PCT_ANTIG_OFICIALES / 100
    Marinería (729/15)          ->  BASE_SUELDO * #PCT_ANTIG_SOMU / 100

**El discriminador es el porcentaje, no `TIPOACTIVIDAD`**: `PCT_ANTIG_OFICIALES` tiene CCT para
175/75, 768/19 y ESP, y `PCT_ANTIG_SOMU` sólo para 729/15, así que se excluyen por convenio y
`#PCT_ANTIG_OFICIALES > 0` identifica al oficial sin inventar ninguna regla.

**El testigo es el legajo 00607.** Meta4 le paga 383.625,00 = 1.485.000 / 30 × 31 días × 25%. Con
`BASE_SUELDO` le salían 428.289,57, porque `BASE_SUELDO` es lo que cobró de **órdenes** y las órdenes
se le pagan a 55.263,17 por día, no a los 49.500 del precio base. Verificado al peso en 16 de 17
oficiales; los casos con distinta cantidad de días lo confirman (00728: 4 días → 30.000; 01591:
4 días → 38.733,33), que es lo que descarta que sea un 25% plano del básico mensual.

**Se usa `PRECIO_NAV`, no `BASICO`.** Valían lo mismo en las cuatro categorías de oficial, y por eso
se borraron las cuatro vigencias de `BASICO` de 175/75 y 768/19: una sola lista por valor. Antes de
borrarlas hay que mirar quién las lee — nueve conceptos leen `BASICO`, y el único que le pagaba a un
oficial era 3553, que lo toca sólo dentro de `IF(BASICO_EsFCY, ...)`; los 13 oficiales con vacaciones
tienen `VAC_PROMEDIO = 1` y nunca llegan a esa rama.

Quedaron dos vigencias de 2023 que no se borraron y **son datos muertos**: `BASICO_175/75_OF01` y
`BASICO_175/75_OF03`. Ese par no existe —OF01 y OF03 son de 768/19, ver
[[convenio-of-depende-de-la-categoria]]— y hay 0 empleados con esa combinación.

## La trampa al leer Meta4

Hay **más de una entrada por empleado y mes** (regular y vacaciones), y las dos repiten el mismo
`ANIOS_ANTIG` y `PORC_ANTIG`. **Sumarlas los duplica**: leí 6,24 años y 16% donde había 3,1178 y 8%,
y casi salgo a buscar una regla inexistente. Va `MAX`, no `SUM`. Ver [[tot-remun-27617-es-acumulador]]
para la otra columna donde sumar está mal.

## Relacionado

- [[convenio-of-depende-de-la-categoria]]
- [[tot-remun-27617-es-acumulador]]
- [[a-cuenta-futuros-aumentos-puerto]]
- [[adicional-art-23-vs-art-33]]
- [[adicional-tareas-mecanicas]]
