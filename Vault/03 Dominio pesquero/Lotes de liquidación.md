---
tipo: proceso
tags: [dominio, lotes, creacion, calculo, orden]
fuente: [src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Codeunits/Cod50076.LotesLiquidacionLiq.al, src/Pages/Pag50155.LanzadorLiquidaciones.al, src/Tables/Tab60011.Liquidacion.al, src/TableExtensions/TabExt52001.HRSetupLiqExt.al]
actualizado: 2026-10-04
---

# Lotes de liquidación

Dos codeunits distintos, con dos responsabilidades:

| Codeunit | Objeto | Qué hace |
|---|---|---|
| `Cod50018.ProcesoLiqPorLotes.al` | codeunit **50050** `Proceso Liq. Por Lote` | **Crear** liquidaciones (por proyecto, por período, por empleado, por asignación, cierre de marea) y **calcular** un período. |
| `Cod50076.LotesLiquidacionLiq.al` | codeunit 50076 `Lotes Liquidación Liq.` | Operar un **alcance** ya existente: calcular, reabrir, aprobar, eliminar. |

> [!note] Archivo ≠ ID
> El archivo `Cod50018` contiene el objeto 50050. Al buscar por ID, buscar el nombre del objeto.

## Crear (Cod50050)

| Procedimiento | Entrada | Notas |
|---|---|---|
| `CrearPorPeriodo(período, tipo)` | Lanzador | **Tipo en blanco = todos los tipos `Activo` y `Entra en Corrida Completa`, en su `Orden`** (nunca se inserta un tipo vacío: salían cientos de liquidaciones sin `Cód. Tipo Liq.` que el motor dejaba vacías sin avisar). |
| `CrearPorProyecto(Job, período, tipo)` | Ficha del proyecto | Las guardas de [[Cuándo corresponde una liquidación]]. |
| `CrearCierreMarea(Job)` | Ficha del proyecto | Exige `Ending Date`; deriva el período de esa fecha (error si no existe el período). Usa `CodigoArribo()` (ver advertencia en [[Tipos de liquidación]]). |
| `CrearParaEmpleado(emp, período, tipo)` | Reportes por empleado | Gemelo de `CrearPorProyecto` por empleado; **las omisiones no cortan** (se corre sobre un filtro de empleados). |
| `CrearParaAsignacion(Personal Proyecto, …)` | Alta de a una | **Corta con error** (no omite en silencio): exige fase en el período y que la asignación haya empezado al cierre del período. |
| `CrearYCalcularPorPeriodo` | Lanzador | Crea, calcula y descarta vacías de a una (ver abajo). |

Invariantes de la creación:
- **Período cerrado ⇒ error** al empezar.
- **No duplica**: `LiqExiste` (empleado + proyecto + período + tipo) o, para tipos agrupados, `LiqExisteEmpleado` (sin mirar proyecto). Crear es idempotente.
- **Cabecera**: `No.` de la serie `HR Setup."Cód. Serie Liq."` (si falta: error "Serie Núm. Liquidaciones"); `Fecha Liquidación` = fin del período, o el **arribo** si el tipo es de arribo; `Estado = Borrador`; el par convenio/categoría sale de los atributos (`ResolverParDeAtributos`), con la ficha como respaldo.
- **Proyecto de una liquidación agrupada** (`ProyectoNominaDe`): se recorre el historial **hacia atrás** buscando el último estado **no marea con proyecto** *dentro del período*; si no hay, el último embarque y de ahí el atributo `PROY_NOMINA` del **buque**; y para quien nunca embarcó, el mismo atributo cargado sobre el **empleado**. Sin red hacia Configuración de RR.HH.: poner el proyecto genérico a todo el personal de tierra sería inventar un dato. En blanco no es inofensivo: `{BUQUE}` resuelve vacío y toda fuente del buque (la veda) devuelve cero. Ver [[proyecto-nomina-dos-fuentes]], [[novedad-proyecto-sale-del-estado]].

