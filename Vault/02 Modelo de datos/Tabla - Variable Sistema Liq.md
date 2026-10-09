---
tipo: tabla
tags: [modelo-datos, configuracion, variables, motor]
fuente: [src/Tables/Tab60018.VariableSistemaLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50077.GestionVariablesSistema.al]
actualizado: 2026-10-04
---

# Tabla - Variable Sistema Liq. (60018)

## Propósito
Mapea un **cálculo fijo en código** (`Cód. Cálculo`, resuelto en `ComputeVariableSistema` de `Cod50016.ContextoLiquidacion`) a un **nombre de variable configurable** que ven las fórmulas. La lógica es AL; lo único configurable es el nombre, qué se muestra en el recibo y el parámetro del cálculo (acumulador, concepto, tipo, estado). Sin filas, el motor no resuelve ninguna variable de sistema y la primera fórmula que use una corta con "Variable desconocida".

## PK
`Nombre Variable` (Code[30]), clustered. OnValidate → `ExigirLibre` (`Cod110051`).

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Cálculo` (1) | Code[30] | Qué cálculo corre. OnLookup: `StrMenu` con una lista fija (ver discrepancia abajo) |
| `Nombre Variable` (2) | Code[30] | Nombre en la fórmula |
| `Descripción` (3), `Activo` (4, InitValue true) | | Sólo las activas entran al universo de nombres conocidos |
| `Mostrar en Recibo` (5), `Etiqueta Recibo` (6) | | Presentación |
| `Etiqueta Det. Ganancias` (7), `Orden Det. Ganancias` (8) | | Si no es vacía, el motor escribe una fila `Paso` en [[Tabla - Detalle Ganancias Liq]] |
| `Cód. Acumulador` (9) | → `Concepto Liquidación` (`Es Acumulador`) | Requerido por `YTD_ACUM`, `PERIODO_ACUM` |
| `Tipo Concepto` (10) | Enum | Requerido por `YTD_LINEAS` |
| `Cód. Concepto` (11) | → `Concepto Liquidación` | Requerido por `PERIODO_CONCEPTO`. Sin filtro de vigencia a propósito: acumula lo ya liquidado, incluso de un concepto discontinuado |
| `Cód. Estado` (12) | → `Cód. Estado Empleado` | Requerido por `DIAS_ESTADO_PERIODO` / `DIAS_ESTADO_PREVIOS`: permite `DIAS_ENFERMEDAD` y `DIAS_ACCIDENTE` sin un cálculo por cada licencia |

## Catálogo de `Cód. Cálculo` (verificado contra el `case` de `Cod50016`)
`AÑOS_ANTIGUEDAD`, `AÑOS_ANTIG_30JUN`, `DIAS_HAB`, `DIAS_MES`, `DIAS_FERIADOS`, `DIAS_FERIADOS_MAREA`, `DIAS_FERIADOS_GUARDIA`, `PCT_ESCALA`, `DIAS_PROYECTO`, `DIAS_PUERTO`, `DIAS_MAREA`, `DIAS_ENROLAMIENTO`, `DIAS_FRANCOS_PERIODO`, `PAGO_FRANCOS_FIFO`, `FRANCOS_CONSUMIDOS`, `SALDO_FRANCOS`, `VACACIONES_ANUALES`, `DIAS_HAB_AÑO`, `DIAS_ALTA_AÑO`, `VACACIONES_PROP_DIAS`, `MESES_PROM_VAC`, `MESES_PROM_AUS_6`, `MESES_PROM_AUS_12`, `DIAS_ESTADO_PERIODO`, `DIAS_ESTADO_PREVIOS`, `DIAS_VAC_PERIODO`, `DEDUC_GANANCIAS`, `MES_ANUAL`, `TIPO_LIQ`, `YTD_ACUM`, `PERIODO_ACUM`, `PERIODO_CONCEPTO`, `YTD_LINEAS`.

Significados no obvios: `DIAS_MAREA` = `DIAS_PROYECTO + DIAS_PUERTO`; `DIAS_ENROLAMIENTO` = días calendario en estados que devengan francos en toda la marea; `SALDO_FRANCOS` = devengados − consumidos; `PERIODO_ACUM` es `YTD_ACUM` acotado al período **excluyendo la liquidación en curso** (tope mensual SIPA con más de una liquidación); `TIPO_LIQ` = *Orden* del tipo (cero es "sin tipo" y también el Orden de SALDO_INICIAL); `DIAS_FERIADOS_MAREA` y `DIAS_FERIADOS_GUARDIA` son disjuntos (no pagan dos veces el mismo feriado). Detalle del motor en [[Contexto de liquidación y variables]] y [[Variables de sistema]].

> [!warning] Discrepancia: catálogo documentado vs. código
> El comentario de cabecera de la tabla y el `StrMenu` de `OnLookup` **no incluyen** `DIAS_MES`, `MESES_PROM_AUS_6`, `MESES_PROM_AUS_12`, `DIAS_ESTADO_PERIODO` ni `DIAS_ESTADO_PREVIOS`, que el motor sí resuelve. Se pueden tipear a mano o sembrarlos (`Cod50077`), pero no aparecen en el lookup. `Cod50077` pide mantener los tres sitios sincronizados.

## Triggers
Sólo validación de nombre. **Ningún proceso escribe esta tabla**: es configuración pura. `Cod50077.GestionVariablesSistema.Sembrar()` la puebla de forma idempotente (por `Cód. Cálculo`, no por nombre, para no duplicar una variable renombrada) y deja afuera `YTD_ACUM`/`YTD_LINEAS` (no tienen nombre canónico). Siembra `DIAS_ENFERMEDAD` (AU1), `DIAS_ACCIDENTE` (ACC) y `DIAS_ACC_PREVIOS`.

## Quién la lee
`Cod50016.ContextoLiquidacion` (carga), `Cod50014`, `Cod50060.CatalogoVariablesLiq`, `Cod110044/110051`, `Cod50081.ControlMareaLiq`. Página: `Pag50146 Variable Sistema List`, `PagExt50352 ITManagerRCPayrollExt`. Bloquea el borrado de un acumulador que use ([[Tabla - Concepto Liquidación]]).

## Vigencias
No tiene.

## Trampas conocidas
> [!danger] Una variable de sistema hay que sembrarla
> El `Cód. Cálculo` en AL no alcanza: sin la fila el cálculo corta, y RAD no dispara el Upgrade. Ver [[variable-sistema-hay-que-sembrarla]].

- Convenciones de nombres reservados y sufijos: [[system-variables-conventions]].
- Variables cuyo nombre aún existe pero valen cero (`AÑOS_ANTIG_30JUN`, `MESES_PROM_AUS_*`): [[variables-rotas-valen-cero]].
- `TIPO_LIQ` documentada pero no implementada en la ayuda: [[tipo-liq-no-implementada]].
- Ventana del promedio: [[ventana-promedio-ausentismo]], [[vacaciones-tripulantes-promedio]].
