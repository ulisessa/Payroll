---
tipo: proceso
tags: [operacion, lanzador, lotes, tipos-liquidacion]
fuente: [src/Pages/Pag50155.LanzadorLiquidaciones.al, src/Pages/Pag50110.PeriodosLiquidacion.al, src/Pages/Pag50195.TiposLiquidacion.al, src/Tables/Tab50578.TipoLiquidacion.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Codeunits/Cod50055.GestionTipoLiq.al, src/PageExtensions/PagExt50351.JobCardExt.al, src/Codeunits/Cod110032.ProgresoLiq.al]
actualizado: 2026-10-04
---

# Lanzador de liquidaciones y lotes

## Objetivo

Crear y calcular **muchas** liquidaciones de una vez, y entender cuándo el sistema decide que una "corresponde". Hay cuatro puertas de entrada que usan la **misma lógica** (`Proceso Liq. Por Lote`, Cod50018):

| Puerta | Dónde | Alcance | Tipo |
|---|---|---|---|
| **Crear y Calcular Liquidaciones** | *Períodos* | Un período | **Todos** los tipos que entran en la corrida |
| **Crear Liquidaciones** / **Calcular Período** | *Períodos* | Un período | Sólo `REGULAR` (fijo en el código) |
| **Lanzador de Liquidaciones** | Role Center → Nómina | Un período | El tipo que se elija (o todos si se deja en blanco) |
| Acciones del **Job** | Ficha de Proyecto → *Personal* | Una marea | `REGULAR`, `DEVENGADOS` o `CIERRE_MAREA` |

## Lanzador de liquidaciones (Pag50155)

Pantalla de dos campos y dos botones.

| Elemento | Caption | Detalle |
|---|---|---|
| Campo | **Período** | Lookup a *Período Liquidación* |
| Campo | **Tipo Liquidación** | Lookup a *Tipo Liquidación*. **En blanco = todos los tipos con "Entra en la corrida sin tipo"** |
| Info | *Período*, *Último resultado* | Rango de fechas del período y el resultado de la última acción |
| Acción | **Crear Liquidaciones** | Confirma y crea borradores para los empleados que correspondan |
| Acción | **Calcular Todo** | Confirma y calcula las **Borrador** del período y tipo; informa cuántas y el tiempo |

> [!warning] Divergencia con la guía vieja
> `GUIA-LIQUIDACION.md` decía que el Lanzador permite filtrar proyectos "Todos / Productivo / Improductivo". La pantalla **no tiene** ese filtro: ese eje es el campo **Tipo de proyecto** del *Tipo de Liquidación*. Y *Calcular Todo* sólo toma **Borrador** aunque su tooltip diga "Borrador o Calculada".

Si el período no está abierto el proceso falla con "El período %1 está cerrado". Al terminar de crear, avisa lo omitido (ver más abajo).

## Cuándo corresponde una liquidación

Se decide **antes de crearla**, con cuatro preguntas que salen de la configuración del *Tipo de Liquidación* y no del código ([[cuando-corresponde-una-liquidacion]]):

| # | Pregunta | Dónde se configura |
|---|---|---|
| 1 | **Calendario**: ¿el tipo corre este mes? | Campo **Meses en que corre** (filtro de BC: `6|12`, `1..6`; vacío = todos) |
| 2 | **Disparador**: ¿ocurrió el hecho que lo dispara? | Campo **Disparador**: *Ninguno*, *Arribo de marea*, *Marea en curso*, *Baja del empleado* |
| 3 | **Fase de alta**: ¿pertenecía a la empresa ese período? | Fases de Alta del empleado |
| 4 | **Estados**: ¿sus estados justifican el tipo? | Subpágina **Estados que lo justifican** (modo Exige/Excluye, estado, ventana, tipo de proyecto) |

Además filtran: **Aplica a** (clase de empleado: p. ej. Vacaciones sólo a *Tripulante*), **Tipo de proyecto**, **Agrupa por empleado** (una liquidación por empleado y período, sin proyecto — la Regular) e **Incluye Francos en Puerto**.

### Tipos que trae el sistema

Sembrados por `Gestión Tipo Liq.` (idempotente, corre en instalación y upgrade):

| Código | Descripción | Orden | Nota |
|---|---|---|---|
| `REGULAR` | Regular | 10 | Agrupa por empleado; exige un estado del mes cuyo proyecto **no** sea productivo (los días de marea los paga el Cierre) |
| `AGUINALDO` | Aguinaldo | 20 | Meses `6|12` |
| `VACACIONES` | Vacaciones | 30 | Aplica a Tripulante; exige estado `AU9` que *empiece* en el período |
| `LIQ_FINAL` | Liquidación Final | 40 | Disparador *Baja del empleado* |
| `RELIQUIDACION` | Reliquidación | 50 | **No** entra en la corrida: se crea a mano |
| `DEVENGADOS` | Devengados | 60 | Disparador *Marea en curso* (proyectos que al cierre del período todavía no arribaron) |
| `CIERRE_MAREA` | Cierre Marea | 70 | Disparador *Arribo de marea*: fecha de referencia = arribo |

