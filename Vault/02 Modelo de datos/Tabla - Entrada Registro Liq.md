---
tipo: tabla
tags: [modelo-de-datos, auditoria, bitacora]
fuente: [src/Tables/Tab110001.EntradaRegistroLiq.al, src/Codeunits/Cod50068.RegistroProcesosLiq.al]
actualizado: 2026-10-04
---

# Tabla - Entrada Registro Liq

**Tabla 110001 `Entrada Registro Liq.`** (caption *Entrada de Registro*). **Datos persistentes** (aunque `Cod50068` usa una instancia `temporary` como buffer antes de escribirlas).

**Propósito.** Cada cosa que pasó dentro de una operación: error, advertencia o acción realizada. Hija de [[Tabla - Registro Proceso Liq]].

## Clave primaria
`("No. Registro","No. Línea")`. Secundarias: `("No. Registro",Severidad)` y `("Cód. Concepto")`. `No. Línea` avanza de a 10000 en el buffer (`Agregar`).

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Registro` | Integer | Relación a `Registro Proceso Liq.`. |
| `Severidad` | Enum `Severidad Registro Liq.` | Información / Advertencia / Error. |
| `Categoría` | Enum `Categoría Registro Liq.` | General, Fórmula, Parámetro, Orden de Cálculo, Novedad, Incidencia, Préstamo, Estado Empleado, Francos, Grossing Up, Cambio de Estado. |
| `Mensaje` (250), `Detalle` (2048) | Text | El detalle guarda lo largo: el error del evaluador con su expresión, la lista completa de conceptos afectados. |
| `Cód. Concepto`, `Nombre Variable` | Code | Qué concepto o variable disparó la entrada (relación a [[Tabla - Concepto Liquidación]]). |
| `Fecha Hora`, `Importe` | DateTime/Decimal | `Importe` lo usa `InfoImporte`. |

## Lógica en triggers
Ninguno. Una entrada con `Mensaje = ''` no se anota (`Agregar` sale).

## Quién la lee y la escribe
- **Escribe:** `Cod50068` (`Escribir`), copiando el buffer temporal con el `No. Registro` ya asignado.
- **Lee:** páginas `Entradas Registro Liq.` (110002) y `Entradas Registro Liq. Sub` (110001), reporte `Avisos del Cálculo` (50047).

## Trampas
- Los textos se truncan con `CopyStr` al largo del campo: un `Detalle` de más de 2048 caracteres pierde la cola sin aviso.
- El borrado en cascada lo hace el `OnDelete` del padre; borrar entradas sueltas deja el contador `Cant. Errores/Advertencias` del padre desactualizado (se calcula al escribir, no es FlowField).

## Relacionado
[[Tabla - Registro Proceso Liq]] · [[Índice Modelo de datos (110xxx)]]
