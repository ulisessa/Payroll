---
tipo: tabla
tags: [modelo-datos, transaccional, motor]
fuente: [src/Tables/Tab60011.Liquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Liquidación (60011)

## Propósito
**Cabecera** del recibo: una por (empleado, período, tipo de liquidación, y proyecto en Cierre de Marea). Guarda totales congelados, cobertura y el estado del flujo Borrador → Calculada → Aprobada → Contabilizada ([[Enums de liquidación#Estado Liq]]). Sus hijas son [[Tabla - Línea Liquidación]], [[Tabla - Incidencia Liquidación]] y las tablas de detalle de cálculo.

## PK e índices
| Clave | Campos | Uso |
|---|---|---|
| PK (clustered) | `No.` | |
| K2 | `Cód. Período`, `No. Empleado` | |
| K3 | `No. Proyecto` | |
| K4 | `Estado`, `Cód. Período` | |
| K5 | `Cód. Período`, `Cód. Tipo Liq.`, `Estado` | Filtro exacto de `CalcularPorPeriodo` (Cod50018) |
| K6 | `No. Empleado`, `No. Proyecto`, `Cód. Período`, `Cód. Tipo Liq.` | `LiqExiste`. **No es Unique a propósito**: un choque aparecería como error en medio de un lote de cientos |

Sin SumIndexFields.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No.` (1) | Code[20] | Serie numérica |
| `Cód. Período` (2) | → [[Tabla - Período Liquidación]] | |
| `No. Empleado` (3), `Nombre Empleado` (4) | → `Employee` | OnValidate: nombre, par de la ficha y luego `ResolverParDeAtributos` |
| `No. Proyecto` (5) | → `Job` | Marea (Cierre de Marea / Devengados) |
| `Cód. Convenio` (6), `Cód. Categoría` (7) | → [[Tabla - Convenio Colectivo]] / [[Tabla - Categoría CCT]] | El **encuadre por atributos** (lo que se imprime), recalculado en cada corrida |
| `Cód. Tipo Liq.` (30) | → [[Tabla - Tipo Liquidación]] | Si queda vacío el motor no aplica conceptos y no avisa ([[migracion-tipo-liq-incompleta]]) |
| `Fecha Liquidación` (8) | Date | En Cierre de Marea = arribo |
| `Estado` (9) | Enum | |
| `No. Liq. Origen` (11) | → `Liquidación."No."` | Reliquidaciones |
| `Cobertura Desde/Hasta` (12/13) | Date | Días que cubre realmente (no editables) |
| `Total Haberes`, `Total Descuentos`, `Total Contribuciones`, `Neto a Pagar` (20–23) | Decimal (2:2) | **Almacenados** (no FlowField) para que sean estables tras el cierre y permitan comparar reliquidaciones |
| `Haberes Ordinarios Gravados` (24) | Decimal | Snapshot del acumulador `BASE_IG4` al terminar el cálculo (excluye extraordinarios `BASE_EXT_IG4`); lo consume `MEJOR_REM_SEM` para el SAC |

## Lógica de la tabla
- **`Cobertura(Desde, Hasta)` / `CalcularCobertura()`**: período completo; si el tipo `CubreSoloElProyecto` y hay proyecto, se acota primero a los **días del empleado en ese proyecto** (`RecortarAlTramoDelEmpleado`, recorre todos los tramos de [[Tabla - Estado Empleado]]) y, si no los hay, a `Starting/Ending Date` del Job. Mismo criterio que usa `Gestión Novedades Liq.` para repartir novedades. Ver [[ventana-liquidacion-es-cobertura]], [[cobertura-devengado-tapa-dias]].
- `FechaReferenciaAprox()`: `Fecha Liquidación`, o fin del período, o `WorkDate`. Es aproximación de pantalla; la definitiva la calcula el motor.
- `ResolverParDeAtributos()`: `Convenio Categoría Liq.`.`ParDeEntidad` (`Cod50080`).
- **OnDelete**: sólo en Borrador. Borra detalles de variable (`DeleteAll` directo para evitar un DeleteAll por línea), líneas (`DeleteAll(false)`), [[Tabla - Tramo Cobertura Liq]], el uso de parámetros (`BorrarUsoParametros`), revierte novedades aplicadas (`RevertirLiquidacion`) y, si no queda ninguna liquidación Calculada/Aprobada/Contabilizada, **libera todos los `En Uso`** de [[Tabla - Parámetro Vigente]].

\* tabla 110061, documentada por otro agente.

## Quién la lee / escribe
Crea y calcula: `Cod50014.MotorLiquidacion`, `Cod50018.ProcesoLiqPorLotes`, `Cod50076.LotesLiquidacionLiq`, `Cod50069.EjecutorLiquidacion`. Transiciones: `Cod50019.GestionLiquidacion` (aprobar/reabrir; sincroniza `Estado` en las líneas). Lectores: `Cod50017` (bloqueo de estados), `Cod50051.GestionPrestamos`, `Cod50052.GestionIncidenciaMasiva`, `Cod50053`, `Cod50054`, `Cod50061`, `Cod50074.ArbolLiquidacionesLiq`, `Cod50081.ControlMareaLiq`, `Cod110028/29/30/31/44/54`. Páginas: `Pag50100 Lista Liquidaciones`, `Pag50117 Ficha Liquidación`, `Pag110017 Árbol Liquidaciones`.

## Vigencias
Sin vigencia propia; cada liquidación cubre `[Cobertura Desde, Cobertura Hasta]` y resuelve todo lo efectivo-fechado a su fecha de referencia.

## Trampas conocidas
> [!warning] Una liquidación no Borrador bloquea la configuración
> Cambiar estados de empleado, cerrar vigencias de conceptos usados o tocar parámetros `En Uso` falla mientras exista una liquidación Calculada/Aprobada/Contabilizada que los alcance. Revertir primero.

- Cobertura en tramos (un día se liquida una vez): [[cobertura-en-tramos]], [[cuando-corresponde-una-liquidacion]].
- Tipos de liquidación en blanco al crear por lote: [[lote-tipo-liq-en-blanco]], [[crear-y-calcular-descarta-vacias]].
- Un control agrupado por empleado miente con dos liquidaciones: [[dias-sumados-donde-van-pesos]].
- El grossing-up tapa errores: comparar bruto y base, nunca el neto ([[grossing-up-tapa-errores]]).
- Orden de cálculo del lote: [[orden-calculo-del-lote]].

## Traza del contexto (campo 31, Blob, desde el 24/10/2026)
`Traza Contexto` guarda **una sola vez** lo que el contexto resolvió para toda la liquidación (`GetParamLog()` de `Cod50016`: fuentes `FDS:`, deducciones `DED_FAM:`, variables que leyeron las de sistema). Lo escribe `FaseCerrar` del motor antes del `Modify`; se lee con `LeerTrazaContexto()` y se ve desde la acción "Traza del contexto" de la ficha. Antes iba delante de `Fuente Parámetros` en cada línea (ver [[Tabla - Línea Liquidación]]). Las liquidaciones calculadas antes no la tienen.
