---
aliases: ["Fuente de Datos apunta por número"]
tipo: leccion
tema: parametros-atributos
tags: [leccion, parametros-atributos, feedback]
actualizado: 2026-10-04
---

# Fuente de Datos apunta por número

Borrar un campo de una tabla rompe las Fuentes de Datos que lo referencian por número, y el compilador no ve nada

> [!danger] Borrar un campo rompe en runtime las Fuentes de Datos que lo referencian por número; el compilador no lo ve.

`Fuente Datos Liquidación` guarda `Id. Tabla` + `No. Campo` como **números**. Al borrar un campo
de una tabla, AL compila perfecto y el error aparece recién al calcular:

    No se pudo calcular la liquidación:
    El número de campo proporcionado '4' no se encuentra en la tabla 'Personal Proyecto'.

Y revienta **aunque ninguna fórmula use esa variable**: el contexto carga todas las fuentes
activas, se usen o no. Pasó el 18/9/2026 al eliminar `Cód. Convenio`, `Cód. Categoría` y
`Rol en Proyecto` de `Personal Proyecto`; la que rompía era `CAT_MAREA`, huérfana desde que la
producción pasó a resolverse por el par.

**Por qué:** una referencia por número no es un símbolo, así que ni el compilador ni un grep la
encuentran. El único momento en que se nota es en runtime, sobre una liquidación real.

**Cómo aplicarlo:** antes de borrar un campo, buscarlo por NÚMERO en la configuración:

```sql
SELECT * FROM [<Empresa>$Fuente Datos Liquidación$<app>]
WHERE [Id_ Tabla] = <tabla> AND (<n> IN ([No_ Campo Valor],[No_ Filtro 1],[No_ Filtro 2],
      [No_ Filtro 3],[No_ Campo Fecha Inicio],[No_ Campo Fecha Fin]));
SELECT f.* FROM [<Empresa>$Filtro Fuente Datos Liq_$<app>] f
JOIN [<Empresa>$Fuente Datos Liquidación$<app>] d ON d.[Nombre Variable]=f.[Nombre Variable]
WHERE d.[Id_ Tabla] = <tabla> AND f.[No_ Campo] = <n>;
```

Los filtros viven en una tabla aparte y hay que borrarlos con la fuente. Misma familia que
[[configpackage-campos-faltantes]]: configuración que referencia al código sin que el código lo
sepa. Ver [[atributos-tipados]].

## Relacionado

- [[configpackage-campos-faltantes]]
- [[atributos-tipados]]
- [[antiguedad-maxima-vigencia-avisa-de-mas]]
- [[dos-parametros-mismo-nombre]]
