---
aliases: ["UsarParCCT deshace las pasadas posteriores"]
tipo: leccion
tema: motor-calculo
tags: [leccion, motor-calculo, project]
actualizado: 2026-10-08
---

# UsarParCCT deshace las pasadas posteriores

Recarga los parámetros crudos a mitad del cálculo y pisa lo que se hizo después de la carga inicial

> [!warning] `UsarParCCT` (`Cod50016`) no es sólo un cambio de filtros: cuando el par convenio/categoría no está en su caché de dos ranuras, llama **otra vez a `LoadParametros`**, que reescribe el contexto con los valores crudos de la base. Todo paso que corra *después* de la carga inicial queda deshecho **para ese par**.

El síntoma no parece un error de carga. Un tripulante tenía, **en la misma liquidación**, `BASE_PROD_CAL` convertido y `PROD_EMPRESA` sin convertir: uno usa el par del empleado y el otro el de la asignación ([[arroba-ignora-el-par-del-concepto]]). Un importe **1.415 veces más chico** y ningún aviso.

El diseño supone que el contexto se arma una vez, pero los conceptos marcados con otro par lo rearman a mitad del cálculo. El comentario de `Cod50016:153-155` describe el orden de la carga inicial y no dice nada de esta segunda entrada.

## Cómo se aplica

- Toda transformación posterior a `LoadParametros` va **también** dentro de `UsarParCCT`, **antes** de `GuardarValoresDelPar`: lo que se cachea tiene que ser el valor ya transformado, porque al volver al par se restaura de la caché y no se recarga.
- El estado que la transformación consume hay que **limpiarlo por pasada**. `FParamTC` sólo se limpiaba al iniciar el contexto, así que arrastraba el par anterior; con un parámetro mixto como `BASICO` o `PRECIO_PUERTO_*` eso convierte un valor que ya está en pesos.

## Relacionado

- [[control-moneda-es-asimetrico]]
- [[que-tc-usa-cada-concepto]]
- [[arroba-ignora-el-par-del-concepto]]
- [[tc-comprador-parametro-fantasma]]
- [[tc-del-franco-ventana-de-una-linea]]
