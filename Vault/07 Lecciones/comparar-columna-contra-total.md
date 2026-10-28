---
aliases: ["Comparar columna contra total"]
tipo: leccion
tema: controles-auditoria
tags: [leccion, controles-auditoria, feedback]
actualizado: 2026-10-04
---

# Comparar columna contra total

hacer coincidir una columna de Meta4 puede empeorar el total; el reparto de Meta4 entre sus columnas no es el reparto de BC entre tramos

**Que una columna de Meta4 coincida exacto no quiere decir que el concepto esté bien.** Meta4 cobra
el total y lo reparte entre sus columnas con un criterio propio, que **no es** el reparto de BC
entre tramos de cobertura. Perseguir la coincidencia columna por columna puede romper el total.

El caso: la cuota sindical es 4% de la remuneración del mes. Meta4 la parte en `C_SINDIC_VOL`
(8522) y `C_SINDICAL_VAC` (8525) según su propio corte; BC la parte según sus tramos —la Regular
cubre los días 1–4 y la de Vacaciones el 5–31—. En 00191:

| | |
|---|---|
| `BASE_SINDICAL` del mes (las dos liquidaciones) | 8.447.502,85 |
| 4% | **337.900,11** |
| Meta4: 238.143,83 (8522) + 99.756,29 (8525) | **337.900,12** |

Al pasar el 8525 de `BASE_SINDICAL` a `BASE_SINDICAL_VAC`, la columna 8525 quedó **idéntica** a la
de Meta4 (99.756,29 = 99.756,29) y pareció una mejora. Pero `BASE_SINDICAL_VAC` sólo tiene el
concepto 3553 Vacaciones —2.493.907,25 de los 8.313.024,18 que paga esa liquidación—, así que el
total cayó a 105.135,44: **faltaban 232.764,67 en diez empleados, 1,78 M**.

**Entonces: el control va sobre el TOTAL de la familia de conceptos**, sumando las liquidaciones del
mes, no sobre cada columna contra su homónima. Ver [[dias-sumados-donde-van-pesos]], que es la misma
trampa por el otro lado: agrupar por empleado miente cuando hay dos liquidaciones.

**Y el arreglo no siempre es revertir todo.** Acá hubo dos cambios juntos: agregar `3553 →
BASE_SINDICAL` (que estaba **bien**: la paga de vacaciones es sindicalizable y sin ella el total
quedaba corto en 99.756,29) y pasar el 8525 a `BASE_SINDICAL_VAC` (que estaba **mal**). Revertir los
dos deja el total corto otra vez; hay que revertir sólo el segundo. Antes de deshacer un cambio,
verificar con la aritmética **cuál** de los cambios rompe.

El 8522 sigue sobre `BASE_SINDICAL` y el 8525 volvió a `BASE_SINDICAL` el 2/10/2026;
`BASE_SINDICAL_VAC` quedó sin lector.

## Relacionado

- [[dias-sumados-donde-van-pesos]]
- [[control-precedencia-formulas]]
- [[grossing-up-tapa-errores]]
