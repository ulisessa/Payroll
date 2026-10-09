---
aliases: ["Un día de puerto no estira la marea"]
tipo: leccion
tema: estados-fases
tags: [leccion, estados-fases, project]
actualizado: 2026-10-08
---

# Un día de puerto no estira la marea

La marea son los días del buque; embarcar antes agrega un día del tripulante, no un día de marea

> [!warning] Los días de la marea salen de la **zarpada al arribo** y son iguales para todos los que la hacen. Un tripulante que sube antes a hacer trabajos de puerto suma **un día suyo**, que se paga como puerto y **no** entra en el prorrateo del neto acordado.

El HF802 zarpó el 3/1 y arribó el 24/1: **22 días de marea**. Un primer oficial subió el **2/1** a trabajar en puerto sobre esa misma marea. Su recibo de Meta4 lo dice sin ambigüedad:

```
Sueldo Navegación   22 × 25.500 = 561.000
Sueldo Puerto        1 × 51.000 =  51.000
A Cta Futuros Aumentos        15.199.400     ← prorrateado sobre 22, no sobre 23
```

Meta4 lleva las dos cuentas por separado —`DIAS_NAVEG` 22, `DIAS_PUERTO` 1, `DIAS_MAREA` 23— **paga el día de puerto** y prorratea el acuerdo sobre los **22**. BC tiene exactamente los mismos días; lo que se había alineado mal era cuál de ellos alimenta el objetivo del grossing-up.

## Cómo se modela

- **La asignación** (`Personal Proyecto`) va de la **zarpada al arribo**: es la parte de la marea que le toca al tripulante, y es de donde sale el prorrateo del neto acordado ([[valor-franco-por-terna]] usa la misma idea para el franco).
- **El día de puerto extra lo declara el estado**: un `PS` sobre el proyecto de la marea, anterior al alta de la asignación.

Hasta el 8/10/2026 el día de puerto sólo existía si la **asignación** arrancaba antes de la zarpada, porque `CalcDiasPuertoMarea` lo deducía como "día de víspera" de esa ventana. Eso forzaba a elegir:

| Asignación | Objetivo | Día de puerto |
|---|---|---|
| 2/1 – 24/1 | 23 días ✗ | se paga ✔ |
| 3/1 – 24/1 | 22 días ✔ | **se pierde** ✗ |

Y perderlo era peor que no pagarlo: el día quedaba **dentro de la cobertura** de la liquidación, así que ninguna otra lo iba a reclamar ([[cobertura-devengado-tapa-dias]]).

`DiasPuertoDeclaradosFueraDeLaAsignacion` cierra la pinza: suma los días de estado **de marea pero no de navegación** que caen fuera de la ventana de la asignación. Con eso la asignación puede decir la verdad —22 días— y el día de puerto se paga igual.

> [!note] Qué estado es "de puerto" no está escrito en el código
> Es uno marcado `Transcurre en Marea` que **no** es el de navegación, y el de navegación es el `Estado Liq. Personal Predet.` del propio proyecto. Así `PS` y `PL` entran sin nombrarlos y un estado de marea nuevo entra solo. Ver [[tres-capas-fase-estado-asignacion]].

**Medido antes de escribirlo:** sobre las 180 liquidaciones de marea calculadas, **179 dan exactamente los mismos días** y la única que cambia es la que había perdido su día de puerto.

## Lo que se descartó, y por qué

Prorratear el objetivo sobre `DIAS_NAVEGADOS` en vez de `DIAS_MAREA` parecía el arreglo obvio. Simulado: **arregla uno y rompe siete**. Los seis devengados de las mareas que arrancan a fin de mes pierden su día de **zarpada**, que sí es día de marea y hoy cuadra exacto contra Meta4.

Y ojo con acotar "días dentro de la ventana del proyecto" sin más: tres administrativos tienen `NETO_GARANT` **sin días de marea** —su objetivo sale del otro término de la fórmula— y un acote recalculado desde cero les daría 31 días donde hoy tienen 0.

## Relacionado

- [[tres-capas-fase-estado-asignacion]]
- [[asignacion-no-pisa-el-historial]]
- [[cobertura-devengado-tapa-dias]]
- [[ventana-liquidacion-es-cobertura]]
- [[oficiales-netos-al-70]]
