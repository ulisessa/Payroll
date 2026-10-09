---
aliases: ["Un JOIN por menos campos que la PK infla el control"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, project]
actualizado: 2026-10-08
---

# Un JOIN por menos campos que la PK infla el control

El `Get` con menos argumentos que la PK tiene su gemelo en SQL, y ahí no asigna mal: acusa cambios que no existen

> [!warning] Antes de comparar una foto previa contra el estado nuevo, contar las filas del JOIN. Si no son exactamente las de la foto, el control está enfrentando filas que no se corresponden.

Al migrar las fórmulas a CRLF, la invariante que importa era «el texto sin saltos tiene que ser idéntico al de antes». Comparaba una temp table contra la tabla, unidas por `Código`. Acusó cambios de contenido en dos conceptos. No había ninguno: **la PK de `Concepto Liquidación` es `Código` + `Vigencia Desde`** ([[Versionado de conceptos y fórmulas]]), y `PCT_ANTIG_SOMU` tiene dos vigencias.

Con 298 filas y un código repetido, el JOIN devolvía **300**: la fórmula de una vigencia se comparaba contra la de la otra, que legítimamente es distinta.

**La guarda que lo cierra**, y que ahora va antes de confiar en cualquier comparación contra una foto:

```sql
SELECT @n = COUNT(*) FROM #antes a JOIN <tabla> c ON <clave completa>;
IF @n <> (SELECT COUNT(*) FROM #antes) THROW 50002, 'el join no es uno a uno', 1;
```

**Por qué costó encontrarlo:** el síntoma —«cambió el contenido»— apunta al UPDATE, no al control. Verificar la conversión por separado mostró que preservaba el texto en **todas** las filas, y recién ahí quedó claro que el problema era la invariante. Antes de eso pasé por dos hipótesis falsas, las dos razonables y las dos descartables con una consulta:

- **colación**: la temp table vive en `tempdb`, que puede tener otra colación que la base. Forzar `Latin1_General_BIN2` en los dos lados **no** arregló el conteo, así que no era eso. (Vale la pena igual: para un control de *preservación de texto* la binaria es la correcta, porque una diferencia de acento o de mayúscula es un cambio real y la colación de la base la da por igual.)
- **espacios finales**: SQL ignora el relleno a la derecha en **cualquier** colación, así que `'1063'` y `'1063 '` se unen. `LEN` contra `DATALENGTH/2` lo descarta en una línea. Tampoco era.

La respuesta estaba en `sys.indexes`: mirar la PK **primero** hubiera ahorrado las dos.

## Relacionado

- [[get-con-menos-argumentos]]
- [[Versionado de conceptos y fórmulas]]
- [[previsualizar-antes-de-migrar]]
- [[subconsulta-correlacionada-silenciosa]]
- [[sql-ares-dos-collations]]
- [[Formateador de fórmulas]]
