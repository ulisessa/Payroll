---
aliases: ["Variables rotas que valen cero"]
tipo: leccion
tema: formulas-evaluador
tags: [leccion, formulas-evaluador, project]
actualizado: 2026-10-04
---

# Variables rotas que valen cero

> [!note] Verificar: Al 2026-10-04 `AÑOS_ANTIG_30JUN` y `MESES_PROM_AUS_6/12` ya tienen `case` en el motor. Revisar si el resto sigue vigente. Ver [[Divergencias entre documentación vieja y código]].

> [!warning] Falla en silencio
> tres variables de sistema con Cód. Cálculo inexistente valen CERO en fórmulas que las usan: antigüedad SOMU y los promedios de ausentismo

Siete variables de sistema están **activas con un `Cód. Cálculo` que el dispatcher de Cod50016 no
conoce**, así que valen CERO en toda fórmula que las nombre y el motor sólo lo dice como advertencia.
**Tres de ellas las usa una fórmula vigente**, y ahí el cero es un defecto real:

| Variable | La usa | Qué rompe |
|---|---|---|
| `AÑOS_ANTIG_30JUN` | `PCT_ANTIG_SOMU` | el corte del 30/6 del Art. 32 — ver [[antiguedad-suma-de-fases]] |
| `MESES_PROM_AUS_6` | `PROM_AUS_MES`, `PROM_AUS_MES_NR` | los promedios de ausentismo — ver [[ventana-promedio-ausentismo]] |
| `MESES_PROM_AUS_12` | `PROM_AUS_MES`, `PROM_AUS_MES_NR` | ídem |

Las otras cuatro —`DIAS_HAB_ANIO`, `HAB_EXTORD_ANUAL`, `HAB_GRAV_ANUAL` y `RETENIDO_ANUAL`— **no
las nombra ninguna fórmula**: son filas viejas que quedaron al lado de las `YTD_*` que sí funcionan,
y sólo hacen ruido en el informe de avisos. `DIAS_HAB_ANIO` es el caso ANIO/AÑO que el propio
comentario del motor menciona: el código que existe es **`DIAS_HAB_AÑO`, con Ñ**.

**Cómo buscar esto bien**: la lista de códigos válidos NO es la de la ayuda de Pag50146, que está
incompleta y desactualizada. La fuente es el `case` de `ResolverVariableSistema` en Cod50016; se
saca con `grep -oE "^            '[A-ZÑ_]+'"`. Y para ver si una fórmula usa la variable **no sirve
un `LIKE '%nombre%'`**: `HAB_EXTORD_ANUAL` matchea dentro de `YTD_HAB_EXTORD_ANUAL` y da falsos
positivos. Hay que exigir un carácter no alfanumérico a cada lado:
`PATINDEX('%[^A-Za-z0-9_]'+nv+'[^A-Za-z0-9_]%', ' '+REPLACE(formula,CHAR(10),' ')+' ') > 0`.

Las tres que importan **necesitan código AL**, no configuración: son lógicas de cálculo que el motor
no tiene. Arreglarlas es agregar su `case` en Cod50016, no tocar la fila.

## Relacionado

- [[system-variables-conventions]]
- [[variable-sistema-hay-que-sembrarla]]
- Tema: `formulas-evaluador` (ver [[_Convenciones del vault]])
