---
tipo: tabla
tags: [modelo-datos, parametros, effective-dating]
fuente: [src/Tables/Tab60008.ParametroVigente.al]
actualizado: 2026-10-04
---

# Tabla - Parámetro Vigente (60008)

## Propósito
**Valores con vigencia** de los parámetros ([[Tabla - Parámetro]] es el maestro/definición). Cada fila responde "cuánto vale el parámetro X para este convenio/categoría/empleado desde esta fecha". Es donde viven sueldos básicos, porcentajes, topes, valores de franco, tipos de cambio, etc.

## Clave: la "clave derivada"
`Cód. Parámetro` (caption **Clave Derivada**) **no se tipea**: se arma siempre con `Claves Parámetro Liq.`.`ArmarDeFila` (`Cod50071`) desde el código base y los ejes completos de la fila. Ejemplos: `BASICO_175/75_CAPITAN`, `VALOR_FRANCO_LAN_729/15_MR05`. `Nivel` también se calcula (`NivelDeFila`): 0 base, 1 convenio **o** empleado, 2 convenio + categoría (es la indentación del árbol `Pag110013`).

## PK e índices
| Clave | Campos |
|---|---|
| PK (clustered) | `Cód. Parámetro Base`, `Cód. Parámetro`, `Vigencia Desde` |
| `Codigo` | `Cód. Parámetro`, `Vigencia Desde` |

> [!warning] La PK empieza por "Cód. Parámetro Base"
> Un `Get` con menos argumentos que la PK **compila** y asigna al campo equivocado. Ver [[get-con-menos-argumentos]].

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Parámetro Base` (10) | Code[20] → `Parámetro` | Definición del parámetro |
| `Cód. Parámetro` (1) | Code[50] | Clave derivada (no editable, sin TableRelation: las claves derivadas no existen como registros de Parámetro) |
| `Vigencia Desde` (2) | Date | Inicio de vigencia |
| `Valor` (4) | Decimal (0:6) | El valor |
| `Moneda` (5) | Code[10] → `Currency` | Moneda del valor (habilita las variantes `_ESFCY`) |
| `No. Empleado` (8) | Code[20] → `Employee` | Eje más específico: valor para un empleado; **limpia convenio y categoría** y no se combina con ellos |
| `Cód. Convenio` (11) | Code[20] → `Convenio Colectivo` | Vaciarlo limpia categoría; cargarlo limpia empleado |
| `Cód. Categoría` (12) | Code[20] → `Categoría CCT` (filtrada por convenio) | Error si se carga sin convenio |
| `Nivel` (13), `En Uso` (6), `Descripción` (3 "Descripción Versión"), `Notas` (7) | | `En Uso` lo marca el motor al usar el valor; no editable |

## Triggers y validaciones
- OnValidate de empleado/base/convenio/categoría → `RecalcularClave()`.
- **OnInsert**: si falta la base la deduce con `DeriveBase` (prefijo más largo que coincida con un `Parámetro.Código` + `_`), recalcula, y `ValidarClaveLibre`.
- **OnModify**: `ValidarClaveLibre` (excluye la fila propia por su PK) y, si estaba `En Uso`: bloquea cuando hay liquidaciones Calculada/Aprobada/Contabilizada (del empleado si el valor es por empleado); si no hay ninguna, libera `En Uso`.
- **OnRename**: se dispara porque cambiar la clave derivada es renombrar la PK; reaplica `ValidarClaveLibre` con la clave vieja.
- **OnDelete**: mismo bloqueo por `En Uso`.
- `ValidarClaveLibre`: dos filas con la misma clave derivada y vigencia son dos respuestas a la misma pregunta; la PK las admitiría si difieren en el código base.

## Quién la lee / escribe
Lee: `Cod50016.ContextoLiquidacion` (carga de parámetros, `Cód. Convenio`/`Cód. Categoría` de la liquidación, `UsarParCCT`), `Cod50019.GestionLiquidacion`, `Cod50053.GestionFrancos`, `Cod50060.CatalogoVariablesLiq`, `Cod50081.ControlMareaLiq`, `Cod50071.ClavesParametroLiq`; es también fuente de datos (`Tabla Origen Liq.` = Parámetro Vigente, [[Enums de liquidación#Tabla Origen Liq]]). Escribe: `Cod50049.InstallParametroBase`, páginas `Pag50137` (subpágina del parámetro), `Pag50153` (sufijos), `Pag50154` (lista), `Pag110013` (árbol), `Pag110014` (ficha), `Pag110016` (claves a revisar). Liberación masiva de `En Uso`: [[Tabla - Liquidación]] OnDelete.

## Vigencias
Effective-dating por `Vigencia Desde` (se toma la última `<=` la fecha de referencia), por clave derivada. La resolución jerárquica (empleado > convenio+categoría > convenio > base) está en el contexto.

## Trampas conocidas
- Faltan en el ConfigPackage los sufijos de Parámetro Vigente: [[configpackage-campos-faltantes]].
- Parámetro y atributo/otro parámetro con el mismo nombre: gana uno y el otro queda mudo o pisa con cero: [[parametro-y-atributo-mismo-nombre]], [[dos-parametros-mismo-nombre]], [[tc-comprador-parametro-fantasma]].
- Un valor, una fuente: [[un-valor-una-fuente]]. Unidades mezcladas (PCT_ en % vs fracción): [[parametros-somu-por-pesqueria]].
- UPDATE por SQL directo no invalida la caché: [[sql-directo-deja-cache-rancia]].
- `CopyFilters` copia sólo el grupo actual: [[copyfilters-solo-grupo-actual]].
