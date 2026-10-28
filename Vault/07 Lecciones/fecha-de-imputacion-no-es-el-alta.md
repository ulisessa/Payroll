---
aliases: ["La fecha de imputación de Meta4 no es el alta", "Vigencias desde la secuencia de liquidaciones de Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, atributos, vigencias]
actualizado: 2026-10-26
---

# La fecha de imputación de Meta4 no es el alta

**En una frase:** cuando una vigencia de BC se arma con la secuencia de liquidaciones de Meta4, la primera fecha no sirve de inicio y "la última alta" tampoco: el inicio es el de la fase vigente en la fecha del primer registro y, si no hay ninguna, la primera alta posterior.

## El caso

Cargando la zona DGI de los tripulantes en `ZONA_DESFAVORABLE` (para el crédito IVA del asiento, ver [[Asiento de sueldos]]), cada tramo arrancaba el día de la primera liquidación de Meta4 con esa zona y el primero en el 1/1/2026. El control "todos son `TRIPUL` a la fecha de su tramo" frenó dos veces, y por dos motivos opuestos:

1. **Diez ingresos de 2026** tenían el primer tramo en el 1/1, antes de su alta. El atributo `TIPOEMPLEADO` arranca en el alta y el control lo vio.
2. Corregido con "el alta más reciente", **00839 quedó con zona desde el 21/5**: es un reingreso, y sus liquidaciones de enero a mayo se quedaban sin zona. La previa lo mostró en la lista de reemplazos: 46 en vez de 2.
3. Con "la fase vigente en la fecha del primer registro" frenaron **seis** que entraron el 27/3: Meta4 imputa la mensual **el 25**, así que el primer registro (25/3) es anterior al alta. Para ellos, la primera alta de 2026.

> [!tip] La fecha de imputación es un dato de Meta4, no del hecho
> La mensual de Meta4 se imputa el 25, el cierre de marea en la fecha del cierre de Meta4 (que no es
> la `Fecha Liquidación` de BC: el 802 cerró el 13/3 en Meta4 y el 22/3 en BC). Sirve para ordenar y
> para ver cuándo cambió algo; no para fijar un inicio de vigencia sin cruzarlo con la fase.

## El control que lo atrapó

No contaba filas: verificaba una **invariante** —un atributo de tripulante sólo puede empezar cuando el empleado es tripulante— y, además, la **cobertura**: toda liquidación de 2026 de esos empleados tiene que encontrar su zona a la fecha. El primero atrapó los inicios tempranos; la lista de reemplazos, el tardío. Ver [[previsualizar-antes-de-migrar]].

## Relacionado

[[atributo-cargado-que-nadie-lee]] · [[oracle-date-lleva-hora]] · [[nomina-no-es-intervalo-presencia]]
