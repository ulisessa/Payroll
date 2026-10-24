---
tipo: proceso
tags: [motor, lotes, progreso, creacion-liquidaciones]
fuente: [src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Codeunits/Cod50076.LotesLiquidacionLiq.al, src/Codeunits/Cod110032.ProgresoLiq.al, src/Codeunits/Cod50069.EjecutorLiquidacion.al]
actualizado: 2026-10-04
---

# Procesos por lotes y progreso

Dos codeunits distintos hacen "cosas en lote" sobre liquidaciones:

| Codeunit | ID | Qué hace |
|---|---|---|
| `Proceso Liq. Por Lote` | **50050** (archivo `Cod50018`) | **Crear** liquidaciones (por proyecto, por empleado, por período, cierre de marea) y **crear+calcular** en una pasada; **calcular** un período |
| `Lotes Liquidación Liq.` | 50076 | Operar sobre un **alcance ya filtrado** (selección de la lista o nodo del árbol): **Calcular**, **Reabrir**, **Aprobar**, **Eliminar** |

Los llama el *Lanzador de Liquidaciones* (Pag50155), la lista y la ficha de períodos, la ficha del proyecto y *Personal Proyecto*, el reporte *Crear Liq. Para Empleado* (50043) y el Árbol de Liquidaciones. Cada liquidación se calcula con `Motor.LiquidarConRegistro` ([[Transaccionalidad y errores del cálculo]]).

## Crear: las guardas, de la más barata a la más cara

`CrearPorProyecto(Job, período, tipo)`:

1. Período no `Cerrado`.
2. **Calendario del tipo**: `TipoLiqRec.CorreEnElMes(tipo, Fecha Hasta)`; el aguinaldo no mira a nadie en marzo.
3. Alcance de personas (`AplicarFiltroPersonal`): para tipos de **arribo**, asignaciones con `Fecha Baja` vacía o `>=` el zarpe; para el resto, asignaciones que **estuvieron vigentes en algún momento del período** (baja vacía o `>=` inicio del período, alta `<=` fin del período). El criterio es *"estuvo asignado durante lo que se liquida"*, no *"sigue asignado hoy"*: desde que cargar la fecha de arribo cierra las asignaciones, pedir la abierta dejaba "Crear Devengados" devolviendo 0.
4. Por cada asignación, en este orden (cada una incrementa su propio contador de omitidos, que se avisan al final con `AvisarOmitidos`):
   1. `TipoAplicaAlEmpleado`: el `Aplica a` del **tipo** vs el `Tipo Empleado` del convenio (vacaciones no se emiten a mensualizados).
   2. `EstuvoEnLaEmpresa`: alguna **fase de alta** cubre el período (`Fase Alta Empleado`.`EstuvoActivoEntre`). Hace falta porque `Personal Proyecto` tiene **una fila por par empleado+proyecto** y esa fila puede atravesar meses de baja (46 empleados en enero de 2026).
   3. Si el tipo es **de baja** (`EsBajaEmpleado`): `SeDioDeBajaEnElPeriodo` (`Termination Date` dentro del período).
   4. `EstadosJustifican`: ver más abajo.
5. `CrearSiFalta`: si el tipo **"Agrupa por Empleado"** una sola liquidación por empleado+período+tipo, sin importar el proyecto (`InsertarLiquidacionEmpleado`, el proyecto lo resuelve `ProyectoNominaDe` desde el estado); si no, una por empleado+proyecto+período+tipo. **Idempotente**: si existe, no hace nada.

`AplicarFiltroJobs`: la **clase de proyecto la declara el tipo** (`Tipo Proyecto`: 0 todos, 1 productivo, 2 improductivo), no quien corre el proceso. Para arribo, proyectos con `Ending Date` en el período; para el resto, `Starting Date <= Fecha Hasta` (en blanco **pasa**: los proyectos de nómina no tienen), y si el disparador es `MareaEnCurso`, además `Ending Date` vacío o posterior al cierre. **El `Status` del proyecto no se usa** (no se mantiene; estaba mal en las dos direcciones en enero de 2026).

### `EstadosJustifican` (`Estado Tipo Liq.`)

