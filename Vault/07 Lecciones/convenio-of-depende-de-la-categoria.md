---
aliases: ["El convenio OF depende de la categoría"]
tipo: leccion
tema: convenios-cct
tags: [leccion, convenios-cct, project]
actualizado: 2026-10-04
---

# El convenio OF depende de la categoría

El código OF de Meta4 son DOS convenios según la categoría; OF01/OF03 van a 768/19 y OF02/OF04 a 175/75

`M4_HIST_CONVENIOS` es la tabla que dice a qué convenio pertenece cada tripulante. El mapeo a los códigos de BC (Adriana Sienes, 23/9/2026):

| Meta4 | BC |
|---|---|
| `JO`, `CA` | 372/2004 |
| `FA` | Fuera de convenio tierra |
| `FE` | Fuera de convenio embarcados españoles |
| `MR` | SOMU 729/2015 |
| **`OF` con categoría OF01 u OF03** | **AACPyPP 768/2019** |
| **`OF` con categoría OF02 u OF04** | **CCT 175/75** |

**`OF` NO es un convenio: son dos.** Se parte por categoría. Históricamente en el 175/75 estaban todos los sindicatos y después fueron firmando por separado; los únicos que quedaron en 175/75 son **SICONARA y MAQUINISTAS NAVALES**.

**Por qué:** invita a "unificar" los oficiales en un solo convenio, y eso paga mal. Los dos convenios difieren de verdad en cuota sindical (3,00% en 175/75 contra 2,50% en 768/19) y en dólar producción (60% contra 90%), más 29 parámetros que existen sólo en 175/75. Al 23/9/2026 **22 de los 46 oficiales de enero estaban en el convenio equivocado** según esta regla: 10 OF01 y 4 OF03 en 175/75, 5 OF02 y 3 OF04 en 768/19.

**Cómo aplicarlo:** antes de tocar el atributo `CONVENIO` hay que comparar cada parámetro con sufijo `_175/75` contra su gemelo `_768/19` **mirando también el campo Moneda**: varios precios del 175/75 están en USD y sus equivalentes de 768/19 en pesos, así que comparados en crudo parecen diferir 540× y no difieren en nada. Hay 48 parámetros en USD y 4 en EUR en `Parámetro Vigente`.

## Relacionado

- [[art19-calamar-cuenta-corriente]]
- [[basico-de-tierra-por-empleado]]
- [[cct-175-75-remuneracion-navegacion]]
