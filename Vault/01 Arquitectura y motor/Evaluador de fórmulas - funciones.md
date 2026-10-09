---
tipo: referencia
tags: [motor, evaluador, formulas]
fuente: [src/Codeunits/Cod50015.EvaluadorFormula.al, src/Codeunits/Cod50060.CatalogoVariablesLiq.al]
actualizado: 2026-10-04
---

# Evaluador de fórmulas - funciones

Las funciones son las del `case` de `CallFunction` (Cod50015). Hay **12**, y el catálogo del editor
(`Catálogo Variables Liq.`, Cod50064, `Inicializar`) es su **espejo**: agregar una función obliga a
tocar los dos, más `IsFormulaKeyword` del motor (`BuildFormulaEvaluada`). Ver [[Evaluador de fórmulas - sintaxis]].

| Función | Firma | Argumentos evaluados |
|---|---|---|
| `TRAMO` | `TRAMO('CÓDIGO', valor)` | siempre |
| `ROUND` | `ROUND(valor, precisión)` | siempre |
| `REDONDEAR` | `REDONDEAR(valor, decimales)` | siempre |
| `ABS` | `ABS(valor)` | siempre |
| `PISO` | `PISO(valor)` | siempre |
| `TECHO` | `TECHO(valor)` | siempre |
| `MIN` | `MIN(a, b)` | siempre (dos argumentos exactos) |
| `MAX` | `MAX(a, b)` | siempre (dos argumentos exactos) |
| `IF` | `IF(cond, si_verdadero, si_falso)` | **perezosa**: sólo la rama elegida |
| `IFZERO` | `IFZERO(valor, alternativa)` | **perezosa**: la alternativa sólo si el valor es 0 |
| `CASE` | `CASE(c1, v1, c2, v2, …, default)` | **perezosa**: sólo el valor devuelto |
| `DIV` | `DIV(a, b)` | siempre |

Una función desconocida corta con *"Función desconocida: X."* (en modo tolerante devuelve `0`). Los nombres de función no distinguen mayúsculas (la fórmula se pasa a mayúsculas).

## `TRAMO('CÓDIGO', valor)`

Consulta una [[Tablas escalonadas|tabla escalonada]]. El primer argumento **debe** ser un literal entre comillas simples; el segundo, cualquier expresión.

```
TRAMO('TAB_IMP_4CAT', MAX(BASE_IG4 * 12 - MNI_ANUAL, 0)) / 12
```

- `valor <= 0` → devuelve `0` (y deja una entrada de log "No se consultó la tabla: la base es…" para que se vea en el detalle).
- Resultado = `Monto Fijo + (% / 100) × (valor − Límite Inferior)` del tramo hallado. **No acumula tramos**: el `Monto Fijo` de cada tramo tiene que traer el impuesto de los anteriores.
- Los argumentos de `TRAMO` marcan `FTrazaBaseEscala` para que el detalle del cálculo separe "base de la escala" de "ajustes".
- Sin ninguna versión de la tabla vigente a `FechaRef` → error (`ErrTablaEscalonada`), salvo tolerante (0). Valor sin tramo → error, salvo tolerante/validación (0).
- Cachea por liquidación (versión por tabla y resultado por `(tabla, valor)`), y re-emite la entrada de log desde la caché para que cada línea que consulte lo mismo la tenga en su detalle.

## `ROUND(valor, precisión)`

`Round` de AL con **múltiplo** como precisión: `ROUND(x, 0.01)` redondea a centavos, `ROUND(x, 1)` a pesos, `ROUND(x, 0.0001)` a cuatro decimales. Precisión `0` → error *"ROUND con precisión 0: …"* (en modo validación/tolerante devuelve el valor sin redondear). Habitualmente la precisión sale de un parámetro (`PRECISION_REDONDEO`).

## `REDONDEAR(valor, decimales)`

Redondea a *n* decimales (`REDONDEAR(5473.286, 2) = 5473.29`). Internamente arma la precisión `1 / 10^n` con un bucle: `decimales <= 0` redondea a entero (no a decenas o centenas).

## `ABS`, `PISO`, `TECHO`

`ABS` valor absoluto. `PISO` = `Round(x, 1, '<')` (entero ≤ x). `TECHO` = `Round(x, 1, '>')` (entero ≥ x).

## `MIN` / `MAX`

Exactamente dos argumentos; para tres o más hay que anidar: `MAX(0, MIN(a, MIN(b, c)))`.

## `IF(cond, a, b)`

Lazy: la rama no elegida se **saltea a nivel de tokens** (`SkipExpression`) sin evaluarla, así que protege una división por cero. En modo validación/tolerante esa rama sí se parsea (para detectar variables inexistentes) y se descarta su valor.

> [!warning] Una rama muerta con un error de sintaxis no se detecta hasta que se elige
> En un cálculo real, `SkipExpression` sólo cuenta paréntesis y comas. Por eso la validación previa
> (fase 1) corre en modo validación, que sí parsea las dos ramas.

## `IFZERO(valor, alternativa)`

`valor` si no es cero, si no `alternativa`. Existe para parámetros que no están cargados para todos los pares convenio/categoría: un parámetro sin vigencia **resuelve a 0, no a error**, y multiplicar por 0 da 0 sin avisar (dejó 128 líneas de sueldo de oficiales en cero en enero de 2026). Cuidado: `IFZERO(X, 1)` convierte "no está cargado" en "vale 1", que es una decisión de negocio. Ver [[Parámetros y vigencias]].

## `CASE(c1, v1, c2, v2, …, default)`

Devuelve el valor de la **primera condición verdadera**. Con cantidad **impar** de argumentos, el último suelto es el default; con cantidad **par** no hay default y el resultado es `0`. Un solo argumento es error (*"CASE necesita al menos una condición con su valor"*). Es azúcar sobre `IF` anidados.

```
CASE(AÑOS_ANTIGUEDAD >= 10, PCT_10, AÑOS_ANTIGUEDAD >= 5, PCT_5, 0)
```

## `DIV(a, b)`

División segura: devuelve `0` si `b = 0`. A diferencia del operador `/`, que corta con *"División por cero en la fórmula."* (salvo tolerante/validación, donde da 0).

## Operadores lógicos y de comparación

`AND`, `OR`, `NOT` y `= <> < > <= >=` están en el catálogo como *operadores* (`DefOp`). El texto de ayuda dice "debe escribirse en mayúsculas", pero como el evaluador pasa **toda** la fórmula a mayúsculas, funcionan también en minúsculas (el editor sí los reconoce sin distinguir mayúsculas).

## Dónde vive cada pieza al agregar una función

1. `CallFunction` (Cod50015): el `case`.
2. `Catálogo Variables Liq.`.`Inicializar` (`DefFunc`) + la etiqueta de ayuda: autocompletado, firma y ayuda del editor.
3. `IsFormulaKeyword` (Cod50014): para que `BuildFormulaEvaluada` no intente reemplazar el nombre por un valor.
4. `Formateador Fórmula Liq.`: no necesita cambios (formatea por tokens), salvo que la función se corte distinto (como `CASE`, que corta de a pares).
5. Pruebas: `test/Codeunits` cubre el evaluador y el formateador.

## Relacionado

[[Evaluador de fórmulas - sintaxis]] · [[Editor de fórmulas]] · [[Formateador de fórmulas]] · [[format-no-se-valida-al-compilar]]