El tipo puede declarar líneas con `Modo` **Exige** o **Excluye**, con un filtro de `Cód. Estado` (admite `BAJ*`, `NV|PL|PS`), `Ventana` (`Cobertura`, `Periodo`, `MesSiguiente`), `Empieza en la Ventana` y `Tipo Proyecto`. Regla: **se crea si algún estado justifica y no está excluido**; las "Exige" se combinan con **O** (vacaciones: este mes **o** el que viene). Se decide **por estado**, no por empleado: una exclusión que apareciera en cualquier punto del período dejaba sin Regular a quien navegó parte del mes (99 empleados y 307 días en enero de 2026). Sin líneas, el tipo no tiene condición de estados y pasa. Ver [[cuando-corresponde-una-liquidacion]].

### Sin proyecto: `CrearSinProyecto`

Sólo para tipos "Agrupa por Empleado": empleados con estados en el período pero **sin asignación a proyecto** (nueve de tierra en enero de 2026 a los que Meta4 les pagó y BC no les creaba nada). Mismas guardas, mismo orden; `FIntentados` evita reevaluar a quien ya vio el recorrido por proyecto. El cierre de marea **no** lo hace: es *de* la marea.

## Sin tipo = los que entran en la corrida completa

`CrearPorPeriodo` y `CalcularPorPeriodo` con tipo en blanco corren **todos los tipos activos con `Entra en Corrida Completa`**, ordenados por `Orden` (el cierre de marea antes que la mensual que lo acumula). **No alcanza con `Activo`**: cuando "blanco" significó "todos los activos", enero de 2026 terminó con 3.604 liquidaciones donde iban ~520 (los 185 conceptos sin tipos declarados aplican a todos). Ver [[lote-tipo-liq-en-blanco]] y [[vacio-en-tipos-liq-aplicables-es-comodin]].

## Crear y calcular de a una (`CrearYCalcularPorPeriodo`)

Crea → calcula → decide, **una por una**, para no dejar cientos de vacías (`SALDO_INICIAL`, `LIQ_FINAL`, `AGUINALDO`) que además ya se llevaron su número:

- **Vacía = ninguna línea con importe `<> 0`** (las informativas y de cantidad no cuentan). Se descarta **reabriéndola y borrándola** (`Gestión Liquidación.Reabrir` + `Delete(true)`), nunca con `Delete(false)` (dejaría líneas huérfanas).
- El **número se espía** (`NextLiqNo` usa `PeekNextNo`) y sólo se consume (`ConsumirLiqNo`) si sobrevive: no deja huecos. Vale porque el lote es secuencial.
- **Una que falla no se descarta** (`FFallidas`): no se sabe si está vacía por no corresponder o por romperse.
- **`BarrerVacias`** al final, con el alcance de la corrida: borra las **vacías** que ya no se crearían y **cuenta** (no toca) las que tienen importe y que las guardas de hoy ya no crearían (`Sobrantes`): borrar plata en silencio porque cambió un parámetro es lo que no hay que hacer. Es lo que hace que la corrida **converja** (el resultado depende de los datos y no de la historia de corridas).

Ver [[crear-y-calcular-descarta-vacias]].

## Calcular un alcance

### Por período (`CalcularPorPeriodo`)

Junta los números de las liquidaciones en **Borrador** de cada tipo, **tipo por tipo en una sola lista** (para una sola barra de progreso y una sola sesión de registro y para que el cierre de marea corra antes que la mensual), y calcula cada una con `LiquidarConRegistro`.

### Por selección (`Lotes Liquidación Liq.`.`Calcular`)

