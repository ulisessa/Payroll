---
aliases: ["Bucle que modifica el campo filtrado"]
tipo: leccion
tema: desarrollo-al
tags: [leccion, desarrollo-al, project]
origen: 9be8057e-0e48-430a-b6b0-cc4322f51ebc
actualizado: 2026-08-11
---

# Bucle que modifica el campo filtrado

Un bucle por lotes procesa sólo el primer registro, sin error, cuando la acción cambia el campo por el que se filtra.

> [!warning] El lote se detiene después del registro 1 sin dar error. Juntar las claves primarias primero y actuar en una segunda pasada.

## Qué pasa

Es una clase de bug recurrente en este código, encontrada tres veces distintas (la última el 2026-08-11). Una acción por lotes filtra por `Estado` y luego llama a algo que **cambia** `Estado`. El registro sale del filtro, `Next()` devuelve 0 y el bucle termina después del primer registro, **sin error**. El mensaje de éxito reporta "1 procesada" como si fuera toda la selección, así que parece que la multiselección está rota y no que hay un bug.

```al
Liq.SetRange(Estado, Liq.Estado::Calculada);   // filtra por Estado
Liq.FindSet();
repeat
    Gestion.Reabrir(Liq);                       // ...y Reabrir lo pasa a Borrador
    N += 1;
until Liq.Next() = 0;                           // 0 en la primera vuelta
```

## Cómo aplicarlo

**Juntar las claves primarias en un `List` primero y actuar en una segunda pasada**, haciendo `Get` de cada registro y revisando de nuevo su estado (pudo cambiar entre las dos pasadas).

Instancias conocidas, todas corregidas:

- `LimpiarParaRecalculo` — Cod50066 "Gestión Novedades Liq."
- `Reabrir` — Pag50100 "Lista Liquidaciones"
- `RevertirCalculadas` y `ReabrirPeriodo` — Pag50110 "Períodos Liquidación"

`Delete` + `Next()` **no** está afectado (el delete no cambia el campo filtrado), así que `EliminarBorradores`/`EliminarSelección` están bien como están. El riesgo es específicamente un `Modify` sobre un campo que aparece en el filtro activo.

## Cómo detectarlo

Al auditar si hay más: `grep "SetRange(Estado\|SetFilter(Estado"` y revisar qué llama el cuerpo del bucle.

## Relacionado

- [[codeunit-run-necesita-commit]]
- [[get-con-menos-argumentos]]
- [[al-sin-cortocircuito]]
- [[firma-recibos-digitales]]
