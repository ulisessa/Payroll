---
tipo: referencia
tags: [integracion-nav, staging, dimensiones, mapeo]
fuente: [src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110036.SincNAVLiq.al, src/Codeunits/Cod110041.TraerNAVWS.al, src/Enums/Enum50328.EntidadSincNAV.al, src/Tables/Tab110042.StgProyectoNAV.al, src/Tables/Tab110045.StgEmpleadoNAV.al, src/Tables/Tab110047.StgValorDimNAV.al, src/Tables/Tab110043.StgDescargaCabNAV.al, src/Tables/Tab110044.StgDescargaLinNAV.al, src/Tables/Tab110049.StgInformeCapCabNAV.al, src/Tables/Tab110050.StgInformeCapLinNAV.al, src/Tables/Tab110051.StgDiaAbordoCabNAV.al, src/Tables/Tab110052.StgDiaAbordoLinNAV.al]
actualizado: 2026-10-04
---

# Sincronización NAV - entidades y mapeo

Qué entidades se sincronizan, a qué tabla de BC aterriza cada una y **qué se escribe con `Validate` y qué no**. Contexto: [[Sincronización NAV - visión general]].

## Las 9 entidades

El **ordinal** (Enum50328 `Entidad Sinc NAV`) es identidad: se guarda en `Ctrl Sinc NAV.Entidad` y en el script T-SQL. **El orden de proceso es otro** y está escrito a mano en `Sinc NAV Liq.ProcesarTodo`.

| Orden de proceso | Entidad (ordinal) | Staging (tabla) | Clave | Destino en BC | Espera a |
|---|---|---|---|---|---|
| 1 | Valor Dimension (4) | `Stg Valor Dim NAV` (110047) | Cod Dimension + Codigo | `Dimension Value` | - |
| 2 | Empleado (0) | `Stg Empleado NAV` (110045) | No Empleado | `Employee` + `Fase Alta Empleado` | - |
| 3 | Proyecto (1) | `Stg Proyecto NAV` (110042) | No Proyecto | `Job` | valores de dimensión |
| 4 | Descarga Cabecera (2) | `Stg Descarga Cab NAV` (110043) | No Proyecto | `Cab. descarga` | `Job` existe |
| 5 | Descarga Linea (3) | `Stg Descarga Lin NAV` (110044) | No Proyecto + Line No | `Lín. descarga` | `Job` existe |
| 6 | Informe Cap Cabecera (5) | `Stg Informe Cap Cab NAV` (110049) | No Proyecto | `Cab. informe capitán` | `Job` existe |
| 7 | Informe Cap Linea (6) | `Stg Informe Cap Lin NAV` (110050) | No Proyecto + Line No | `Lín. informe capitán` | `Job` existe |
| 8 | Dia Abordo Cabecera (7) | `Stg Dia Abordo Cab NAV` (110051) | No Proyecto | `On board capture` | `Job` existe |
| 9 | Dia Abordo Linea (8) | `Stg Dia Abordo Lin NAV` (110052) | No Proyecto + Line No | `On board capture lines` | `Job` existe |

Las tablas `Cab./Lín. descarga`, informes y diario vienen de la personalización de NAV convertida (extensión "Tables Only" / Final Version). `Cab. informe capitán`, `On board capture` etc. son nombres tal cual del código.

**Campos comunes del staging (90-95), mismo número y significado en las 9 tablas**: `Estado Sinc`, `Observacion`, `Intentos`, `Marca Origen`, `Traido El`, `Procesado El`. Ese contrato permite escribir resultado/reintentos por `RecordRef` con un solo procedimiento. Cada tabla tiene además la clave `K2 (Estado Sinc, PK...)` para recorrer pendientes.

## Qué hace `Aplicar Fila Sinc NAV` con cada una

### Valor de dimensión
Si la dimensión **no existe en BC** -> error ("crear una dimensión es una decisión contable"). Si el valor ya existe **no se toca** (se anota en `Observacion` si el nombre difiere). Si no existe, se crea con `Validate` de Dimension Code, Code, Name y `Blocked`. **No actualiza nombres existentes** a propósito: en NAV conviven "HAI XIANG 16"/"HAI XIANG", "Vistoria II" por Victoria; pisar devolvería esos errores ([[sincronizacion-valores-dimension]]). En WS la carga inicial se filtra por `Dimension_Code` de las tres dimensiones leídas de `General Ledger Setup` (Global 1, Global 2 y Shortcut 3), y se descartan los tipos no estándar.

