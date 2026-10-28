---
tipo: tabla
tags: [modelo-datos, extension, configuracion]
fuente: [src/TableExtensions/TabExt52001.HRSetupLiqExt.al]
actualizado: 2026-10-04
---

# Extensión - Human Resources Setup (TabExt52001 "HR Setup Liq. Ext.")

Extiende `Human Resources Setup` (la **"Config. Recursos Humanos"** de BC) con los punteros de configuración global del módulo. Hay una segunda extensión de la misma tabla para SIRADIG: [[Extensión - Human Resources Setup SIRADIG]].

| Campo | ID | Tipo / relación | Propósito |
|---|---|---|---|
| `Cód. Serie Liq.` | 52010 | → `No. Series` | Serie de numeración de liquidaciones ([[Tabla - Liquidación]]) |
| `Cód. Serie Préstamos` | 52011 | → `No. Series` | Serie de [[Tabla - Préstamo Empleado]] (OnInsert hace `TestField`) |
| `Proyecto Nómina` | 52012 | → `Job."No."` | **Proyecto de inactividad de respaldo**: donde se estaciona al empleado cuando su marea no define `Proyecto Inactividad Nómina` ([[Extensión - Job]]). Lo lee `Cod50017.ResolverProyectoInactividad` |
| `Cód. Estado Alta Sinc.` | 52013 | → [[Tabla - Cód. Estado Empleado]] (donde `Tipo Estado = Alta`) | Código con que se abre la fase de alta de un empleado que llega de NAV. En blanco: busca el **único** código activo Tipo Alta; si hay más de uno no adivina y marca las altas en Error |
| `Máx. Intentos Sinc.` | 52014 | Integer (InitValue 5) | Cuántas corridas espera una fila que depende de otra ausente (p. ej. línea de descarga sin proyecto) antes de pasar a Error |
| `Cód. Concepto Neto Garantizado` | 52015 | → [[Tabla - Concepto Liquidación]] | Concepto que calcula el **neto objetivo del grossing-up**. **En blanco, el grossing-up no se aplica en ninguna liquidación** |
| `Cód. Acum. Haberes Gravados` | 52016 | → Concepto (`Es Acumulador`) | Acumulador del que sale `Haberes Ordinarios Gravados` de la liquidación. En blanco: el campo queda en cero sin avisar. El nombre del campo está abreviado a ≤30 caracteres a propósito (AL0468); **no restaurar el nombre largo** |

## Protecciones
[[Tabla - Concepto Liquidación]] **bloquea el borrado** del concepto que sea `Cód. Concepto Neto Garantizado` o `Cód. Acum. Haberes Gravados`: sin él, el grossing-up deja de aplicarse o `Haberes Ordinarios Gravados` queda en cero, ambos sin avisar.

## Dónde se lee
`Cod50014.MotorLiquidacion` (grossing-up, snapshot de gravados), `Cod50017`, `Cod50018` (proyecto de nómina), `Cod110036.SincNAVLiq` (alta y reintentos), `Cod50019.GestionLiquidacion`. Página: `PagExt50353 HRSetupLiqExt`.

## Trampas
- Grossing-up: [[grossing-up-tapa-errores]], [[oficiales-netos-al-70]].
- Proyecto de nómina vs. proyecto de inactividad por marea: [[proyecto-nomina-dos-fuentes]], [[puente-mayor-no-es-la-planta]].
- Sincronización NAV: [[transporte-ws-sincronizacion]].
