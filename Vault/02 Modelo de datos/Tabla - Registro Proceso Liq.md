---
tipo: tabla
tags: [modelo-de-datos, auditoria, bitacora]
fuente: [src/Tables/Tab110000.RegistroProcesoLiq.al, src/Codeunits/Cod50068.RegistroProcesosLiq.al, src/Pages/Pag110000.RegistrosProcesoLiq.al]
actualizado: 2026-10-04
---

# Tabla - Registro Proceso Liq

**Tabla 110000 `Registro Proceso Liq.`** (caption *Registro de Proceso*). **Datos persistentes.**

**Propósito.** Bitácora de operaciones sobre liquidaciones: una fila por operación (calcular, aprobar, reabrir, revertir aprobación, eliminar, crear, importar novedades; enum `Tipo Proceso Liq.`). Antes una advertencia vivía en un `Text` en memoria que se perdía al cerrar el mensaje, y un cálculo que fallaba no dejaba rastro. Las filas hijas están en [[Tabla - Entrada Registro Liq]].

## Clave primaria
`"No. Registro"` (Integer, `AutoIncrement`). Claves secundarias: `("No. Liquidación","Fecha Hora Inicio")`, `("No. Sesión")`, `(Resultado,"Fecha Hora Inicio")`, `("Cód. Período","Fecha Hora Inicio")`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Sesión` | Guid | Agrupa todos los registros de una corrida por lote, para ver de un saque cómo salió un proceso de 200 empleados. |
| `Tipo Proceso` | Enum `Tipo Proceso Liq.` | Cálculo, Aprobación, Reapertura, Reversión Aprobación, Eliminación, Creación, Importación Novedades. |
| `No. Liquidación`, `No. Empleado`, `Nombre Empleado`, `Cód. Período`, `Cód. Tipo Liq.` | varios | Contexto de la operación (relaciones a [[Tabla - Liquidación]], `Employee`, [[Tabla - Período Liquidación]], [[Tabla - Tipo Liquidación]]). |
| `Fecha Hora Inicio/Fin`, `Duración (ms)`, `Usuario` | DateTime/Integer/Code | Cuándo, cuánto y quién. `Usuario` es `EndUserIdentifiableInformation`. |
| `Resultado` | Enum `Severidad Registro Liq.` | Severidad máxima de las entradas (Información = salió limpio). |
| `Cant. Errores`, `Cant. Advertencias`, `Mensaje` | Integer/Text[250] | `Mensaje` = primer error, o primera advertencia si no hubo errores. |
| `Cant. Entradas` | FlowField Count | Cuenta [[Tabla - Entrada Registro Liq]]. |

## Lógica en triggers
- `OnDelete`: borra las entradas hijas. Por eso la depuración de la página (*Depurar registros antiguos*) usa `DeleteAll(true)`: sin `true` las entradas quedarían huérfanas.
- `MostrarEntradas()` abre la página de entradas filtrada.

## Quién la lee y la escribe
- **Escribe:** únicamente `Cod50068 Registro Procesos Liq.` (`SingleInstance`), en `Escribir()` al cerrar el proceso con `Finalizar()` / `FinalizarConError()`. Quienes abren procesos: el motor (`Cod50014`), la gestión de liquidaciones y los lotes.
- **Lee:** páginas `Registros Proceso Liq.` (110000), `Ficha Registro Proceso Liq.` (110003), `Ficha Liquidación` (50117) y el reporte `Avisos del Cálculo` (50047).

## Trampas
> [!warning] Las entradas se bufferean en memoria
> Si el cálculo falla, la plataforma revierte *toda* la transacción, incluido el registro que justamente hay que conservar. Por eso `Cod50068` junta las entradas en un `Record "Entrada Registro Liq." temporary` y las escribe recién al cerrar. Un proceso que termina con un error no controlado **no escribe nada**: el siguiente `Iniciar` detecta el proceso abierto y descarta lo anterior con el aviso "el proceso anterior quedó sin cerrar".
> Anotar sin proceso abierto se descarta en silencio (hay herramientas de diagnóstico que llaman caminos de cálculo).

> [!note] Depuración manual
> No hay depuración automática: la acción *Depurar registros antiguos* de la página 110000 borra por fecha de corte, previa confirmación.

## Relacionado
[[Tabla - Entrada Registro Liq]] · [[progreso-singleinstance-sucio]] · [[Índice Modelo de datos (110xxx)]]
