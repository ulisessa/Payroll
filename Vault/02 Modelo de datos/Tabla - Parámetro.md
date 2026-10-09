---
tipo: tabla
tags: [modelo-datos, parametros]
fuente: [src/Tables/Tab60016.Parametro.al]
actualizado: 2026-10-04
---

# Tabla - Parámetro (60016)

## Propósito
**Definición** de un parámetro de liquidación (código, nombre de variable en las fórmulas, reglas de chequeo). Los **valores** con vigencia viven en [[Tabla - Parámetro Vigente]].

## PK
`Código` (Code[20]), clustered. LookupPage `Parámetros`.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Código` (1), `Descripción` (2), `Notas` (3) | | |
| `Nombre Variable` (4) | Code[30] | Nombre expuesto en el contexto de fórmulas; **en blanco = no se carga automáticamente**. OnValidate → `ExigirLibre` (colisiones con atributos, fuentes, variables de sistema, conceptos). El motor genera también `<Nombre>_ESFCY` para valores en moneda |
| `Antigüedad Máxima Vigencia` (7) | DateFormula | Si la última `Vigencia Desde` es anterior a `fecha liquidación + fórmula` se avisa "valor desactualizado" (MNI_ANUAL, DESP_4CAT_ANUAL…). **Debe retroceder** (`-1M`, `-35D`): una fórmula positiva se rechaza (COEF_GUARDIA_PUERTO con `+1M` dejó 2.532 avisos en enero 2026) |
| `Edad Máxima Familiar` (9) | Integer | Tope de edad para deducir al familiar en Ganancias (HIJO 18; HIJO_INC y CONYUGE 0 = sin límite). **Sin fecha de nacimiento no se aplica**: no se da de baja una deducción por un dato faltante |
| `Sufijo CCT` (5), `Sufijo Empleado` (6), `Sufijo Convenio` (8) | Boolean | **Obsoletos (Pending)**. Antes declaraban el eje del parámetro; hoy la clave derivada sale de los campos completos de cada valor y la cascada los consulta todos |

## Triggers y procedimientos
- **OnRename**: arrastra los valores: fotografía los `SystemId` de los Parámetro Vigente con ese código base y re-nombra cada uno reconstruyendo la clave derivada con el prefijo nuevo (`ZONA_DESF_ADM` → `NUEVO_ADM`). Sin eso el motor no vuelve a encontrar ningún valor.
- **OnDelete**: error si algún valor está `En Uso`; si no, borra todos los valores.
- `CopiarEn(NuevoCodigo)`: copia el parámetro y reconstruye cada clave derivada con el prefijo nuevo; deja `En Uso = false`.

## TableRelations
Referenciado por `Parámetro Vigente."Cód. Parámetro Base"`; la extensión [[Extensión - Employee Relative]] usa el parámetro para la edad del familiar.

## Quién la lee
`Cod50016.ContextoLiquidacion` (`LoadParametros`), `Cod50014`, `Cod50019`, `Cod50053.GestionFrancos`, `Cod50060.CatalogoVariablesLiq`, `Cod50071.ClavesParametroLiq`, `Cod50081.ControlMareaLiq`, `Cod50049.InstallParametroBase`, `Cod110044/110051`. Páginas: `Pag50108 Parámetros`, `Pag50138 Parámetro Card`.

## Vigencias
Sin vigencia propia (la tienen sus valores).

## Trampas conocidas
> [!danger] Nombre duplicado entre parámetro y atributo/otro parámetro
> Gana uno y el otro queda mudo (o pisa con cero). Se arregla fusionando niveles, no renombrando. Ver [[parametro-y-atributo-mismo-nombre]], [[dos-parametros-mismo-nombre]], [[tc-comprador-parametro-fantasma]].

- Convenciones de sufijos y derivación de nombres de variable: [[system-variables-conventions]].
- El aviso de parámetro desactualizado grita de más cuando la fórmula avanza o el alcance se confunde con falta de carga: [[antiguedad-maxima-vigencia-avisa-de-mas]].
- ConfigPackage no lleva los sufijos de Parámetro Vigente ni algunos campos: [[configpackage-campos-faltantes]].
