---
tipo: tabla
tags: [modelo-datos, periodos]
fuente: [src/Tables/Tab60010.PeriodoLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Período Liquidación (60010)

## Propósito
Ventana de tiempo contra la que se agrupan y calculan las liquidaciones. Un mes puede tener **más de un período** (`MENS072026`, `MENS072026B`).

## PK e índices
PK (clustered) `Código` (Code[10]); K2 `Año`, `Mes`.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `Código` (1) | Code[10] | Formato aaaamm desde el 26/9/2026 ([[periodos-aaaamm]]); si queda vacío en OnInsert se arma `Format(Año) + Format(Mes,2,'<Integer,2>')` |
| `Año` (2) / `Mes` (3) | Integer | Mín. 2000 / 1–12. OnValidate de `Mes` completa `Fecha Desde` (día 1) y `Fecha Hasta` (`<CM>`) si están vacías |
| `Fecha Desde` (4) / `Fecha Hasta` (5) | Date | Intervalo |
| `Estado` (6) | Enum [[Enums de liquidación#Estado Período Liq]] | Creado / Abierto / Cerrado. `InitValue = Creado`: un período nuevo nace Creado y hay que abrirlo |
| `Fecha Cierre` (7) / `Usuario Cierre` (8) | Date / Code[50] | No editables |
| `Cant. Liquidaciones` (9) | FlowField | `Count(Liquidación)` por período |
| `Cód. Calendario` (10) | Code[10] → `Base Calendar` | `DIAS_HAB` respeta sus días no laborables; vacío = lunes a viernes. El feriado real se resuelve primero por el calendario del convenio ([[Tabla - Convenio Colectivo]]) |

## Procedimientos
- `PeriodoPorDefecto()`: período que contiene `WorkDate`; si no, el último abierto; si no, el último cargado que no sea Creado.
- `ErrorSiCreado()`: corta con error si el período todavía no se abrió. Lo llaman el motor (`Cod50014`), los lotes (`Cod50018`, cuatro entradas), y `Rep50043`. **No** lo llaman las novedades. El Cerrado lo sigue rechazando cada llamador con su texto.
- `PeriodoAnterior(Cód)`: por `Fecha Desde` (no por Año/Mes: puede no ser mensual).
- `ContieneFecha(F)`.
- `PrimerDiaDelMes()`: manda lo que el período **declara** (Año/Mes) sobre sus fechas (un cierre que arranca el 28 del mes anterior pertenece al mes declarado).
- `CodigosDelMismoMes()`: todos los períodos del mismo mes (recorre la tabla entera: algunos viejos tienen Año/Mes vacíos). Lo usan el árbol de liquidaciones y el acumulado mensual por concepto del contexto; una sola copia de la regla para que no discrepen.

## Triggers
OnInsert (código y fechas por defecto). **OnDelete**: error si está Cerrado o si tiene liquidaciones.

## Quién la lee
`Cod50014`, `Cod50016`, `Cod50018` (lotes), `Cod50019`, `Cod50054.GestionMarea`, `Cod50061.GestionNovedadesLiq`, `Cod50074.ArbolLiquidacionesLiq`, `Cod110029`, `Cod110031.RecalculoEnCadenaLiq`, [[Tabla - Estado Empleado]] (cobertura bloqueante), `Tab110000`, `Tab110038`, [[Tabla - Cuota Préstamo]]. Páginas: `Pag50110 Períodos Liquidación`, `PagExt50351 JobCardExt`.

## Ciclo de estados y qué esconde Creado
Creado → Abierto → Cerrado (Cerrado → Abierto con *Reabrir Período*). Los períodos se cargan por adelantado y abiertos llenaban de ruido; **Creado existe pero no se opera**.
- **Se esconde en** `Pag50110` (filtro `Estado <> Creado` en `OnOpenPage`; acciones *Mostrar/Ocultar Creados*). Esa página es además el selector de las acciones y los lookups (`TableRelation`, `JobCardExt`, copia de novedades, asistente de fórmulas), así que lo heredan todos sin tocar cada `TableRelation`. También en `PeriodoPorDefecto` y en la navegación anterior/siguiente de `Pag110026`.
- **Se rechaza en** cálculo y creación de liquidaciones, con el mensaje "abrilo desde Períodos Liquidación". **Las novedades SÍ se pueden precargar en un Creado**: se materializan en la liquidación recién cuando el período se abre y se calcula.
- **Acciones:** *Abrir Período* (Creado → Abierto), *Pasar a Creado* (sólo sin liquidaciones; las novedades se conservan) y *Pasar a Creado los posteriores* al seleccionado, para ordenar de una vez los cargados por adelantado.
- **No hay migración automática:** los períodos que ya existen siguen Abiertos hasta que alguien corra *Pasar a Creado los posteriores*.
- La hoja de novedades (`Pag50013`) elige período con `OnLookup` propio, que abre `Pag50110` con `SetMostrarCreados(true)`, porque el selector estándar los esconde. `ErrorSiCreado()` ya no se llama desde `Tab110038` ni desde `Cod50061`.

## Vigencias
Sin vigencia: el período *es* la vigencia de sus liquidaciones.

## Trampas conocidas
- Formato viejo `MENSmmaaaa` ordenaba mal entre años: [[periodos-aaaamm]].
- La **ventana de liquidación es la cobertura**, no el período: [[ventana-liquidacion-es-cobertura]], [[cobertura-en-tramos]].
- Un período Cerrado no se puede borrar (esta tabla) y el cálculo lo rechaza (`Cod50014`, `Cod50018`: error si `Estado = Cerrado`). No hay ningún trigger en la tabla que cambie `Estado`: el cierre lo escribe quien lo ejecuta (`Fecha Cierre` y `Usuario Cierre` no son editables).