### Crear y calcular, de a una
`CrearYCalcularPorPeriodo` usa la bandera `FCalcYDesc`: crea una liquidación, la calcula y, si no tiene **ninguna línea con importe** (las informativas y las de cantidad no cuentan), la **reabre y borra**. El número de serie se **espía** (`PeekNextNo`) y sólo se consume (`ConsumirLiqNo`) si sobrevive, así las descartadas no dejan huecos. Es seguro porque el lote es secuencial: si se paraleliza, hay que volver a consumir siempre. Ver [[crear-y-calcular-descarta-vacias]].

- **Una que falla no se descarta** (no se sabe si está vacía porque no corresponde o porque se rompió) y queda en `FFallidas`, **fuera de la barrida**. Así se perdieron de vista 14 cierres de marea de enero de 2026.
- **`BarrerVacias`** converge la corrida: borra las vacías del alcance (el del tipo elegido o el de los tipos que entran en la corrida) y **cuenta aparte** (`Sobrantes`) las que tienen importe pero que las guardas de hoy ya no crearían (`SeguiriaCreandose`); esas no se tocan (pueden ser manuales; borrar plata en silencio porque cambió un parámetro es lo que no hay que hacer).
- `FProgreso`/`Progreso Liq.` es `SingleInstance`: un lote detenido deja contadores viejos ([[progreso-singleinstance-sucio]]).

## Calcular un período (`CalcularPorPeriodo`)

Junta primero los números de las liquidaciones en **Borrador** por tipo (en `Orden`) y recién después calcula, con **una sola** lista, barra de progreso y sesión de registro (`Registro Procesos Liq.`) para toda la corrida. Se juntan las claves **antes** de calcular: `LiquidarConRegistro` usa `Codeunit.Run`, que devuelve el registro sin filtros, y el recorrido directo se escapaba a otros períodos ([[bucle-modifica-campo-filtrado]]). Una que falla queda anotada y el lote sigue.

> [!warning] Sólo Borrador
> Tanto `CalcularPorPeriodo` como `Lotes Liquidación Liq.Calcular` calculan **únicamente liquidaciones en Borrador**; las Calculadas o Aprobadas se omiten y se informan. La ayuda de la acción *Calcular Todo* del lanzador ("Borrador o Calculada") y el resumen del codeunit 50076 ("Borrador, Calculada o Aprobada") **no coinciden con el código**. Para recalcular hay que **Reabrir**.

## Operar un alcance (Cod50076)

Cada procedimiento recibe un `Record "Liquidación"` **ya filtrado** y no le toca los filtros (con `SetSelectionFilter` la plataforma puede copiar los de la página y volver a filtrar un campo ya filtrado lo **reemplaza**: el alcance se ensancharía). Siempre juntan las claves antes de escribir.

| Acción | Efecto |
|---|---|
| `Calcular` | **En orden de cálculo**: por empleado, dentro por período, dentro por `Orden` del tipo (clave de texto con `Orden + 10000` rellenado; `List` de AL no tiene `Sort`, se ordena por inserción). El orden **cambia importes**: tope SIPA del SAC (se agota en el mes), Ganancias (resta lo retenido en las anteriores) y consumo FIFO de francos. Una liquidación sin tipo queda con Orden 0, o sea primera. Ver [[orden-calculo-del-lote]], [[tope-sac-por-liquidacion]]. |
| `Reabrir` | Sólo Calculada. Las que tienen **posteriores** se saltean y se informan (reabrirlas liberaría novedades y cuotas que la posterior volvería a tomar); para esas está *Recalcular en cadena*. |
| `Aprobar` | Sólo Calculada; las demás se omiten. |
| `Eliminar` | Sólo Borrador; pide confirmación con el tamaño del alcance. El `OnDelete` de `Liquidación` borra líneas, detalles, **tramos de cobertura**, usos de parámetros y revierte novedades. |

## Interfaz

El *Lanzador de Liquidaciones* (50155) elige período y tipo; *Crear Liquidaciones* invoca `CrearPorPeriodo` + `AvisarOmitidos`, *Calcular Todo* invoca `CalcularPorPeriodo`. El árbol de liquidaciones usa `Lotes Liquidación Liq.` para operar sobre el nodo en que uno está parado.

Relacionado: [[Tipos de liquidación]], [[Cobertura y tramos]], [[lote-tipo-liq-en-blanco]], [[codeunit-run-necesita-commit]], [[Vision del dominio pesquero]].
