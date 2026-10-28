---
tipo: referencia
tags: [reportes, procesos-masivos, cargas, mantenimiento]
fuente: [src/Reports/Rep50042.AsignarEstadoMasivo.al, src/Reports/Rep50043.CrearLiqParaEmpleado.al, src/Reports/Rep50044.InsertarIncidenciaMasiva.al, src/Reports/Rep50045.AsignarAtributoMasivo.al, src/Reports/Rep50046.MigrarConvenioCategoria.al, src/Reports/Rep50047.AvisosDelCalculo.al, src/Pages/Pag110025.SaldoInicialFrancos.al, src/Pages/Pag50107.ConceptosLiquidacion.al, src/PageExtensions/PagExt50356.EmployeeListExt.al]
actualizado: 2026-10-04
---

# Reportes y procesos masivos

Los informes `ProcessingOnly` (sin impresión) de la extensión son **procesos masivos**: se abren como una ventana de solicitud con filtros y opciones, corren con ventana de progreso y terminan con un cartel de resultado. Los de impresión son [[Recibo de sueldo (reporte)]] y *Avisos del cálculo* ([[Controles y avisos del cálculo]]).

| Caption | Informe | Dónde se abre |
|---|---|---|
| **Asignar Estado Masivo** | 50042 | Role Center → Informes |
| **Crear Liq. para Empleado** | 50043 | Informes; *Períodos* → *Crear Liq. para Empleado*; Lista de empleados → *Crear Liquidación* |
| **Insertar Incidencia Masiva** | 50044 | Informes |
| **Asignar Atributos en Lote** (*Asignar Atributo Masivo*) | 50045 | Empleados |
| **Migrar Convenio y Categoría** (*… a Atributos*) | 50046 | Empleados |
| **Avisos del cálculo** | 50047 | Se abre solo al final de un lote con 5 o más avisos |

## Asignar Estado Masivo (50042)

Asigna **un estado** a muchos empleados desde una **fecha de inicio**. Filtros: *Empleado (No., Estado)* y *Personal Proyecto (No. Proyecto)*.

| Opción | Efecto |
|---|---|
| **Cód. Estado** | Obligatorio |
| **Fecha Inicio** | Obligatoria; propone la fecha de trabajo |
| **Omitir conflictos** | Los empleados con un estado en conflicto (fecha ya cubierta o mismo inicio) se omiten **sin preguntar**; sin tildar, pregunta por cada uno |

Resultado: "Se asignó el estado a N empleado(s). M omitido(s) por conflicto." **Alcance real:** el informe recorre empleados **que tengan al menos una asignación en Personal Proyecto** (dataitem anidado) y procesa cada empleado una sola vez; un empleado sin ninguna asignación a proyecto **no entra**. Alternativas sin esa limitación: *Establecer estado (lote)* en la Lista de empleados y *Establecer estado* en *Entidades* (propaga el estado a los empleados de los proyectos activos de cada buque). Reglas de contigüidad: [[estado-empleado-effective-dated]].

## Crear Liq. para Empleado (50043)

Crea liquidaciones en Borrador para los empleados filtrados (*No., Nombre, Apellido, Estado*). **Período** y **Tipo Liquidación** son **obligatorios**: el tipo no se infiere a propósito, porque sin él la cabecera queda en blanco y el motor no aplica los conceptos restringidos por tipo, sin avisar. Falla si el período está cerrado o falta la serie de numeración. Usa **toda** la lógica de creación del lote (agrupación, proyecto desde el estado, las cuatro guardas de [[Lanzador de liquidaciones y lotes]]): crea sólo lo que *corresponde*, así que puede crear **cero** y decirlo.

## Insertar Incidencia Masiva (50044)

Carga **la misma incidencia** (concepto + importe, o cantidad × valor unitario) en muchas liquidaciones **ya existentes**. Filtros sobre *Liquidación*: *No., Período, Tipo Liq., Empleado, Convenio, Estado*.

| Campo | Detalle |
|---|---|
| **Cód. Concepto** | Obligatorio |
| **Cantidad**, **Unidad Cantidad**, **Valor Unitario** | Si hay cantidad **y** valor, el importe es Cantidad × Valor redondeado a 0,01 |
| **Importe** | Obligatorio y distinto de 0 (directo o por cálculo) |
| **Observaciones** | Se copia a cada incidencia |
| **Sobrescribir si ya existe** | Reemplaza la incidencia existente de ese concepto; sin tildar esas liquidaciones se **omiten** |

Sólo actúa sobre liquidaciones en **Borrador**: resultado "Se insertó la incidencia en N liquidación(es). M omitida(s) (no estaba en Borrador, o ya tenía incidencia…)". **Para cargar antes de que existan las liquidaciones, usar *Novedades de Liquidación*** ([[Novedades e incidencias - carga operativa]]); y una incidencia hecha a mano **gana** sobre la novedad.

## Asignar Atributo Masivo (50045)

Asigna **un atributo con vigencia** a muchos empleados, buques (entidades) o proyectos: "todos los de este convenio pasan a zona Patagonia desde el 1/9".

