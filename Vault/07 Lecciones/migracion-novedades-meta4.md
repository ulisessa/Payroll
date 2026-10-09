---
aliases: ["Migración de novedades desde Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, project]
actualizado: 2026-10-04
---

# Migración de novedades desde Meta4

**En una frase:** M4T_VAL_INCIDENCIA mezcla novedades reales con datos que BC deriva; sólo ~60% es migrable

Migradas **2.765 novedades de 2026** el 18/9/2026, de 4.747 filas en `M4T_VAL_INCIDENCIA`.

**Meta4 guarda en esa tabla dos cosas distintas** y migrarla entera sería un error:

| | Conceptos | Filas | |
|---|---|---|---|
| Mismo código en BC → Importe | 32 | 1.116 | migrado |
| Unidades → Cantidad, con otro código | 3 | 1.649 | migrado |
| Días (franco, órdenes, puerto, enfermedad) | 11 | 954 | **no**: salen de Estado Empleado |
| Precios y porcentajes (`PR_*`, `PORC_*`) | 13 | 448 | **no**: son Parámetros Vigentes |
| Bases imponibles | 7 | 98 | **no**: son acumuladores |
| Horas extras de tierra (1891/4529/4538/4539) | 4 | 99 | pendiente: familia 18xx, y 56 sin convenio a su fecha |

**El patrón de las unidades**: Meta4 usa un concepto aparte para la cantidad y otro para el que
paga. `1582 DS_TRAB_ESP → 1583`, `4420 UN_HORAS_100_NV → 4423`, `4430 UN_HORAS_50_NV → 4433`.
Los tres son 100% de empleados en 729/15, verificado resolviendo el convenio **a la fecha de
cada novedad** (con una fecha fija daba 40% de falsos "sin convenio").

**Ojo con el 1583**: recibe las dos cosas —unidades desde el 1582 e importes desde el 1583 de
Meta4—, así que un control que valide el campo por el concepto DESTINO aborta la carga. Hay que
validarlo contra el concepto de ORIGEN.

`ID_TIPO_APLICACION` (0 y 2) **no** sirve para decidir cantidad vs importe: hay conceptos tipo 2
con valores de 200.000. Se decide por concepto.

Resultado verificado en A28/59: los 26 tripulantes pasaron de 1 con horas extras a 26, y las 74
novedades del viaje se ubican solas en la liquidación de la marea por
[[novedad-proyecto-sale-del-estado]]. Ver también [[novedades-pre-liquidacion]].

**ERROR CORREGIDO el 18/9/2026: 128 novedades que congelaban el cálculo.** De los 32 conceptos
que coincidían por código, nueve son conceptos que **BC sabe calcular** (tienen fórmula), y en
`M4T_VAL_INCIDENCIA` lo que hay para ellos no es una novedad sino **el resultado que Meta4
escribe después de calcular**. Los dos más grandes: `2003` a cuenta futuros (57 filas,
692.299.808) y `5010` impuesto a las ganancias (57 filas).

**La distinción que hay que hacer es Cantidad contra Importe**, no el concepto:

- Una novedad con **Cantidad** ALIMENTA la fórmula (21 horas y el concepto sabe cuánto vale la
  hora). Es el modo correcto y no hay que tocarla.
- Una con **Importe** la REEMPLAZA: el motor ve `TieneIncidencia` y usa el importe sin evaluar
  la fórmula. Cargar ahí el resultado de Meta4 congela el cálculo de BC en el número viejo,
  sin dejar rastro.

Control para detectarlo: novedades con `Importe <> 0` sobre un concepto cuya `Fórmula` no esté
vacía. Las 1.649 de cantidad (horas extras y días de trabajos especiales) quedaron intactas.

## Dos corridas de migración dejan duplicados que el importe no delata

El 8893 tenía **426 novedades en dos corridas**: la del **18/9/2026** cargó 424 (45 empleados, 6
períodos) y la del **15/9** había dejado **2 sueltas** —90299 y 90319, sólo 202601, con proyecto y
Tipo Liq. REGULAR—. Las dos gemelas con el mismo importe. Mientras el 8893 estuvo restringido a
`VACACIONES` no se veía, porque esos dos no tienen liquidación de vacaciones y cobraban cero; al
ampliarle el alcance aplicaron las dos y **cobraron el doble** (1,71 M y 1,65 M). Borradas el
2/10/2026.

**El criterio para distinguir un duplicado es la corrida de migración, NO el importe.** Buscar
"mismo empleado + período + concepto + importe" da 511 pares en el 8840 (127,75 M) y 674 en el 8850
(44,64 M), y muchos son legítimos: 04925 tiene dos anticipos de 50.000 el mismo día y Meta4 le cobró
100.000. En el 8893 mismo, 9 de los 11 "pares" eran importes distintos en fechas distintas y su
suma coincide con Meta4. Los únicos duplicados reales eran los que venían de **otra corrida**.

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[meta4-number-castea-a-cero]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-tipo-liq-incompleta]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
