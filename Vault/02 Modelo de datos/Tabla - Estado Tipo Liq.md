---
tipo: tabla
tags: [modelo-de-datos, tipos-de-liquidacion, seleccion, cobertura]
fuente: [src/Tables/Tab110059.EstadoTipoLiq.al, src/Codeunits/Cod50018.ProcesoLiqPorLotes.al, src/Codeunits/Cod110054.CoberturaTramosLiq.al, src/Codeunits/Cod50055.GestionTipoLiq.al]
actualizado: 2026-10-04
---

# Tabla - Estado Tipo Liq

**Tabla 110059 `Estado Tipo Liq.`** (caption *Estados exigidos por tipo de liquidación*). **Datos persistentes** (configuración).

**Propósito.** Qué estados tiene que tener —o no tener— un empleado para que un tipo de liquidación le corresponda. Es la **tercera pregunta** de la selección del lote: (1) asignado a un proyecto del tipo dentro del período, (2) alguna fase de alta dice que ese mes pertenecía a la empresa, (3) sus **estados** dicen si hay algo que liquidar. Los mismos estados definen qué **días cubre** el tipo ([[Tabla - Tramo Cobertura Liq]]).

**Regla:** la liquidación se crea si **alguna** línea *Exige* encuentra estado y **ninguna** línea *Excluye* lo encuentra. Sin líneas el tipo se comporta como antes. Las *Exige* se combinan con **O** (caso: vacaciones se pagan si el empleado las toma este mes *o* el que viene).

Es tabla y no campos del tipo porque la cantidad de condiciones no está acotada y cada una lleva tres calificadores propios (ventana, modo, tipo de proyecto).

## Clave primaria
`("Cód. Tipo Liq.","No. Línea")` (`No. Línea` con `AutoIncrement`). Secundaria `("Cód. Tipo Liq.", Modo)`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `Cód. Tipo Liq.` | Code[20] → [[Tabla - Tipo Liquidación]] | |
| `Modo` | Enum `Modo Estado Tipo Liq.` | Exige / Excluye. |
| `Cód. Estado` | Code[50] | **Filtro**, no código: admite `BAJ*`, `NV|PL|PS`, `<>OI`. Un código a secas sigue valiendo. Sin `TableRelation`. **En blanco = cualquier estado** (igual exige al menos uno en la ventana). |
| `Ventana` | Enum `Ventana Estado Tipo Liq.` | Cobertura (días que cubre la liquidación) / Período completo / Mes siguiente. |
| `Tipo Proyecto` | Option Todos/Productivo/Improductivo | Del proyecto **del estado**, no de la liquidación (ordinales de `Job.Tipo`). La Regular pide los días que NO son de una marea. |
| `Descripción` | Text[100] | |
| `Empieza en la Ventana` | Boolean | El estado debe **arrancar** dentro de la ventana, no solaparla. Evita que vacaciones ya iniciadas (1/1→4/2) cuenten como anticipo del mes siguiente. |

## Lógica en triggers
`OnValidate Cód. Estado`: valida la sintaxis del filtro (`TryAplicarFiltro` con `IsEmpty` para forzar la evaluación) y avisa con `Message` si no coincide con ningún código de [[Tabla - Cód. Estado Empleado]]. `CoincideEstado(Cod)` evalúa el filtro sobre un registro temporal de una fila (mismo motor de filtros que SQL; blanco coincide con todo).

## Quién la lee y la escribe
- **Escribe:** página `Estados Tipo Liq. Sub` (110053, subpágina de Tipo Liquidación); `Cod50055 Gestión Tipo Liq.` (siembra/retira líneas de REGULAR, VACACIONES, etc.).
- **Lee:** `Cod50018 Proceso Liq. por Lotes` (`EstadoCumpleLinea`, `HayEstado`, `EstadoCumpleProyecto`, `VentanaDe`, con caché de coincidencia) y `Cod110054 Cobertura Tramos Liq.`; `Tipo Liquidación` tiene un FlowField `exist(...)`.

## Trampas
> [!warning] Sin permisos en los PermissionSets
> `Estado Tipo Liq.` no figura en `LiqPescaAdmin`, `LiqPescaLiquidador` ni `LiqPescaLectura` (verificado en `src/PermissionSets/`) y las tablas no declaran `InherentPermissions`. Un usuario no-SUPER que cree liquidaciones por lote (donde `Cod50018` la lee) recibiría error de permisos. Verificar en el entorno antes de asumir que anda.

> [!warning] Un typo en el filtro no da error: deja al tipo sin generarse
> Por eso el `OnValidate` avisa si el filtro no coincide con ningún estado. La línea se guarda igual.

> [!warning] "Solapar no es empezar"
> En enero de 2026, sin `Empieza en la Ventana` había 64 liquidaciones de vacaciones de más (522 millones en haberes). La regla del anticipo es sobre la fecha de **inicio**.

- Blanco en `Cód. Estado` ≠ "ningún filtro": sigue exigiendo al menos un estado.
- Ver [[tipo-liq-no-implementada]] (la ayuda promete `TIPO_LIQ`, que no existe) y [[vacio-en-tipos-liq-aplicables-es-comodin]].

## Relacionado
[[Tabla - Tipo Liquidación]] · [[Tabla - Tramo Cobertura Liq]] · [[cuando-corresponde-una-liquidacion]] · [[cobertura-en-tramos]] · [[exclusividad-vacaciones]] · [[job-tipo-cero-no-bloquea]]