Existen además tipos creados por datos (`SALDO_INICIAL`, `HIST_REMUN`) que no entran en la corrida. El **Orden** debe ser único y es el orden en que corre un lote dentro de cada empleado y período (los valores de la tabla son los sembrados; en una base real pueden haberse cambiado).

> [!danger] "En blanco" no es "todos los activos"
> Dejar el tipo en blanco corre **sólo los tipos con "Entra en la corrida sin tipo" tildado**, no todos los *Activo*. Cuando en blanco significaba "todos los activos", enero de 2026 terminó con 3.604 liquidaciones donde iban ~520 (687 de Aguinaldo, de Liq. Final, de Reliquidación y de Saldo Inicial, **con importes**, porque 185 conceptos no declaran tipo y aplican a todos). Ver [[lote-tipo-liq-en-blanco]] y [[vacio-en-tipos-liq-aplicables-es-comodin]].

## Crear y Calcular Liquidaciones (Períodos)

Va **de a una**: crea → calcula → decide. La que sale **sin ninguna línea con importe** (las informativas y las de cantidad no cuentan) se **borra en el acto** y **no gasta número** de la serie (se "espía" el siguiente número y sólo se consume si sobrevive). Una que **falla** no se descarta (no se sabe si está vacía o rota): queda anotada en su registro.

Es **idempotente** y converge: una segunda corrida no duplica; una barrida final saca las vacías (incluso las de una corrida anterior con otra configuración) y **cuenta pero no borra** las que tienen importe y que la configuración de hoy ya no crearía (pueden ser manuales). El mensaje final dice: *N quedaron calculadas, M se descartaron por vacías, K tienen importe pero hoy no se crearían: revisalas*. → [[crear-y-calcular-descarta-vacias]]

## Desde el Job (una marea)

*Proyecto* → grupo **Personal**:

| Acción | Crea | Período |
|---|---|---|
| **Liquidar Personal (Regular)** | `REGULAR` | Lo elige el usuario (lookup de Períodos) |
| **Crear Devengados** | `DEVENGADOS` | Lo elige el usuario |
| **Crear Cierre Marea** | `CIERRE_MAREA` | **Se deriva de la fecha de arribo**; habilitada sólo si hay *Ending Date*; error "No existe un período … que contenga la fecha de arribo" si falta el período del mes |

## Qué se omite y por qué

Antes de crear cada liquidación se aplican las guardas; al terminar, `AvisarOmitidos` informa cuántas quedaron afuera:

| Aviso | Causa |
|---|---|
| "empleados quedaron afuera porque ese tipo no le corresponde a su clase de empleado" | El *Aplica a* del tipo (p. ej. Vacaciones a mensualizados) |
| "…ninguna de sus fases de alta cubre el período" | Asignación a proyecto abierta tras el desembarco; falta la fase de alta, no la liquidación |
| "…el empleado no se dio de baja dentro del período" | Tipo con disparador *Baja del empleado* |
| "…no tiene NINGÚN estado en los días que esa liquidación iba a cubrir" | Casi siempre una asignación que quedó abierta después del desembarco |

También corta con errores: asignación que empieza **después** del fin del período, o período cerrado.

## Durante el lote

- **Ventana de progreso** (`Progreso Liq.`): liquidación, empleado, *paso* (un grossing-up recalcula la lista de conceptos hasta 21 veces y se ve como "Grossing Up: iteración N de M"), avance %, tiempo transcurrido y segundos por liquidación.
- Cada liquidación corre en **su propia transacción**: una que falla no se lleva las demás; queda "N calculada(s), M con error" y el motivo en *Registros de Proceso*.
- El lote calcula **en orden de cálculo**: por empleado, por período y por el *Orden* del tipo, porque el tope de SIPA del SAC, Ganancias (retenido anterior) y los francos FIFO leen lo ya liquidado y el orden cambia importes ([[orden-calculo-del-lote]]).
- Al cerrar, si la corrida dejó **cinco o más avisos**, abre el informe *Avisos del cálculo*; con menos, el cartel resumen los dice.
- Si un lote se corta a la mitad, el estado de la ventana puede quedar sucio para el siguiente ([[progreso-singleinstance-sucio]]).

## Relacionado

[[Flujo operativo mensual de liquidación]] · [[Crear, calcular, aprobar y reabrir liquidaciones]] · [[Árbol de liquidaciones]] · [[Controles y avisos del cálculo]] · [[Tabla - Período Liquidación]]

## Ver también

[[Procesos por lotes y progreso]] · [[Lotes de liquidación]] · [[Tipos de liquidación]] · [[Aplicabilidad de un concepto a una liquidación]] · [[Tabla - Tipo Liquidación]] · [[Tabla - Estado Tipo Liq]]
