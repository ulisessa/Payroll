---
tipo: concepto
tags: [motor, transacciones, errores, registro-de-procesos]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50069.EjecutorLiquidacion.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Codeunits/Cod110031.RecalculoEnCadenaLiq.al]
actualizado: 2026-10-04
---

# Transaccionalidad y errores del cálculo

**Cada liquidación se calcula en su propia transacción**, de modo que 199 correctas no se pierden por una
que falla. La mecánica no es obvia y tiene restricciones de la plataforma.

## `LiquidarConRegistro` + `Ejecutor Liquidación`

```
Registro.Iniciar(Cálculo, Liq)
Commit()                              ← obligatorio
if Ejecutor.Run(Liq) then
    Registro.Finalizar();  Liq.Get(No.)        ← relee: ve lo realmente guardado
else
    Registro.FinalizarConError(GetLastErrorText());  Liq.Get(No.)
```

- **Por qué `Codeunit.Run` y no `[TryFunction]`**: un `TryFunction` **no puede escribir en la base** ("Una llamada a la función 'MODIFY' no se permite…") y liquidar es todo escritura. `Codeunit.Run` abre su **propio ámbito de transacción**: si falla, la plataforma **revierte lo que hizo el ejecutor** y devuelve `false` al llamador, que sigue vivo para escribir el registro del error y confirmarlo aparte. `Ejecutor Liquidación` (Cod50069, `TableNo = "Liquidación"`, `OnRun` → `Motor.LiquidarRecord(Rec)`) existe sólo para eso.
- **El `Commit()` previo no es opcional**: la plataforma sólo permite *usar el valor de retorno* de `Codeunit.Run` si la transacción **no tiene escrituras pendientes**. En un lote la liquidación anterior siempre dejó escrituras; sin el `Commit` falla de la segunda en adelante. Efecto buscado: cada liquidación en su transacción. Ver [[codeunit-run-necesita-commit]].
- **El ejecutor trabaja sobre su propia instancia del registro**: se **relee** (`Liq.Get`) para que el llamador vea estado y totales guardados; tras un fallo, para descartar valores de un cálculo revertido.
- El `Rec` que devuelve `Run` **no tiene los filtros** del llamador (por eso los lotes recorren una lista de números y no el registro filtrado). Ver [[Procesos por lotes y progreso]].
- Una liquidación fallida **no se aborta en el lote**: queda anotada en el registro y el proceso sigue. El llamador **tiene que mirar el resultado** (`LiquidarConRegistro` devuelve `Boolean`).

## Registro de procesos (`Registro Procesos Liq.`)

`Registro Procesos Liq.` (Cod50068): `Iniciar(tipo, Liq)` / `IniciarProceso(tipo, período)`, `Finalizar`, `FinalizarConError(texto)`, `Info`, `InfoImporte`, `Advertir`, `AdvertirVariable(categoría, mensaje, variable, concepto)`, `RegistrarError`, `AgregarTexto`, y la **sesión** (`IniciarSesion` devuelve un `Guid`, `CerrarSesion`, `MostrarAvisosDeLaSesion`) que agrupa los registros de una corrida. Cada entrada tiene **severidad** (`Información`, `Advertencia`, `Error`) y **categoría** (`General`, `Fórmula`, `Parámetro`, `Orden Cálculo`, `Novedad`, `Incidencia`, `Préstamo`, `Estado Empleado`, `Franco`, `Grossing Up`, `Estado`), con variable y concepto en columnas filtrables. Lo escriben el motor, `Gestión Liquidación` (Aprobación, Reapertura, Reversión Aprobación) y los lotes. El informe `Avisos del Cálculo` (Rep50047) lo muestra. Ver [[Avisos y advertencias del cálculo]].

> [!warning] "Falló y no hay cabecera" ya no pasa, pero cuidar el barrido
> Una liquidación que falla **no tiene líneas**: `EstaVacia` dice que sí. `BarrerVacias` la borraba y
> el único rastro quedaba en el registro (se perdieron de vista 14 cierres de marea de enero de 2026).
> Hoy `FFallidas` la protege del barrido. Si se crea otro proceso que borre "vacías", respetar esa regla.

## Dónde corta el motor con `Error`

Todo `Error` dentro de `LiquidarRecord` aborta **la liquidación entera** (y la revierte). Casos principales:

| Error | Dónde |
|---|---|
| Contabilizada / período cerrado | inicio |
| Orden cronológico | `ValidarOrdenCronologico` |
| Sin estado a `FechaRef` / sin asignación | `ValidarEstadoExiste`, `ValidarAsignacionProyecto` |
| Fórmulas inválidas (lista de conceptos) | fase 1 |
| `Error al calcular el concepto X: …` | fase 2, concepto, condición o variable cantidad de un concepto |
| Consumo de francos mayor al saldo | `GenerarLineasConsumoFranco` |
| `NETO_GARANTIZADO` autorreferente / sin cotización / no converge | grossing-up |
| Referencia circular, variable desconocida, función desconocida, tabla/tramo inexistente | evaluador |

**Las incoherencias de datos que el motor tolera** (por diseño, con aviso o sin él): parámetro sin valor (0), variable de sistema con `Cód. Cálculo` desconocido (0 + aviso), fuente sin filtros (aviso), `@` sobre concepto inexistente en modo tolerante (0), fracción hacia un acumulador inexistente (descartada **sin aviso**). Ver [[Acumuladores y fracciones]].

## Excepción deliberada: la cadena

El [[Recálculo en cadena]] **no** usa `Codeunit.Run` por período: corre todo en una transacción, de modo que un fallo revierte la cadena completa.

## Patrones de AL que se ven acá

- **No cortocircuita**: `ContainsKey` y `Get` en sentencias separadas ([[al-sin-cortocircuito]]).
- **Borrar mientras se recorre**: juntar claves primero ([[bucle-modifica-campo-filtrado]]).
- **`CLEAR` no vacía un `Record TEMPORARY`** (sólo limpia campos y filtros): usar `DeleteAll` ([[clear-no-vacia-temporary]]). El motor lo hace con `FIncidencias.Reset(); DeleteAll(false)`.
- **SQL directo deja la caché rancia**: un `UPDATE` por fuera no invalida el service tier ([[sql-directo-deja-cache-rancia]]).

## Relacionado

[[Ciclo de cálculo de una liquidación]] · [[Visión general de la arquitectura]] · [[Estados y transiciones de una liquidación]]

**Tablas relacionadas:** [[Tabla - Registro Proceso Liq]] · [[Tabla - Entrada Registro Liq]]
