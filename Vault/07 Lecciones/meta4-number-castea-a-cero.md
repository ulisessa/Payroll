---
aliases: ["Trampas de forma al leer Meta4"]
tipo: leccion
tema: migracion-meta4
tags: [leccion, migracion-meta4, feedback]
origen: 7aa458fa-440c-4ba2-a50b-60d4d7167eea
actualizado: 2026-09-19
---

# Trampas de forma al leer Meta4

> [!warning] Falla en silencio
> Dos trampas de forma al leer Meta4 desde PowerShell: el DataRow que se indexa por columna y el DataReader que se enumera al devolverlo

Dos trampas distintas del helper `ora/Meta4.ps1`, las dos silenciosas y las dos por la **forma** del objeto, no por el dato.

## 1. `M4-Query` devuelve un `DataRow`, no un array, cuando hay una sola fila

Y `$r[0]` sobre un `DataRow` indexa **la primera columna**, no la fila. Entonces `$r[0].TOT` evalúa `.TOT` sobre el valor de esa columna, que no lo tiene: da `$null`, y de ahí sale `0` al castear a número o `''` al castear a string.

**Regla: envolver siempre en `@(...)` antes de indexar — `@($r)[0].TOT`.** Con varias filas `$r` sí es un array, que es por qué la misma consulta con `GROUP BY` funciona y la escalar no.

## 2. `M4-Reader` se enumera si se devuelve con `return $rd`

Un `OracleDataReader` es `IEnumerable`, así que PowerShell lo desarma al devolverlo y el llamador recibe **el primer registro** (`DataRecordInternal`, que no tiene `.Read()`) en vez del lector. Se arregla con el operador coma: `return ,$rd`. Y del lado del llamador, `@(M4-Reader ...)[0]`.

**Por qué:** ninguna de las dos avisa. En la primera, `0` es una respuesta perfectamente creíble a "¿cuántos valores no nulos hay?"; el fallo no se distingue de un hallazgo. Me hizo afirmar dos veces cosas falsas sobre `M4T_ACUMULADO_RL2` —que estaba vacía en 2025, y que el total de 31 años era cero— y reporté la primera antes de verificarla. Encima me llevó a un diagnóstico equivocado: lo atribuí al separador decimal con coma (que es un problema real, pero en otro contexto — ver [[export-csv-decimal-con-coma]]) y escribí una regla inútil, envolver todo en `TO_CHAR`, que no arregla nada porque la causa era el indexado.

**Cómo aplicarlo:** si una agregación sobre Meta4 da 0 o vacío, sospechar de la forma del objeto **antes** que del dato. El contraste barato es volver a pedirla con `GROUP BY` y recorrer con `foreach`: si así aparece el valor, es el indexado. Y ante cualquier `$x.GetType().Name` inesperado (`DataRecordInternal`, `DataRow` donde se esperaba un array), la causa casi siempre es que PowerShell enumeró o desarmó algo al devolverlo.

Ver [[meta4-conectar-desde-powershell]] y [[previsualizar-antes-de-migrar]].

## Relacionado

- [[meta4-conectar-desde-powershell]]
- [[meta4-es-oracle]]
- [[migracion-atributos-cct-meta4]]
- [[migracion-estados-meta4]]
- [[migracion-novedades-meta4]]
- [[migracion-tipo-liq-incompleta]]
- Tema: `migracion-meta4` (ver [[_Convenciones del vault]])
