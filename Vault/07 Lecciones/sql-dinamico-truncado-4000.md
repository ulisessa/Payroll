---
aliases: ["SQL dinámico truncado a 4000"]
tipo: leccion
tema: sql-bc-infra
tags: [leccion, sql-bc-infra, feedback]
actualizado: 2026-10-04
---

# SQL dinámico truncado a 4000

> [!warning] Falla en silencio
> Concatenar literales N'' para armar SQL dinámico da nvarchar(4000) aunque la variable sea max — el SQL se guarda cortado, sin error

**En T-SQL el tipo de una concatenación lo fija la EXPRESIÓN, no la variable destino.** Si armás SQL
dinámico juntando literales `N'...'` y variables cortas, el resultado es `nvarchar(4000)` aunque
`@sql` esté declarada `nvarchar(max)`: pasando los 4000 caracteres **se guarda cortado, sin error ni
advertencia**.

```sql
SET @sql = CAST(N'' AS nvarchar(max)) + N'MERGE ...';   -- el CAST del primer operando es lo que
                                                        -- arrastra nvarchar(max) a toda la expresión
```

**Por qué:** el síntoma es un error de sintaxis en el punto del corte, que casi nunca tiene que ver con
el problema. En `scripts/SincronizarNAV_2013R2.sql` (11/9/2026) el MERGE de empleados quedó en ~4300
caracteres y el servidor tiró *"Incorrect syntax near 'src'"* — `src` era, literalmente, donde
terminaba el carácter 4000. El `PRINT @sql` de depuración **no** estaba truncando la salida: mostraba
fielmente un `@sql` ya truncado.

**Cómo aplicarlo:**

1. Todo `SET @sql = ...` que arme algo largo arranca con `CAST(N'' AS nvarchar(max)) +`.
2. **Los comentarios largos van AFUERA del literal.** Adentro son carga útil que viaja al servidor en
   cada corrida y que cuenta para el límite — meter un párrafo explicativo adentro del MERGE fue
   justamente lo que lo empujó sobre los 4000. Además, ahí dentro una comilla simple cierra la cadena.
3. Se puede verificar offline, sin base: parsear con `Microsoft.SqlServer.TransactSql.ScriptDom.dll`
   (viene con SSMS, en `Release\Common7\IDE\Extensions\Application\`). Reconstruyendo el literal
   —reemplazar los splices `' + expr + N'` y deshacer las comillas dobladas— se obtiene el SQL
   generado, se mide el largo y se lo parsea. Así aparecieron cuatro bugs sin tocar el servidor.

**Niveles de escape dentro de un OPENQUERY:** un literal que va adentro de la consulta interna lleva
`''''` en el archivo (no `''`), porque hay dos niveles: el de `@sql` y el de la cadena del OPENQUERY.

Relacionado: [[linked-server-leer-escalar-remoto]].

## Relacionado

- [[linked-server-leer-escalar-remoto]]
- [[sql-ares-dos-collations]]
- [[sql-directo-deja-cache-rancia]]
- [[subconsulta-correlacionada-silenciosa]]
- Tema: `sql-bc-infra` (ver [[_Convenciones del vault]])
