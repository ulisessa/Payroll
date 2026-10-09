---
tipo: guia
tags: [integracion-nav, operacion, errores, runbook]
fuente: [src/Pages/Pag110032.ControlSincNAV.al, src/Pages/Pag110037.ConfigSincNAV.al, src/Codeunits/Cod110036.SincNAVLiq.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Tables/Tab110041.CtrlSincNAV.al]
actualizado: 2026-10-04
---

# Sincronización NAV - operación y errores

Cómo se opera la sincronización día a día y cómo se destraba. Arquitectura: [[Sincronización NAV - visión general]].

## Las dos páginas de operación

**"Sincronización con NAV" (Pag110032, `Control Sinc. NAV`)** - una fila por entidad, con *Pendientes* y *Con Error* (drill-down al staging) y estas acciones:

| Acción | Qué hace |
|---|---|
| Traer ahora de NAV | `Traer NAV WS.TraerEntidad` sólo de la entidad seleccionada (WS). Con SQL la traída es del job del Agent. |
| Procesar pendientes | `Sinc NAV Liq.ProcesarTodo` - lo mismo que el Job Queue. |
| Procesar sólo esta entidad | `ProcesarEntidad(Rec.Entidad)`. |
| Ver filas traídas | Abre la página de staging de la entidad. |
| Reintentar las que fallaron | `ReprocesarErrores`: devuelve `Error` a `Pendiente` e `Intentos = 0`. **Antes hay que corregir la causa.** |
| Volver a traer todo | Vacía `Marca Agua` (confirma). Siguiente corrida = carga completa. No borra nada en BC. |
| Configuración / Empleados a completar | Abre `Config Sinc NAV` / la lista de empleados (los sin convenio son los pendientes de completar). |

**"Configuración Sincronización NAV" (Pag110037)**: transporte, URL/empresa/usuario WS, entity sets, números de tabla, nombres de tabla del origen; acciones *Completar valores por defecto*, *Cargar clave de web services*, *Probar conexión* (`$top=1` a `Entidad Proyectos`) y *Estado de la sincronización*.

## Automatización

Entrada de Job Queue cada 15 minutos sobre Cod110042 `Traer y Procesar NAV` (sirve para los dos transportes). Con SQL, el job del Agent corre a las :02 para que el orden natural sea traer y después aplicar. El resultado de cada entidad queda en `Ctrl Sinc NAV` (`Filas Procesadas`, `Ultima Observacion`: "N aplicadas, M en espera, K con error" o "Sin filas pendientes").

## Qué significa cada error típico

| Mensaje / síntoma | Causa | Qué hacer |
|---|---|---|
| "Espera al proyecto X, que todavía no llegó de NAV" | Descarga/informe/diario antes que su `Job` | Normal; se reintenta solo hasta `Máx. Intentos Sinc.`. Si llega a `Error`: traer/procesar Proyecto y reintentar. |
| "Se agotaron los N intentos. Último motivo: ..." | Idem, vencido el máximo | Resolver el proyecto faltante y *Reintentar las que fallaron*. |
| "La dimensión X no existe en BC..." | Valor de dimensión de una dimensión no creada | Crear la dimensión en BC (decisión contable) y reintentar. |
| "No se puede dar el alta: definí «Cód. Estado de Alta (Sinc. NAV)»..." | Más de un código activo de tipo Alta y sin configurar | Cargar el campo en `Human Resources Setup`. |
| Aviso "NAV no trajo fecha de ingreso..." (en `Procesado`) | Empleado creado sin fase de alta | Cargar la fase a mano; mientras tanto antigüedad = 0 y sin devengo de francos. |
| NAV devolvió el estado/tipo "X" ... no está en la lista | Instancia de NAV en otro idioma o caption nueva | Ampliar `EstadoProyectoDesdeTexto`/`TipoProyectoDesdeTexto` (Cod110041). |
| Descarga nueva falla con "Puerto debe tener un valor" | Se insertó antes de llenar campos | Ya resuelto: campos antes del `Insert`. |
| Líneas de descarga fallan con "valor que no se puede encontrar en la tabla relacionada" | Tipo de proyecto en blanco (Productivo mapeado a 0) | Verificar `TipoProyectoDesdeTexto` (Productivo = 1). |
| `Codeunit.Run() no está permitido` | Falta `Commit()` previo | Ya está; ver [[codeunit-run-necesita-commit]]. |
| Marea `LAN`/`CAL` en todos los proyectos | Dimensiones 2/3 sin cruzar | [[dim2-nav-actividad-bc-marea]]. |
| Todo "se trae" pero nada llega tras cambiar de transporte | Marca de agua de otro transporte | Vaciar `Marca Agua`. |
| Invalid object name al traer (SQL) | `Empresa NAV` con puntos en vez del prefijo SQL | Usar el valor del bloque 3 del script. |

## Reglas de operación

- **No** correr UPDATE por SQL sobre `Job`/`Employee` para "arreglar" proyectos: usar el reintento o corregir el origen ([[sql-directo-deja-cache-rancia]]).
- Vaciar `Marca Agua` es seguro (el volcado a staging es idempotente), pero con 240.000 líneas de descarga la carga completa es un lote grande.
- El orden manual correcto ante un lote atascado: Valor Dimensión -> Empleado -> Proyecto -> Descargas/Informe/Diario (el botón *Procesar pendientes* ya lo respeta).

## Hallazgos del código (verificados leyendo, no ejecutados)

> [!warning] `Reprocesar errores` no cubre las 4 entidades nuevas
> `Sinc NAV Liq.ReprocesarErrores` abre el `RecordRef` sólo para Valor Dimensión, Empleado, Proyecto, Descarga Cab. y Descarga Lín. Para Informe Cap. (5, 6) y Diario de Abordo (7, 8) el `case` no asigna tabla y luego usa `RecRef.Field(90)`: previsiblemente falla en ejecución. Mientras tanto, esas filas en `Error` se pueden devolver a `Pendiente` editando el staging a mano.

> [!warning] El texto de "Volver a traer todo" habla sólo del job de SQL
> La acción vacía `Marca Agua` también con WS, donde dispara la **carga inicial** (barrido completo) en la próxima traída.

> [!note] Estado `Omitido` y bajas
> `Omitido` no se asigna en ningún lado; las bajas del Change Log no se aplican ([[Sincronización NAV - transporte WS]]).

## Ver también

[[Tabla - Ctrl Sinc NAV]], [[Tabla - Config Sinc NAV]], [[Extensión - Human Resources Setup]] (campos `Cód. Estado Alta Sinc.` y `Máx. Intentos Sinc.`), [[Sincronización NAV - entidades y mapeo]].
