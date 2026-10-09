---
tipo: proceso
tags: [dominio, carga-masiva, migracion, upgrade]
fuente: [src/Reports/Rep50042.AsignarEstadoMasivo.al, src/Reports/Rep50045.AsignarAtributoMasivo.al, src/Reports/Rep50046.MigrarConvenioCategoria.al, src/Codeunits/Cod50017.GestionEstadoEmpleado.al, src/Codeunits/Cod50062.EstadoFechaFinUpgrade.al, src/Codeunits/Cod50082.MigracionFechasImpFam.al, src/Codeunits/Cod50072.AltaEstadosBuque.al, src/Codeunits/Cod50073.PlantillaAtributosLiq.al, src/Codeunits/Cod50079.AltaAtributoEntidadLiq.al, src/Codeunits/Cod110043.SinDialogoDimJob.al, src/Codeunits/Cod50056.TipoLiqInstall.al, src/Codeunits/Cod50057.TipoLiqUpgrade.al]
actualizado: 2026-10-04
---

# Altas masivas y migraciones de fechas

Todo lo que carga o corrige estados, atributos, fases o fechas **en bloque**, y los `Upgrade`/`Install` que lo dejaron en el estado actual. Regla común: cada alta pasa por la **misma tabla** que el alta manual, así que valen las mismas validaciones; lo que cambia es qué se hace cuando una fila falla.

## Cargas masivas operativas

| Qué | Cómo | Particularidades |
|---|---|---|
| **Estado a empleados** (selección de la lista de empleados) | `SetEstadoEnLoteEmpleados` (Cod50017), acción de la lista de empleados + diálogo `Estado en Lote Dialog` | `FSkipConflicts` activo: si ya hay un estado que **arranca ese día** se reemplaza sin preguntar. Sin él, `SetEstadoEntidad` pregunta. |
| **Estado a empleados con asignación** | Reporte 50042 `Asignar Estado Masivo` | Recorre `Employee` → `Personal Proyecto`; cada empleado **una sola vez** (`ProcessedEmployees`). Pide estado y fecha de inicio; opción *Omitir conflictos*. Un empleado **sin ninguna asignación no se procesa**. |
| **Estado a buques y propagación** | Acción *Establecer estado* de *Entidades* → `SetEstadoEnLoteEntidades` → `SetEstadoBuque` | Junta las claves antes de escribir (propaga a la tripulación). Recibe **entidades**, no valores de dimensión: sólo alcanza lo ya clasificado. Ver [[Estados de empleado y de buque]]. |
| **Atributo a muchas entidades** | Reporte 50045 `Asignar Atributo Masivo` | Un dataitem por tipo de entidad (`Employee`, `Entidad Liq.`, `Job`); sólo corre el que coincide. Modos: *crear vigencia nueva* u *omitir si ya lo tiene*. |
| **Plantilla de atributos** | `Plantilla Atributos Liq.` desde *Entidades* | Crea las filas obligatorias que falten. Ver [[Entidades y clases de entidad]]. |
| **Estados de buque** | Acción *Crear estados de buque* en *Cód. Estados Empleado* | `Alta Estados Buque`: crea `PESCA`, `NAVEGACION`, `PUERTO`, `AMARRADO`, `DIQUE` con `Ámbito = Buque`; no pisa. Hay que revisar `Devenga Francos` de cada uno. |
| **Tipos de liquidación** | Acción *Sembrar y migrar datos* | Ver [[Tipos de liquidación]]. |

### Atributo masivo: reglas finas
- **Una fila con la misma vigencia se omite siempre**, en cualquiera de los dos modos: podría tener un valor ya usado en una liquidación y sobrescribirlo en un proceso masivo no se puede explicar después.
- Para un atributo de **lista** se verifica que el código pertenezca al tipo (por código y no con `Get`: con atributos encadenados la PK lleva el padre en el medio, y un `Get` de dos argumentos compilaría y compararía contra el campo equivocado, ver [[get-con-menos-argumentos]]). **No se filtra por padre**: elegís `OF01` y cada empleado recibe la `OF01` de **su propio convenio** (el padre lo resuelve la tabla contra el padre vigente de cada entidad).
- Cada alta corre en su propia transacción con `Codeunit.Run(Alta Atributo Entidad Liq.)` y `Commit()` previo. **No** con `[TryFunction]`: un TryFunction no puede escribir en la base, y el síntoma engaña porque la primera entidad se asigna bien. Una que falla se cuenta como omitida y el lote sigue. Ver [[codeunit-run-necesita-commit]].
- Una *request page* **no reevalúa `Visible`** después de abrirse: por eso hay un solo campo `Valor` para los cuatro tipos de dato. Y su lookup usa `Page::"Valores de Atributo"` por nombre, no `Page.RunModal(0, …)`.
- `CurrReport.Break()` en el `OnPreDataItem` saltea el bucle pero **no** el `OnPostDataItem`: la bandera `Corrio` evita cerrar un diálogo que nunca se abrió.

