---
aliases: ["Vacaciones de tierra duplica el mes"]
tipo: leccion
tema: vacaciones-sac-licencias
tags: [leccion, vacaciones-sac-licencias, project]
actualizado: 2026-10-04
---

# Vacaciones de tierra duplica el mes

**En una frase:** En mensualizados el REGULAR paga el sueldo entero y el de Vacaciones las vacaciones enteras, porque HAY_LIQ_VACACIONES apaga el descuento de días

Después de acotar los conceptos del recibo de vacaciones —ver
[[recibo-vacaciones-paga-solo-vacaciones]]— la duplicación **desapareció en los embarcados y quedó
en el personal 90xxx**, los mensualizados de tierra. En enero de 2026, sobre los 82 con vacaciones:

    90016  BC 50.381.512,84  contra  Meta4 24.208.252,13   razón 2,081
    90302  BC  9.618.124,01  contra        4.384.453,45    razón 2,194
    90251  BC 20.217.000,00  contra       11.793.250,54    razón 1,714

## La causa: la exclusividad apaga el descuento y nadie prorratea el sueldo

Meta4 paga las dos cosas **en un solo recibo**: para el 90016, `VACACIONES` 24.208.251,20 y
`DESC_VACACIONES` **−17.291.608,00**. BC emite dos documentos y en el REGULAR paga `1003 Sueldo`
entero, 26.173.261,08.

El concepto que tendría que descontar es el **4743 "Descuento días de vacaciones"**, y su condición es

    (DIAS_VAC_PERIODO > 0) AND HAY_LIQ_VACACIONES = 0

o sea que **se apaga justo cuando existe la liquidación de Vacaciones** — el mecanismo de
[[exclusividad-vacaciones]]. En enero corrió en **2 liquidaciones de todo el período**, las de dos
empleados sin documento de vacaciones.

La exclusividad da por sentado que el documento de Vacaciones se hace cargo de todo, pero **nadie
prorratea el `1003`**: el REGULAR sigue pagando el mes completo. Las dos coberturas del 90016 son
además idénticas —1/1 al 31/1 las dos—, a diferencia de los embarcados, donde sí se reparten en
tramos ([[cobertura-en-tramos]]).

## Los dos modelos de Meta4, medidos

El corte por clase de empleado es total, enero a junio de 2026, sin un solo cruce:

    VACACIONES       ti=3, documento propio   Tripulante      148 entradas / 147 empleados
    VACACIONES       ti=1, recibo mensual     Mensualizado     38 / 37
                                              Jornalizado       2 / 2
    DESC_VACACIONES  ti=1                     Mensualizado     52 / 39
    AD_VAC_ALIM      ti=1                     Mensualizado      4  (+1 jornalizado)

**Tripulante: documento aparte, sólo el haber.** No lleva descuento de días ni plus.
**Mensualizado y jornalizado: todo en el mensual** — vacaciones, descuento de días y plus.

**El plus vacacional es el 3573** "Adicional vacaciones artículo 76", `round(#3553 * 0,1, …)` — un
10% de las vacaciones, `AD_VAC_ALIM` en Meta4. Como lee `#3553`, **tiene que correr en el mismo
documento donde se pagan las vacaciones**, y por eso sólo lo cobran los que las cobran en el mensual.

Eso valida de rebote una decisión que había quedado marcada como riesgosa: al acotar los conceptos
del recibo de vacaciones se le **sacó VACACIONES al 3573**, y está bien — los tripulantes no cobran
plus, y a los mensualizados les llega por el REGULAR, que sí lo declara.

**Un caso a mirar**: hay 1 empleado con `AD_VAC_ALIM` y **sin atributo CONVENIO**. El filtro nuevo es
permisivo ante la duda, así que a ése se le va a seguir emitiendo el documento de vacaciones.

## Resuelto el 28/9/2026: no se emite el documento para tierra

Se agregó **`Aplica A` a `Tipo Liquidación`** (campo 15, mismo enum `Aplica A Liq.` que el del
concepto). Es el mismo eje un escalón más arriba: el del concepto dice a qué clase de empleado le
toca una **línea**, éste a qué clase le toca el **documento entero**. `VACACIONES` quedó en
**Tripulante**, sembrado desde `Cod50055.AplicarA`, que **converge** —sin guarda permisiva— porque una
instalación ya corrida tiene el campo en "Todos" y nunca llegaría al valor bueno.

El filtro se aplica en `Cod50018.TipoAplicaAlEmpleado`, en los **dos** caminos de creación —el que
recorre proyectos y el que recorre empleados—, y cuenta los omitidos con su propio mensaje. Resuelve
con `Convenio Categoría Liq..ParDeEntidad`, el mismo resolvedor que usa el motor, para que el
documento se cree con el criterio con el que después se calcula. Ante la duda no filtra: sin convenio
o con "Todos" de cualquiera de los dos lados, pasa.

El mapeo de convenio a clase ya existía: **175/75, 729/15, 768/19 y ESP son Tripulante**; 130/75,
372/04 y FA son Mensualizado; JO es Jornalizado.

**De paso, un bug de alta**: `Orden` en `Tipo Liquidación` nacía en 0, que ya usa `SALDO_INICIAL`, así
que **toda fila nueva nacía en error** y la página la descartaba al navegar — no se podía dar de alta
un tipo desde la grilla. Ahora `OnInsert` le asigna el siguiente libre si vino en cero.

Queda sin diagnosticar el grupo que paga **de menos**, con razón **0,714** (90184, 90219, 90046,
90068).

## Relacionado

- [[recaida-accidente-mismo-valor]]
- [[recibo-vacaciones-paga-solo-vacaciones]]
- [[vacaciones-tripulantes-promedio]]
- [[ventana-promedio-ausentismo]]
- Tema: `vacaciones-sac-licencias` (ver [[_Convenciones del vault]])
