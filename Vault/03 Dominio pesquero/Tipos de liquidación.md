---
tipo: concepto
tags: [dominio, tipos-liquidacion, disparador, orden]
fuente: [src/Tables/Tab50578.TipoLiquidacion.al, src/Tables/Tab110059.EstadoTipoLiq.al, src/Codeunits/Cod50055.GestionTipoLiq.al, src/Codeunits/Cod50056.TipoLiqInstall.al, src/Codeunits/Cod50057.TipoLiqUpgrade.al, src/Enums/Enum50331.DisparadorTipoLiq.al, src/Enums/Enum50332.ModoEstadoTipoLiq.al, src/Enums/Enum50333.VentanaEstadoTipoLiq.al, src/Enums/Enum50307.AplicaTipoLiq.al, src/Codeunits/Cod50014.MotorLiquidacion.al, src/Pages/Pag50195.TiposLiquidacion.al]
actualizado: 2026-10-04
---

# Tipos de liquidación

`Tipo Liquidación` (50578) es el **maestro configurable** que reemplazó al enum fijo: los tipos genéricos son puro dato y no hay código atado a un código de tipo concreto. Los que tienen comportamiento propio lo declaran con campos (disparador, agrupación, tipo de proyecto, estados exigidos…). Se mantiene desde *Tipos de Liquidación* (50195).

## Los tipos que siembra el código

`Gestión Tipo Liq.Sembrar` (Cod50055; lo ejecutan `Tipo Liq. Install` y `Tipo Liq. Upgrade` en cada instalación y upgrade, y la acción *Sembrar y migrar datos*) crea **sólo los que faltan**:

| Código | Descripción | Orden sembrado | Qué declara el sembrador |
|---|---|---|---|
| `REGULAR` | Regular | 10 | `Incluye Francos Puerto`; entra en la corrida; exige un estado del período cuyo **proyecto no sea productivo** (líneas de [[Cuándo corresponde una liquidación]]). |
| `AGUINALDO` | Aguinaldo | 20 | Entra en la corrida con `Meses = 6\|12`. |
| `VACACIONES` | Vacaciones | 30 | Entra en la corrida; `Aplica A = Tripulante`; exige `AU9` que **empiece** en el período. |
| `LIQ_FINAL` | Liquidación Final | 40 | Disparador `BajaEmpleado`; entra en la corrida. |
| `RELIQUIDACION` | Reliquidación | 50 | **No** entra en la corrida: la dispara un cambio posterior al cálculo, no un hecho del empleado. Se crea a mano. |
| `DEVENGADOS` | Devengados | 60 | Entra en la corrida. |
| `CIERRE_MAREA` | Cierre Marea | 70 | `Liquida al Arribo` → disparador `Arribo`; entra en la corrida. |

> [!warning] Los Órdenes reales no son los sembrados
> La lección [[tipo-liq-no-implementada]] y la lógica de reparto de días asumen `CIERRE_MAREA 1`, `HIST_REMUN 5`, `ANTICIPO 10`, `VACACIONES 30`, `LIQ_FINAL 40`, `RELIQUIDACION 50`, `DEVENGADOS 60`, `REGULAR 100`, `AGUINALDO 110` y `SALDO_INICIAL 0`. La base productiva fue ajustada a mano; el sembrador **sólo vale para instalaciones nuevas** y daría un orden que invierte el reclamo de días (Regular antes que Vacaciones). Verificar los Órdenes en la base antes de confiar en este cuadro. `SALDO_INICIAL`, `HIST_REMUN` y `ANTICIPO` **no los crea ningún código**: son datos.

> [!warning] Lo que la siembra no configura
> `Agrupa por Empleado`, `Tipo Proyecto` (Productivo para Cierre y Devengados), `Sólo Conceptos Declarados` (para Vacaciones) y el disparador `MareaEnCurso` de Devengados (sólo se deriva de la bandera obsoleta `Sólo Proyectos en Curso`, que `Sembrar` no marca) **no se siembran**. En una instalación nueva hay que cargarlos a mano o la selección de proyectos y de conceptos sale mal sin avisar.

## Campos y para qué sirve cada uno

| Campo | Lo lee | Efecto |
|---|---|---|
| `Orden` (único) | Cálculo en lote, reparto de días, variable `TIPO_LIQ` | Ver abajo. Su `OnInsert` propone el siguiente libre (+10). |
| `Disparador` (enum 50331) | `EsArribo`, `EsMareaEnCurso`, `EsBajaEmpleado`, `AplicarFiltroJobs` | `Ninguno`, `Arribo`, `MareaEnCurso`, `BajaEmpleado`. **Uno solo**: reemplaza a tres banderas excluyentes. |
| `Meses` | `CorreEnElMes` | Filtro de BC sobre el número de mes (`6\|12`, `1..6`); vacío = todos. Se evalúa con una tabla temporal de una fila para usar la sintaxis de filtros nativa. |
| `Tipo Proyecto` (Todos/Productivo/Improductivo) | `AplicarFiltroJobs`, `CubreSoloElProyecto` | Sobre qué `Job` corre. Productivo ⇒ la cobertura se recorta al tramo del proyecto ([[Cobertura y tramos]]). |
| `Agrupa por Empleado` | `CrearSiFalta`, `CrearSinProyecto` | Una cabecera por empleado y período, **sin proyecto** (la Regular). |
| `Incluye Francos Puerto` | `CodigoFrancosPuerto` | Marca la Regular. |
| `Aplica A` | `TipoAplicaAlEmpleado` | A qué clase de empleado corresponde el **documento** entero. |
| `Entra en Corrida Completa` | `CrearPorPeriodo`, `CalcularPorPeriodo` | Si el tipo corre cuando no se elige tipo. **No es lo mismo que `Activo`**. |
| `Sólo Conceptos Declarados` | `ConceptoAplicaATipoLiq` | Invierte la regla del comodín (ver abajo). |
| `Exige Estados` (FlowField) | — | Existe alguna línea de `Estado Tipo Liq.`. |
| `Liquida al Arribo`, `Sólo Proyectos en Curso` | `ConfigurarDisparadores`, `CodigoArribo` | **Obsoletas (Pending)**: sólo se usan para migrar al disparador. |