- **Orden de cálculo**: `RecolectarNumerosEnOrdenDeCalculo` ordena por **empleado + período + `Orden` del tipo de liquidación + `No.`**. Ese orden decide importes: el tope de SIPA del SAC, Ganancias (`YTD_RETENIDO_ANUAL`) y los francos FIFO leen lo ya liquidado. La clave es un texto con `Format(10000 + Orden)` porque el `Orden` no es un campo de `Liquidación` y no se puede pedir a la base. Ver [[orden-calculo-del-lote]].
- **Sólo `Borrador`**: las `Calculada`/`Aprobada` se **omiten** y se informan (el comentario `summary` del procedimiento dice "Borrador, Calculada o Aprobada", pero el cuerpo sólo calcula Borrador). Rehacer una = reabrirla.
- **Reabrir**: saltea las que tienen posteriores (`PuedeReabrir`) y las cuenta. **Aprobar**: sólo `Calculada`. **Eliminar**: sólo `Borrador`, con confirmación que lleva el tamaño del alcance.
- **Las claves se juntan antes** de tocar nada y se recorre la **lista**, no el registro: (1) borrar/modificar el campo filtrado mientras se recorre corta el bucle en el primero ([[bucle-modifica-campo-filtrado]]); (2) `Codeunit.Run` con un registro como parámetro **devuelve el registro sin filtros**, y el `Next` seguía por liquidaciones de otros períodos. No se vuelve a filtrar el campo que la página ya filtraba: `SetFilter` **reemplaza** el filtro de la selección y la ensancharía ([[copyfilters-solo-grupo-actual]]).
- **Una sesión de registro por corrida** (`Registro.IniciarSesion`/`CerrarSesion`): desde cualquier registro se ve el lote completo, y `MostrarAvisosDeLaSesion` abre un informe con todos los avisos (los del cálculo van al informe; si no salió, se repiten en el cartel final). Ver [[Avisos y advertencias del cálculo]].

## Ventana de progreso (`Progreso Liq.`, Cod110032)

**SingleInstance**: el lote abre la ventana, pero quien tarda es el motor, y entre los dos hay un `Codeunit.Run` por el que no se puede pasar un `Dialog`. Con la ventana en un SingleInstance, el motor la actualiza desde adentro (`Progreso.Paso`).

| Procedimiento | Qué hace |
|---|---|
| `AbrirLote(Total)` | arranca un lote **de afuera**: reinicia nivel, handle y contadores (descarta lo que dejó un lote detenido) y llama `Abrir` |
| `Abrir(Total)` | anidable: `FNivel += 1`; si ya hay ventana, sale. El reloj arranca (`FInicio`) **aunque no haya GUI** (un Job Queue igual tiene que poder decir cuánto tardó) |
| `Registro(NoLiq, Nombre)` | empieza una liquidación: pinta número, empleado y "Procesando N de M" |
| `Paso(texto)` | lo llama el motor ("Calculando conceptos…", "Grossing Up: iteración 3 de 20…", "pasada final con auditoría") y refresca el tiempo |
| `FinalizarRegistro()` | avanza `FProcesadas` y el porcentaje (redondeado **hacia abajo**: no muestra 100 % antes del último) |
| `Cerrar()` | decrementa el nivel; al llegar a 0 **congela la duración** (`FDuracionTotal`) y cierra la ventana |
| `TranscurridoTexto()` | `hh:mm:ss` sin milisegundos; se usa en el mensaje final cuando la ventana ya no existe |

Muestra el **promedio por liquidación** (un hecho), no un tiempo restante estimado: las de grossing-up tardan casi un orden de magnitud más y la proyección se movería sola. Con total desconocido (`FTotal = 0`, como abre *Crear y Calcular*) muestra el conteo sin porcentaje.

> [!warning] Estado sucio en un SingleInstance
> Si un lote se detiene (corte del usuario o error escapado), `Cerrar` no corre y quedan `FAbierta`, `FNivel` y los contadores viejos: el lote siguiente pintaba "519 de 519, 100 %" con un reloj de 36 minutos. Por eso existe `AbrirLote`, que **declara** que es el de afuera. Ver [[progreso-singleinstance-sucio]]. Todo es inofensivo si nadie abrió la ventana (background, job queue).

## Relacionado

[[Ciclo de cálculo de una liquidación]] · [[Recálculo en cadena]] · [[Estados y transiciones de una liquidación]] · [[Tabla - Liquidación]]

**Tablas relacionadas:** [[Tabla - Estado Tipo Liq]] · [[Tabla - Tipo Liquidación]] · [[Tabla - Fase Alta Empleado]] · [[Tabla - Personal Proyecto]] · [[Tabla - Período Liquidación]]

## Reapertura con consumos dentro del alcance

Lotes Liquidación Liq.Reabrir conserva las claves seleccionadas y delega el orden en
Gestión Liquidación.ReabrirSeleccion, compartido con Revertir Calculadas del período.
Los consumidores se retiran antes de sus devengos. Las dependencias fuera del alcance
se cuentan como bloqueadas, sin ampliar la selección ni abortar por un origen interno.
Ver [[reapertura-periodo-dependencias-francos]].

