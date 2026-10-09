---
tipo: concepto
tags: [motor, variables, nombres, controles]
fuente: [src/Codeunits/Cod110051.NombresVariablesLiq.al, src/Codeunits/Cod50060.CatalogoVariablesLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-04
---

# Nombres de variables y conflictos

Todo lo que una fórmula puede nombrar vive en **un solo espacio de nombres plano** (el diccionario del
[[Contexto de liquidación y variables|contexto]]), alimentado por **cinco** orígenes:

1. `Parámetro` (más su compañero `<VAR>_ESFCY`),
2. `Variable Sistema Liq.`,
3. `Fuente Datos Liquidación`,
4. `Tipo Atributo Liq.` (con `Nombre Variable`),
5. el **código de cada concepto** (`#CÓDIGO`, y los acumuladores, que se leen por su nombre pelado).

Dos cosas con el mismo nombre **no dan error**: se pisan, y cuál gana **depende del orden** en que el motor
arma el contexto, que nadie debería tener que saber para leer una fórmula. Peor: el ganador puede
**cambiar a mitad del cálculo** (`UsarParCCT` recarga sólo parámetros). Ver la tabla de precedencias en
[[Contexto de liquidación y variables]].

## Casos reales que motivaron el control

| Caso | Efecto |
|---|---|
| `TC_COMPRADOR` como Fuente de Datos **y** como Parámetro (una vigencia de 2023, valor 0) | resolvía bien en `ADIC_PROD_PESCA` y daba **0 en 125 de las líneas de `PROD_EMPRESA`** (la que tiene `Par CCT a Usar`): producción valuada a cero. [[tc-comprador-parametro-fantasma]] |
| `BASICO` y `BASICO_MENSUAL`, **los dos** declarando `BASICO` | el motor recorre `Parámetro` por código y hace `Ctx.Set` sin condición: ganaba `BASICO_MENSUAL`, cargado sólo por empleado, y ponía el token en **cero** para todos los demás, borrando el básico por convenio de los oficiales. [[dos-parametros-mismo-nombre]] |
| Concepto con código `AÑOS_ANTIGUEDAD` **y** variable de sistema homónima | mientras el concepto no se calcula, la variable vale lo correcto; desde que se calcula, cualquier fórmula posterior lee el **importe del concepto** creyendo leer la antigüedad (los dos números se parecen, uno es el otro redondeado) |
| Parámetro vs atributo con el mismo nombre | el atributo **no se carga** y su comparación por código falla. [[parametro-y-atributo-mismo-nombre]] |

## El control: `Nombres Variables Liq.`.`ExigirLibre` (Cod110051)

Se llama desde el `OnValidate` de `Nombre Variable` en las **cuatro** tablas (`Parámetro`, `Variable Sistema Liq.`, `Fuente Datos Liquidación`, `Tipo Atributo Liq.`) y corta con *"El nombre de variable X ya lo usa <tabla> (<código>)…"*. Detalles:

- Se **excluye al propio registro** (`TablaPropia`/`ClavePropia`) para no encontrarse a sí mismo al editar.
- Un parámetro `VAR` ocupa también **`VAR_ESFCY`**: el control mira por las dos puntas (`X` y `X` sin el sufijo).
- Para `Parámetro` se compara contra otros **parámetros** (excluyendo el propio código): dos parámetros con el mismo nombre ya no entran. Las variables de sistema y las fuentes se comparan contra el resto de las tablas.
- **No** mira códigos de concepto (acumuladores): eso lo cubre el informe de conflictos (abajo).
- Sólo frena lo que se **cargue de ahí en adelante**; lo ya duplicado sigue duplicado.

## Detectar lo ya cargado

| Herramienta | Qué mira |
|---|---|
| `Nombres Variables Liq.`.`Duplicados()` | las **cuatro** tablas entre sí (`OcupadoPorOtro`); incluye el choque Parámetro-Parámetro, que **faltaba** en esta función aunque `ExigirLibre` sí lo chequeaba |
| `Catálogo Variables Liq.`.`NombresEnConflicto()` | las cuatro fuentes **más todos los códigos de concepto** (no sólo acumuladores: el importe de cada concepto queda en el contexto bajo su código). Recorre los orígenes **por separado** porque el catálogo del editor (`SetVarCat`) pisa el nombre repetido igual que el motor y no sirve para detectarlo |

## Reglas prácticas

- Un nombre de variable **en mayúsculas** (la fórmula se pasa a mayúsculas antes de parsear; uno en minúsculas no se encuentra nunca, y el editor lo marca).
- Usar nombres que **no se parezcan a un código de concepto** (`1003`, `AÑOS_ANTIGUEDAD`). Si el nombre ya existe, renombrar el que hace menos falta.
- No usar `_ESFCY` como sufijo propio.
- **Un valor, una fuente**: no duplicar un parámetro en una fuente o viceversa ([[un-valor-una-fuente]]).
- Al **renombrar** un parámetro hay trampas de prefijo (las claves derivadas llevan el código base como prefijo): `Parámetro.OnRename` las reconstruye.
- Los nombres admiten `Ñ` y acentos (el evaluador los tokeniza); sin eso la plataforma dejaba crear `AÑOS_ANTIGUEDAD` y el tokenizador cortaba en la `Ñ` ("Variable desconocida: A").

## Relacionado

[[Parámetros y vigencias]] · [[Variables de sistema]] · [[Fuentes de datos]] · [[Evaluador de fórmulas - sintaxis]] · [[Editor de fórmulas]]

**Tablas relacionadas:** [[Tabla - Parámetro]] · [[Tabla - Variable Sistema Liq]] · [[Tabla - Fuente Datos Liquidación]] · [[Tabla - Tipo Atributo Liq]]
