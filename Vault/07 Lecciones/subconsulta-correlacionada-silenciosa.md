---
aliases: ["Subconsulta correlacionada silenciosa"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, feedback]
actualizado: 2026-10-04
---

# Subconsulta correlacionada silenciosa

> [!warning] Falla en silencio
> Un nombre de columna mal escrito dentro de un IN (SELECT ...) no da error, se resuelve contra la tabla de afuera y el filtro deja de filtrar

En SQL Server, si la columna de un `IN (SELECT col FROM Otra ...)` no existe en `Otra`,
el motor **no falla**: la resuelve contra la tabla de la consulta externa. La subconsulta
queda correlacionada y el `IN` da verdadero para toda fila donde el `WHERE` interno
encuentre algo, así que el filtro desaparece sin un solo mensaje.

Pasó con las tablas de la extensión, donde los nombres se parecen mucho entre sí:
`Línea Liquidación` tiene `[No_ Liquidación]`, pero la cabecera `Liquidación` se llama
`[No_]`. Un control que debía traer 4 líneas de una marea devolvió 34 de mareas ajenas,
con números perfectamente plausibles.

**Por qué:** los nombres de columna de BC en SQL son largos y casi iguales entre cabecera y
línea, así que equivocarse es lo normal, y el modo de falla es silencioso y creíble.

**Cómo aplicarlo:** en los scripts de control usar **JOIN explícito** en vez de
`IN (SELECT ...)`. Con el JOIN, el nombre mal escrito es un error de compilación. Si hace
falta un `IN`, calificar siempre la columna interna con el alias de su tabla
(`SELECT x.[No_] FROM ... x`), que fuerza el mismo error.

Misma familia que [[get-con-menos-argumentos]]: la API acepta algo incompleto y elige por
vos. Y el que lo detecta es un control de invariante, no la lectura del código:
ver [[previsualizar-antes-de-migrar]].

## Relacionado

- [[linked-server-leer-escalar-remoto]]
- [[sql-ares-dos-collations]]
- [[sql-dinamico-truncado-4000]]
- [[sql-directo-deja-cache-rancia]]
- Tema: `sql-bc-infra` (ver [[_Convenciones del vault]])
