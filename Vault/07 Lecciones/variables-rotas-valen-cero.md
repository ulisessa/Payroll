---
aliases: ["Variables rotas que valen cero"]
tipo: leccion
tema: formulas-evaluador
tags: [leccion, formulas-evaluador, project]
actualizado: 2026-10-15
---

# Variables rotas que valen cero

Una fila activa de `Variable Sistema Liq.` con un `Cód. Cálculo` que el motor no implementa
se carga como **cero** y deja una advertencia. La existencia de ese aviso no demuestra que
una fórmula haya utilizado el cero: también se cargan variables que ninguna fórmula consume.

## Estado verificado el 15/10/2026

`AÑOS_ANTIG_30JUN`, `MESES_PROM_AUS_6` y `MESES_PROM_AUS_12` **sí tienen `case`** en el motor
actual. El hallazgo anterior que proponía agregar esos tres cálculos ya no describe el código
publicado; ver [[antiguedad-suma-de-fases]] y [[ventana-promedio-ausentismo]].

La revisión de avisos de **1.0.0.660** encontró cinco filas con código inexistente:
`DIAS_COBERTURA_30`, `DIAS_HAB_ANIO`, `HAB_EXTORD_ANUAL`, `HAB_GRAV_ANUAL` y `RETENIDO_ANUAL`.
No tenían consumidores exactos en las fórmulas y configuración conservadas. Se **inactivaron**,
sin borrar filas, renombrar variables ni modificar fórmulas o recibos. No requieren recalcular
enero. Las alternativas que ya usa la configuración se detallan en [[Variables de sistema]].

`DIAS_HAB_ANIO` no es una grafía equivalente a `DIAS_HAB_AÑO`: el motor implementa la segunda,
con Ñ. `DIAS_COBERTURA_30` tampoco debe convertirse mecánicamente en `DIAS_ALTA_30`, porque
una cobertura parcial y la fase de alta miden cosas distintas; ver [[cobertura-parcial-no-es-ausencia]].

## Cómo verificar un caso nuevo

1. Comparar el `Cód. Cálculo` de la fila con el `case` de **`ComputeVariableSistema`** en
   Cod50016 y con la versión publicada. La ayuda de Pag50146 y la lista del lookup pueden
   estar incompletas; no son el dispatcher.
2. Buscar usos del **identificador completo** en todas las vigencias conservadas de conceptos,
   fórmulas, condiciones, órdenes, cantidades, bases, fuentes, filtros y parámetros. No alcanza
   `LIKE '%nombre%'`: `HAB_EXTORD_ANUAL` aparece dentro de `YTD_HAB_EXTORD_ANUAL` sin ser
   una referencia independiente. El límite debe excluir letras españolas, números y guion bajo;
   por ejemplo, `(?<![\p{L}\p{N}_])NOMBRE(?![\p{L}\p{N}_])`.
3. Verificar otros dueños o aliases del nombre antes de inactivar o migrar una fila. Cambiar el
   propietario de un nombre puede hacer que otra fuente lo sobrescriba.
4. Si el cálculo existe, corregir su configuración; si la fila no tiene uso, retirarla del catálogo
   activo conservando su trazabilidad. Sólo un cálculo requerido que realmente no exista puede
   necesitar AL nuevo. **Sembrar agrega faltantes; no repara códigos erróneos de filas existentes.**

Antes de 660, `AvisarCodigoDesconocido` unía los mensajes sin separador. El registro guardaba
los primeros 250 caracteres y perdía el resto, ocultando otros nombres. Desde 660 se separan
los avisos y un mensaje largo conserva texto en `Detalle`; esto mejora la lectura del control,
sin cambiar la resolución de una variable ni los resultados económicos.

## Relacionado

- [[system-variables-conventions]]
- [[variable-sistema-hay-que-sembrarla]]
- Tema: `formulas-evaluador` (ver [[_Convenciones del vault]])
