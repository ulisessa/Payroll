---
aliases: ["AL no cortocircuita and/or"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
origen: 9be8057e-0e48-430a-b6b0-cc4322f51ebc
actualizado: 2026-08-12
---

# AL no cortocircuita and/or

AL no garantiza cortocircuito en and/or: ContainsKey y Get nunca deben compartir una expresión.

> [!warning] Compila y explota en runtime: el Get corre aunque ContainsKey haya dado false. La guarda va en una sentencia separada.

**AL no garantiza cortocircuito en `and`/`or`.** Esto compila y explota en runtime:

```al
if Mapa.ContainsKey(Cod) and (Fecha = Mapa.Get(Cod)) then   // ❌
```

El `Get` se evalúa aunque el `ContainsKey` haya dado `false` → *"La clave proporcionada no estaba presente en el diccionario"*. La guarda tiene que ir en una **sentencia separada**:

```al
if not Mapa.ContainsKey(Cod) then exit(false);              // ✅
exit(Fecha = Mapa.Get(Cod));
```

Helpers que ya encapsulan el patrón: `EsVersionEnUso` (Cod50014) y `EsVersionVigente` (Cod50067). Usar esos en vez de escribir la guarda de nuevo.

**Por qué estuvo latente años (2026-08-11):** `SelectConceptos` y `BuildLatestVersionCache` usaban el mismo `SetRange(Activo, true)`, así que todo lo que devolvía el bucle estaba sí o sí en el mapa y el `Get` nunca fallaba. Al pasar la baja de concepto a resolverse por fecha (ver [[conceptos-tres-vigencias]]), el mapa empezó a excluir al concepto discontinuado mientras el bucle lo seguía devolviendo, y la deuda se cobró en **todas** las liquidaciones a la vez.

La lección general: cuando dos consultas se mantienen sincronizadas *por convención* y una cambia, lo que falla no es la que cambió sino un guard que nunca se ejercitó. Al tocar una de las dos, buscar los `.Get(` que dependían de esa correspondencia.

Auditoría: `grep -n "ContainsKey" | grep -E "and|or"` y revisar cuáles llaman `.Get(` en la misma expresión. Sanos: los que hacen el `Get` dentro del `then`.

**La misma trampa en un `while` (2026-10-27).** El ordenamiento por inserción del asiento de sueldos (`OrdenarTexto`, Cod110083) se escribió con la guarda natural, `while (j >= 1) and (Lista.Get(j) > Actual)`, y con `j = 0` evaluaba `Get(0)`: "An invalid argument was passed to a 'List' data type method" en la primera corrida real. `OrdenarClaves` de Cod50076 ya tenía la forma buena (el `while` sobre el índice y el `break` adentro) y su comentario lo explica. Compiló, y una revisión adversarial de 31 agentes no lo vio; lo vio la base. Auditoría: `grep -nE "while .*and .*\.Get\("`.

## Relacionado

- [[conceptos-tres-vigencias]]
- [[al-compile-command]]
- [[avoid-tables-principle]]
- [[borrar-rad-json-tras-cada-cambio]]