### Empleado
- Alta o modificación con `Validate` de nombre, segundo nombre, apellido, iniciales, puesto, nº seguridad social, nacimiento, domicilio, teléfono, mail y `Employment Date`.
- **`CIF/NIF` se copia tal cual**: el CUIL de los empleados vive ahí, no en `Social Security No.` ([[cuil-vive-en-cif-nif]]); la importación de SIRADIG busca en los dos ([[SIRADIG - importación]]).
- **Convenio, categoría y zona NUNCA se tocan** (el empleado queda con convenio en blanco; eso filtra la vista "Pendientes de completar (Sinc.)"). `Convenio Origen` y `Categoria Origen` se traen al staging pero **no se aplican** (verificado).
- Sólo en el **alta** se abre la **fase** con `Fase Alta Empleado.AbrirFase(Empleado, Fecha Ingreso, CodEstadoAlta, '')`. Si ya hay una fase abierta vale la existente. Sin fecha de ingreso: se crea el empleado, **no** la fase, y queda un aviso.
- **Sin código de alta** (`Cód. Estado Alta Sinc.` en `Human Resources Setup`; o único código activo de tipo Alta) no se crea empleados nuevos: fila en `Error`. Las modificaciones sí pasan.

### Proyecto (Job)
Orden deliberado: `Description`/`Description 2` por `Validate`; **`Ending Date := 0D` por asignación directa antes de tocar `Starting Date`** (BC valida inicial <= final contra el valor *actual*); `Starting Date`; dimensiones por `Validate` (Buque = Global 1, **Marea = Global 2**, **Actividad = Global 3**, campo 50000 del Job para que funcionen los FlowFilters `Filtro actividad`); `Tipo`; campos de la extensión `Job Ext.` por **asignación directa** (Patrón, horas, puertos, `Year tide`); y **al final `Validate("Ending Date", Fecha Fin)`**, porque cargar la fecha de arribo cierra la marea y el `OnModify` de `Proyecto Pesca Ext.` cierra las asignaciones abiertas. Si esa cadena falla, falla la fila entera.
`Estado` del staging se trae pero **no se aplica** al Job.

> [!warning] Dimensiones 2 y 3 cruzadas
> NAV: dim 2 = actividad (LAN/CAL), dim 3 = marea. BC: dim 2 = marea, dim 3 = actividad. Copiar por posición deja todos los proyectos con marea `LAN`/`CAL` **sin error**. Tanto el script SQL como `VolcarProyectos` (WS) hacen el cruce explícito. Ver [[dim2-nav-actividad-bc-marea]]. El código de dimensión además no siempre coincide con el segmento del `No.` (`PP-HUAI-260001` -> `HUA`; `PP-MAT` -> `MT1`) y hay mareas de 7 dígitos: se lee la dimensión, no se parsea el número.

### Descargas, informe del capitán, diario de abordo
Se asignan **todos los campos antes del `Insert`** (el `OnInsert` de las tablas convertidas valida campos propios y con la fila vacía rechaza; sólo fallaba en las 148 descargas nuevas de 2957). Campos con `Validate` puntual: `Origen del cartón`, `Tipo de amparo sanitario`, `Confirmed`. **No se escriben**: `Zona de pesca` del diario (llega como caption y hay que mirar los `OptionMembers` antes de traducir), `Cantidad` de la cabecera del informe (en NAV es FlowField), `Buque`/`Marea` de la cabecera del informe (no los expone la página NAV; están en el proyecto), y `Pallets desde/hasta` por WS.

## Qué esperan las entidades dependientes

`Descarga*`, `Informe*` y `Diario*` consultan `Job.Get(No Proyecto)`: si el proyecto no llegó, la fila **se difiere** (`Pendiente` + motivo "Espera al proyecto X, que todavía no llegó de NAV") y recién al agotar `Máx. Intentos Sinc.` pasa a `Error`. Los valores de dimensión y empleados no esperan a nadie.

## Dónde mirar cada una en la UI

Páginas 110033 (proyectos), 110034 (empleados), 110035/110036 (descargas cab/lín), 110038 (valores dim), 110040/110041 (informe capitán), 110042/110043 (diario de abordo), todas listas del staging con su estado y observación. Navegación desde [[Sincronización NAV - operación y errores]].

## Ver también

Tablas de staging: [[Tabla - Stg Proyecto NAV]], [[Tabla - Stg Empleado NAV]], [[Tabla - Stg Valor Dim NAV]], [[Tabla - Stg Descarga Cab NAV]], [[Tabla - Stg Descarga Lin NAV]], [[Tabla - Stg Informe Cap Cab NAV]], [[Tabla - Stg Informe Cap Lin NAV]], [[Tabla - Stg Dia Abordo Cab NAV]], [[Tabla - Stg Dia Abordo Lin NAV]]. Destinos: [[Extensión - Job]], [[Extensión - Employee]], [[Extensión - Dimension Value]], [[Tabla - Fase Alta Empleado]], [[Fases de alta]].