### Estado masivo: lo que conviene saber
- El reporte 50042 informa "N omitido(s) por conflicto" calculando `Procesados − Contador`; como ambos contadores suben juntos, **el número de omitidos siempre es 0** (los conflictos se resuelven dentro de `SetEstado` sin avisar). No es un indicador confiable.
- La carga se frena sola si hay una **liquidación no Borrador** que cubra los días ([[Estados de empleado y de buque]]): revertirla antes.

## Migración de convenio y categoría (reporte 50046)

`Migrar Convenio y Categoría a Atributos`: toma el par que cada empleado tiene en su **ficha** (`Employee."Cód. Convenio"/"Cód. Categoría"`) y lo escribe como atributos con una **fecha de inicio común** (por defecto 1/1/2026; lo anterior queda sin cubrir). Es un proceso de migración, **no de operación**: de ahí en adelante los cambios son una vigencia nueva por empleado.
- Los tipos no se nombran: se buscan **por espejo** (`TipoConEspejo`), igual que en el motor. Si faltan, error.
- **Convenio primero, categoría después**: la categoría valida contra el padre vigente a esa fecha.
- Quien **ya tiene** algún atributo de ese tipo no se pisa ("el historial existente manda sobre una migración, que es una reconstrucción aproximada").
- Opción **Solo simular**: recorre todo y lista qué haría. Correrlo así primero.
- Cada alta con `Commit()` + `Codeunit.Run`; falla ⇒ anota y sigue. El detalle sale en un mensaje (se corta en ~3.000 caracteres).
- Ya no existe la opción de tomar el par de la asignación a proyecto: esos campos se eliminaron de `Personal Proyecto` el 18/9/2026.

## Upgrades que dejaron huella

| Objeto | Qué hizo | Estado |
|---|---|---|
| `Estado Fecha Fin Upgrade` (archivo `Cod50062`, **objeto 50065**) | Materializó `Fecha Fin` en el historial cargado cuando el fin era derivado; el último de cada entidad queda abierto. Idempotente, tag `UAS-Payroll-EstadoEmpleado-FechaFin-20260807`. `Modify()` sin disparar contigüidad por fila (sería cuadrático). | Terminado. |
| `Migracion Fechas ImpFam` (`Cod50082`) | Aplanaba los tres pares de fechas de familiares en `Fecha inicial/final`. | **Vacío desde el 22/9/2026**; se conserva sólo por su tag. Ver [[Deducciones de Ganancias y familiares]]. |
| `Tipo Liq. Install` / `Tipo Liq. Upgrade` | `Sembrar` + `MigrarDatos` + `ConfigurarDisparadores` en cada instalación y upgrade. | **Convergen** (ver advertencia en [[Tipos de liquidación]]). |

## Altas desde NAV

La sincronización con NAV crea el empleado y **abre la fase de alta** (`Fase Alta Empleado.AbrirFase` con `Fecha Ingreso` y el estado de alta de Configuración de RR.HH.); nunca toca convenio, categoría ni zona. Mientras importa proyectos activa `Sin Dialogo Dim Job` (Cod110043): suscribe `OnBeforeUpdateJobTaskDimension` y, con `IsHandled`, evita el diálogo "Ha cambiado una dimensión…" **propagando igual la dimensión a las tareas** (de lo contrario el resultado dependería de si se corre desde página o desde el Job Queue, donde no hay diálogo y la rutina base sí actualiza). Fuera de la sincronización el interruptor está apagado. Ver [[job-confirm-dimension-inocuo]] y `04 Integraciones`.

## Antes de migrar

- Limpiar siempre **de arriba hacia abajo**: fases → estados → asignaciones ([[tres-capas-fase-estado-asignacion]]).
- Previsualizar con controles de invariante ([[previsualizar-antes-de-migrar]]).
- Las migraciones desde Meta4 están en [[migracion-estados-meta4]], [[migracion-atributos-cct-meta4]], [[fases-bc-contra-meta4]] y [[migracion-novedades-meta4]].
- Un `UPDATE` directo por SQL no corre triggers ni invalida la caché del service tier: [[sql-directo-deja-cache-rancia]]; y por SQL hay que **replicar** la regla de `CerrarEstadosPorBaja`.

Relacionado: [[Fases de alta]], [[Atributos tipados]], [[Índice Dominio - empleado y condiciones]].
