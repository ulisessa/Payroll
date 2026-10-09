---
tipo: tabla
tags: [modelo-datos, tipos-liquidacion, configuracion, motor]
fuente: [src/Tables/Tab50578.TipoLiquidacion.al, src/Codeunits/Cod50055.GestionTipoLiq.al]
actualizado: 2026-10-04
---

# Tabla - Tipo Liquidación (50578)

## Propósito
**Maestro configurable de tipos de liquidación** (REGULAR, AGUINALDO, VACACIONES, LIQ_FINAL, RELIQUIDACION, DEVENGADOS, CIERRE_MAREA, SALDO_INICIAL…). Reemplazó a un enum fijo: los tipos genéricos son datos puros y los que tienen comportamiento especial se marcan con banderas; **ningún código AL está atado a un código de tipo concreto**. Decide *cuándo corresponde* una liquidación ([[cuando-corresponde-una-liquidacion]]), sobre qué proyectos corre, qué población y qué conceptos.

## PK e índices
PK `Código` (clustered); clave `Orden` (`Orden`). DropDown: Código, Descripción.

## Campos (por rol)
| Rol | Campo | Propósito |
|---|---|---|
| Identidad | `Código` (1), `Descripción` (2), `Activo` (6, InitValue true) | `Activo` = existe y se puede usar (≠ entra en corrida) |
| Orden / TIPO_LIQ | `Orden` (3) | **Único**. También es el valor de la variable de sistema `TIPO_LIQ` en fórmulas (`IF(TIPO_LIQ = 70, …)`). Seed: REGULAR 10, AGUINALDO 20, VACACIONES 30, LIQ_FINAL 40, RELIQUIDACION 50, DEVENGADOS 60, CIERRE_MAREA 70; el 0 lo usa SALDO_INICIAL |
| Disparo | `Disparador` (11, enum [[Enums de liquidación#Disparador Tipo Liq]]) | Ninguno / Arribo / MareaEnCurso / BajaEmpleado |
| Calendario | `Meses` (12, Text[30]) | Filtro de BC sobre el mes (`6|12` aguinaldo, `1..6`); vacío = todos. Se evalúa con una tabla temporal `Mes Filtro Liq.` para reutilizar la sintaxis de filtros de BC |
| Estados | `Exige Estados` (13) | **FlowField** `exist("Estado Tipo Liq.")`: líneas de estado exigido/excluido (tabla 110059, enums [[Enums de liquidación#Modo Estado Tipo Liq]] y [[Enums de liquidación#Ventana Estado Tipo Liq]]) |
| Población | `Aplica A` (15, enum Aplica A Liq.) | A qué tipo de empleado corresponde el *documento* entero (sale del convenio). Evitó que un mensualizado de vacaciones cobrara Vacaciones **y** Regular completos (90016: 50,4 M contra 24,2 M de Meta4) |
| Proyectos | `Tipo Proyecto` (8, **Option** Todos/Productivo/Improductivo) | Ordinales = los de `Job.Tipo`; se usa directo como filtro. Lo declara el tipo porque el operador se equivocó dos veces eligiendo "Todos" (180 Regulares en cero + 501 Devengados en cero) |
| Agrupación | `Agrupa por Empleado` (7), `Incluye Francos Puerto` (5) | Una cabecera por empleado+período sin proyecto (Regular). Ortogonales al disparador |
| Conceptos | `Sólo Conceptos Declarados` (14) | **Invierte** la lista blanca de `Tipos Liq. Aplicables` de los conceptos: el tipo corre únicamente los que lo nombran (el vacío deja de ser comodín). Se marca en 5 tipos en vez de tocar 185 conceptos. Sin esto, en enero 2026 133 empleados cobraron dos veces el SAC devengado, ART, contribuciones, jubilación, cuota sindical y Ganancias |
| Corrida | `Entra en Corrida Completa` (10) | Arranca en **falso** a propósito: la corrida "sin tipo" = todos los que lo tengan marcado. Sin esto salieron 2.748 liquidaciones de SALDO_INICIAL/LIQ_FINAL/RELIQUIDACION/AGUINALDO en enero 2026 y el bruto de BC dio 29% arriba de Meta4 |
| Obsoletos (Pending) | `Liquida al Arribo` (4), `Sólo Proyectos en Curso` (9) | Reemplazados por `Disparador` |

## Procedimientos
`EsArribo`, `EsMareaEnCurso`, `EsBajaEmpleado` (leen `Disparador`), `CubreSoloElProyecto` (por `Tipo Proyecto = Productivo`, **no** por disparador: el Devengado corre sobre mareas sin dispararse al arribo y con la regla vieja cubría el mes entero → 2.425 días de más), `CorreEnElMes`, `CodigoFrancosPuerto`, `CodigoArribo`.

> [!warning] `CodigoArribo()` todavía lee la bandera obsoleta
> Filtra por `Liquida al Arribo = true`, no por `Disparador = Arribo`, y la usa `Cod50018.ProcesoLiqPorLotes` (línea ~312, `CrearPorProyecto`). Un tipo de cierre creado a mano **sólo** con `Disparador = Arribo` haría que `CodigoArribo` falle con "No hay ningún Tipo… marcado como Liquida al Arribo". `Cod50055.ConfigurarDisparadores` migra la bandera al disparador y `Sembrar` marca CIERRE_MAREA con ambos. Sin verificar el comportamiento en una base nueva.

## Triggers
OnInsert: si `Orden = 0` y no es el primero, asigna el siguiente libre (+10); luego `ValidarOrdenUnico`. OnModify: `ValidarOrdenUnico`. (Corre en cada insert/modify, no sólo en el OnValidate del campo, para cubrir `Cod50055.Sembrar`.)

## Quién la lee
`Cod50014.MotorLiquidacion`, `Cod50016.ContextoLiquidacion` (`TIPO_LIQ`), `Cod50017`, `Cod50018.ProcesoLiqPorLotes`, `Cod50019`, `Cod50055.GestionTipoLiq` (siembra y `ConfigurarDisparadores`, idempotente: no pisa lo cargado a mano), `Cod50061`, `Cod50074`, `Cod50076`, `Cod110029`, `Cod110054`. La referencian [[Tabla - Liquidación]], [[Tabla - Línea Liquidación]], [[Tabla - Estado Empleado]] (`EsArribo`), `Tab110000`, `Tab110038`, `Tab110059`. Páginas: `Pag50195 Tipos Liquidación`, `Pag50176 Selector Tipos Liq`, `Pag50194 Conceptos Tipo Liq Sub`, `Pag50196`. Instalación/upgrade: `Cod50056.TipoLiqInstall`, `Cod50057.TipoLiqUpgrade`.

## Vigencias
No tiene; los cambios de configuración valen para las corridas siguientes.

## Trampas conocidas
> [!danger] Vacío en "Tipos Liq. Aplicables" es comodín
> 185 conceptos no declaran tipo; un tipo de más duplica el recibo **entero**. Ver [[vacio-en-tipos-liq-aplicables-es-comodin]], [[migracion-tipo-liq-incompleta]], [[lote-tipo-liq-en-blanco]].

- `Tipo Proyecto = Todos` es legítimo para otros tipos: no avisa si es el equivocado ([[job-tipo-cero-no-bloquea]]).
- Exclusividad Vacaciones/Regular vía `HAY_LIQ_VACACIONES`: [[exclusividad-vacaciones]]; vacaciones de tierra: [[vacaciones-tierra-duplica-el-mes]].
- Cobertura: [[cobertura-devengado-tapa-dias]], [[ventana-liquidacion-es-cobertura]].
- `TIPO_LIQ`: la lección [[tipo-liq-no-implementada]] dice que no existe (al 28/9/2026), pero hoy `Cod50016` **sí** resuelve el `Cód. Cálculo` `TIPO_LIQ` y `Cod50077.Sembrar` lo siembra: la lección está desactualizada. Ver también [[orden-calculo-del-lote]].