> [!danger] `CodigoArribo` todavía lee la bandera obsoleta
> `CrearCierreMarea` obtiene el tipo con `CodigoArribo()`, que busca `Liquida al Arribo = true`; el resto del sistema pregunta `Disparador = Arribo`. Si alguien crea el tipo de cierre sólo con el disparador, el cierre por proyecto falla con "ningún Tipo marcado como Liquida al Arribo". `ConfigurarDisparadores` copia bandera → disparador pero no al revés.

## Orden: cuatro usos

1. **Orden de cálculo del lote**: por empleado, período y `Orden` ([[orden-calculo-del-lote]]); el SAC devengado, el tope SIPA, Ganancias y los francos leen lo ya liquidado.
2. **Quién reclama primero los días** ([[Cobertura y tramos]]): menor `Orden` reclama antes.
3. **Variable `TIPO_LIQ`** del motor: devuelve el `Orden` del tipo de la corrida (0 si la liquidación no tiene tipo; ojo, 0 también es el `Orden` de `SALDO_INICIAL`). Está sembrada como variable de sistema (Cod50077) y resuelta en Cod50016, así que **la lección [[tipo-liq-no-implementada]] está desactualizada**. Ver [[variable-sistema-hay-que-sembrarla]]. La descripción sembrada de la variable dice "CIERRE_MAREA 1", que no coincide con el sembrado de este código.
4. Orden de creación en la corrida sin tipo (`SetCurrentKey(Orden)`): el Cierre antes que la mensual que lo acumula.

## Qué conceptos corren en cada tipo

`ConceptoAplicaATipoLiq` (Cod50014):
- `Concepto."Tipos Liq. Aplicables"` es una lista blanca separada por `|` y **vacío = todos los tipos** ([[vacio-en-tipos-liq-aplicables-es-comodin]]: 185 conceptos no declaran tipo).
- Con `Sólo Conceptos Declarados` marcado en el tipo, corren **únicamente los conceptos que lo nombran** (Vacaciones pasó de 19 conceptos a 5; sin esto, 133 empleados cobraron dos veces el SAC devengado y las cargas).
- Los conceptos **informativos nunca se restringen** por el tipo: alimentan acumuladores y bases que otros leen.
- Convenio: el filtro `Aplica A` del concepto se compara con el tipo de empleado del convenio.

## Exclusividad de vacaciones

Las vacaciones se pagan en **una** liquidación: la de Vacaciones si existe, la Regular si no. No lo decide un tipo sino la Fuente de Datos `HAY_LIQ_VACACIONES` en la condición de los conceptos 3553, 3573 y 4743. El recibo de Vacaciones **sólo para tripulantes**: al mensualizado se le paga el haber y el descuento de días en el mismo recibo mensual. Ver [[exclusividad-vacaciones]], [[vacaciones-tierra-duplica-el-mes]], [[recibo-vacaciones-paga-solo-vacaciones]].

## Siembra e instalación: qué converge y qué no

- `Sembrar` no pisa tipos existentes.
- `ConfigurarDisparadores`: `Disparador` sólo se completa si está en `Ninguno`; las líneas de estado sólo se crean si no existe una igual por (tipo, estado, ventana) y **convergen** (`ExigirEstado` corrige `Empieza en la Ventana`); `RetirarEstado` quita explícitamente la regla vieja `VACACIONES/AU9/MesSiguiente`; `AplicarA` **converge** `VACACIONES → Tripulante`.
- **`EntraEnCorrida` vuelve a encender la bandera** si alguien la apagó a mano en `REGULAR`, `VACACIONES`, `LIQ_FINAL`, `DEVENGADOS`, `CIERRE_MAREA` o `AGUINALDO` (lo contrario de lo que promete el comentario "no pisa lo cargado a mano"). Y como corre en **cada upgrade**, un cambio manual en `Aplica A` de VACACIONES también se revierte.
- `Migrar Datos` convierte los nombres viejos de enum en `Tipos Liq. Aplicables` a códigos.

Una liquidación sin `Cód. Tipo Liq.` (anteriores a la migración) no recibe ningún concepto restringido por tipo y sale vacía sin avisar: [[migracion-tipo-liq-incompleta]], [[lote-tipo-liq-en-blanco]].

Relacionado: [[Cuándo corresponde una liquidación]], [[Lotes de liquidación]], [[Vision del dominio pesquero]].
