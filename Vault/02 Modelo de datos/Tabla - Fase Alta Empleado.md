---
tipo: tabla
tags: [modelo-de-datos, empleados, fases, antiguedad, vigencias]
fuente: [src/Tables/Tab110048.FaseAltaEmpleado.al, src/Codeunits/Cod50017.GestionEstadoEmpleado.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110030.ControlCoberturaLiq.al]
actualizado: 2026-10-04
---

# Tabla - Fase Alta Empleado

**Tabla 110048 `Fase Alta Empleado`** (caption *Fases de Alta del Empleado*). **Datos persistentes.**

**Propósito.** Los períodos de relación laboral de un empleado, desde el alta hasta la baja: una fila por **fase**. Antes alta y baja eran dos filas de [[Tabla - Estado Empleado]], que admite un estado por empleado por fecha: el día que alguien ingresa *y* embarca, Meta4 registra las dos cosas (alta y estado operativo) y las dos son ciertas; en el modelo viejo una tenía que perder (153 filas en la migración de enero). Meta4 lo separa desde siempre (`M4T_FASES_ALTA` vs `M4T_HIST_ESTADOS_EMPL`). Ver [[tres-capas-fase-estado-asignacion]] y [[fases-bc-contra-meta4]].

Reparto: esta tabla = *cuándo pertenece a la empresa* (tramos, sin proyecto ni continuidad diaria); `Estado Empleado` = *qué hacía cada día*, contiguo y **sin altas ni bajas** (la tabla de estados lo rechaza).

## Clave primaria
`("No. Empleado","No. Fase")` — `No. Fase` correlativo **por empleado** (lo asigna `AbrirFase` con el máximo existente + 1). Secundaria `PorAlta`: `("No. Empleado","Fecha Alta")`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Empleado` | Code[20] → `Employee` | Caption *Cód. Legajo*. |
| `Fecha Alta`, `Cód. Motivo Alta`, `Comentario Alta` | Date/Code/Text | Motivo → `Cód. Estado Empleado` filtrado por `Tipo Estado = Alta`. |
| `Fecha Baja`, `Cód. Motivo Baja`, `Comentario Baja` | Date/Code/Text | Vacía = fase abierta. Motivo → `Cód. Estado Empleado` con `Tipo Estado = Baja`. |
| `Días` | Integer (no editable) | `Fecha Baja − Fecha Alta + 1` (**ambos extremos cuentan**); 0 en la fase abierta. |
| `Abierta` | Boolean (no editable) | `Fecha Baja = 0D`. |

Los motivos siguen en [[Tabla - Cód. Estado Empleado]] (ALT, BAJ-1, BAJ-7...) para no duplicar el catálogo.

## Lógica en triggers
`OnInsert` y `OnModify`: `ValidarOrdenDeFechas` (baja no anterior al alta), `ValidarSinSuperposicion` (la abierta se trata como fin 31/12/9999), `Recalcular`, `CerrarEstadosPorBaja`.

`CerrarEstadosPorBaja`: los estados operativos que **empiezan dentro de la fase** y están abiertos o cerrados más allá de la baja se cierran en `Fecha Baja` con `Modify(false)` — a propósito: el `OnModify` de `Estado Empleado` empujaría el siguiente y bloquearía si hay una liquidación sobre el tramo, y la baja es el hecho.

Procedimientos: `AbrirFase` (false si ya hay una abierta), `CerrarFase`, `TieneFaseAbierta`, `BuscarAbierta`, **`EstuvoActivoEntre(Emp, Desde, Hasta)`**, **`CalcDiasHasta(Emp, FechaRef)`**.

## Quién la lee y la escribe
- **Escribe:** páginas `Fases de Alta` (110028) y `Fases Alta Empleado Sub` (110044), y `Cod110037 Aplicar Fila Sinc NAV` (el alta de empleado desde NAV llama `AbrirFase` con la fecha de ingreso). La carga de fases desde Meta4 (`M4T_FASES_ALTA`) se hace con scripts SQL del repo: `scripts/MigrarFasesAlta_1_Meta4_Oracle.sql`, `MigrarFasesAlta_1b_GenerarInserts_Oracle.sql`, `MigrarFasesAlta_2_BC_SqlServer.sql` y `MigrarFasesAlta_3_AEntidadPropia.sql`; también `scripts/CerrarEstadosPorBaja.sql` (ver [[migracion-estados-meta4]]).
- **Lee:** `Cod50017 Gestión Estado Empleado` (antigüedad: `CalcDiasHasta`, línea ~706: "los tramos salen de Fase Alta Empleado, no de recorrer el historial de estados"), `Cod50018 Proceso Liq. por Lotes` (¿estuvo activo en el período?), `Cod110030 Control Cobertura Liq.`, `Cod50016 Contexto Liquidación` (ventanas de promedio de vacaciones/ausencia), `Antigüedad de la Plantilla`; `Estado Empleado` valida contra ella (`ValidarDentroDeFaseDeAlta`).

## Vigencias
Tramos disjuntos por empleado: dos fases no pueden solaparse. Una fase sin `Fecha Baja` es la vigente y se mide contra la **fecha de referencia** de la liquidación, no contra hoy; las fases que empiezan **después** de esa fecha no cuentan.

## Trampas
> [!danger] Sin fases cargadas, EstuvoActivoEntre devuelve TRUE
> Es deliberado: un legajo sin fases no dice "no estaba", dice "no lo sabemos". Equivocarse de más produce una liquidación vacía que se borra; de menos, alguien no cobra. Antes el lote elegía por asignación a proyecto y en enero 2026 generó 47 liquidaciones de gente que no estaba.

> [!warning] Antigüedad: ambos extremos
> `Hasta − Alta + 1`. Con la resta sola se perdía un día por fase y a un legajo con 18 fases lo dejaba un escalón abajo en la escala del CCT. Una fase de un solo día cuenta 1. Ver [[antiguedad-dia-por-fase]] y [[antiguedad-suma-de-fases]].

> [!warning] Fase superpuesta = antigüedad inflada, sin error visible
> `CalcDiasHasta` suma cada fase sin mirar las otras: el solapamiento cuenta días dos veces. Por eso la tabla lo rechaza.

- Un estado sin fecha fin vale hasta 31/12/9999 (`FechaFinEfectiva`); ver [[recorrer-estado-abierto-dia-por-dia]]. De ahí los estados de 2001 que se solapaban con 2026 antes de `CerrarEstadosPorBaja`.
- Una alta por SQL directo (sin pasar por AL) no crea la fase: antigüedad cero y francos sin devengar. Por eso el empleado desde NAV se crea por AL ([[Tabla - Stg Empleado NAV]]).

## Relacionado
[[Tabla - Estado Empleado]] · [[Tabla - Stg Empleado NAV]] · [[estado-empleado-effective-dated]] · [[migracion-estados-meta4]] · [[antiguedad-suma-de-fases]]