| Grupo | Campo | Detalle |
|---|---|---|
| Qué asignar | **Tipo de entidad** | *Empleado*, *Buque* o *Proyecto*: cambia los filtros (Empleado: No./Estado; Entidad: Código/Clase; Proyecto: No./Dim. global 1) |
| | **Atributo** | Define el tipo de dato |
| Valor | **Valor** | Un solo campo: lookup si es lista; numérico/fecha/texto se escribe y se valida |
| | **Vigencia desde** | La vigencia anterior de cada entidad **se cierra sola** el día previo |
| Si ya lo tiene | **Acción** | *Crear una vigencia nueva* (conserva historial) u *Omitir la entidad* (completa sólo las que no lo tienen) |

Una fila con **la misma vigencia** ya cargada se omite siempre (podría estar usada en una liquidación). Cada alta corre en su propia transacción. Resultado: "N asignación(es) creada(s), M omitida(s), sobre K entidad(es) evaluada(s)". Ver [[atributos-tipados]].

## Migrar Convenio y Categoría (50046)

**Una sola vez**: toma el convenio y la categoría que cada empleado ya tiene (ficha o asignación a proyecto) y los escribe como **atributos** con una fecha común. Los tipos de atributo se buscan por su **espejo** (el que refleja *Convenio Colectivo* y el que refleja *Categoría CCT*), no por nombre. Opciones: **Vigencia desde** (propone 1/1/2026) y **Solo simular** (recorre y dice qué haría sin escribir; correrlo así primero y mirar los que no se pueden migrar). Informa migrados / ya tenían historial / sin datos de origen / con error. Ver [[previsualizar-antes-de-migrar]] y [[migracion-atributos-cct-meta4]]. Sólo está en el permission set *Admin*.

## Otros procesos masivos (acciones en páginas)

| Dónde | Acción | Qué hace | Cuidado |
|---|---|---|---|
| **Novedades de Liquidación** | *Importar de Excel/CSV* | Una novedad por fila: Empleado, Concepto, Cantidad, Valor Unitario, Importe, Fecha, Tipo Liq., Observaciones, Proyecto. Saltea el encabezado y las filas con empleado o concepto inexistente y las informa | [[Novedades e incidencias - carga operativa]] |
| | *Copiar de otro período*, *Generar recurrentes* | Traen novedades sin duplicar | idem |
| **Saldo Inicial de Francos** | *Aplicar* / *Revertir* | Genera o borra los lotes de francos de la carga. **Aplicar valida toda la carga antes de escribir**; los lotes nacen en liquidaciones *Aprobadas* de importe cero con un tipo propio | [[francos-fifo-ledger]] |
| **Lista de empleados** | *Establecer estado (lote)* | Estado + fecha para los seleccionados | |
| **Entidades** | *Establecer estado*, *Aplicar plantilla de atributos* | Estado al buque y propagado a sus empleados; crea los atributos obligatorios que falten sin tocar los existentes | |
| **Control de Liquidación por Marea / Lista de Proyectos** | *Control de Liquidación (Excel)* | Baja la matriz a Excel | [[excel-buffer-writer-en-la-variable]] |
| **Registros de Proceso** | *Depurar registros antiguos* | Borra registros anteriores a una fecha | El histórico crece con cada cálculo |
| **Importaciones SIRADIG** | *Importar Archivos SIRADIG*, *Importar desde Carpeta del Servidor* | Carga de archivos | [[Importación SIRADIG - operación]] |
| **Días Liquidados por Empleado** | *Completar fechas de cobertura* | Rellena la cobertura de liquidaciones viejas; no recalcula ni toca importes | |

### Acciones de "una sola vez" tras actualizar la extensión

Existen para migrar datos al nuevo modelo; **ejecutarlas cuando se indica y no como rutina**:

| Acción | Dónde | Efecto |
|---|---|---|
| **Formatear todas las fórmulas** | *Conceptos* | Reescribe todas las fórmulas y condiciones en forma canónica (sangría, saltos). No cambia lo que calculan |
| **Activar "Imprime en Recibo" en todos** | *Conceptos* | Marca **todos** los conceptos existentes como imprimibles (**pisa** los que estaban en No) |
| **Asignar Grupo Costo Laboral** | *Conceptos* | Asigna el rubro a SS y Contribuciones **según la descripción** |
| **Sembrar y migrar datos** | *Tipos de Liquidación* | Crea los tipos por defecto y convierte liquidaciones, líneas y conceptos del enum al código. Seguro de repetir |
| **Sembrar variables estándar** | *Variables Sistema* | Agrega las que falten; no toca las existentes |
| **Crear estados de buque** | *Cód. Estados* | Crea Pesca, Navegación, Puerto, Amarrado y Dique con ámbito Buque; después **revisar *Devenga Francos*** en cada uno |
| **Recalcular niveles del árbol** | *Árbol de Parámetros* | Sólo la indentación |

> [!warning] Formatear y Activar son escrituras masivas sobre los conceptos maestros
> No recalculan liquidaciones, pero cambian la configuración. Probar primero en un entorno de prueba.

Relacionado: [[Flujo operativo mensual de liquidación]] · [[Mapa de páginas por menú]] · [[bucle-modifica-campo-filtrado]] · [[codeunit-run-necesita-commit]]

## Ver también

[[Incidencias masivas]] · [[Altas masivas y migraciones de fechas]] · [[Saldo inicial de francos]] · [[Atributos tipados]]
