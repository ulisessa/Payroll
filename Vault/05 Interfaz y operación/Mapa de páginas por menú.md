---
tipo: referencia
tags: [paginas, menu, role-center, ui]
fuente: [src/Pages/Pag50149.PayrollRoleCenter.al, src/PageExtensions/PagExt50352.ITManagerRCPayrollExt.al, src/PageExtensions/PagExt50350.EmployeeCardExt.al, src/PageExtensions/PagExt50351.JobCardExt.al, src/PageExtensions/PagExt50356.EmployeeListExt.al, src/PageExtensions/PagExt50358.JobListExt.al]
actualizado: 2026-10-04
---

# Mapa de páginas por menú

Los **captions** son los reales del código (lo que se ve en pantalla; el nombre del objeto AL a veces difiere y se indica cuando importa). Todas se abren también con la búsqueda de BC (*Alt+Q*) si tienen `UsageCategory`. Las subpáginas, diálogos y pantallas auxiliares están en [[Mapa de páginas auxiliares y subpáginas]]. Quién puede abrir cada una: [[Perfiles, Role Center y permisos]].

## Role Center *Liquidación de Sueldos* (Pag50149)

### Nómina

| Caption | ID | Qué hace | Más info |
|---|---|---|---|
| **Liquidaciones** | 50100 | Lista de liquidaciones con Calcular, Aprobar, Reabrir, Eliminar, Revertir aprobación e Imprimir recibo (uno o selección) | [[Crear, calcular, aprobar y reabrir liquidaciones]] |
| **Árbol de Liquidaciones** | 110017 | Las mismas liquidaciones agrupadas Mes → Fecha → Tipo → (Proyecto) → Liquidación, con subtotales; acciones de lote sobre el nodo | [[Árbol de liquidaciones]] |
| **Períodos** (Períodos Liquidación) | 50110 | Alta de períodos; crear, calcular, revertir, eliminar borradores, cerrar y reabrir períodos | [[Flujo operativo mensual de liquidación]] |
| **Novedades de Liquidación** | 50013 | Hoja para cargar novedades contra un período, antes de que exista la liquidación | [[Novedades e incidencias - carga operativa]] |
| **Lanzador de Liquidaciones** | 50155 | Crea y calcula en lote por período y tipo | [[Lanzador de liquidaciones y lotes]] |
| **Tipos de Liquidación** | 50195 | Catálogo de tipos y cuándo corresponde cada uno (disparador, meses, estados) | [[Lanzador de liquidaciones y lotes]] |

### Convenios

| Caption | ID | Qué hace | Más info |
|---|---|---|---|
| **Convenios Colectivos** | 50105 | Maestro de CCT; acciones *Categorías* y *Conceptos* | [[Tabla - Convenio Colectivo]] |
| **Categorías CCT** | 50106 | Categorías por convenio | [[Tabla - Categoría CCT]] |
| **Conceptos** (Conceptos Liquidación) | 50107 | Lista de conceptos; abre la ficha 50145. Acciones: Nueva Vigencia, Historial de Fórmulas, Probar Fórmula, y tres de mantenimiento único | [[Configurar un concepto (guía paso a paso)]] |
| **Fórmulas con errores** | 110045 | Parsea todas las fórmulas y condiciones y lista las que no compilan | [[Controles y avisos del cálculo]] |

### Parámetros

| Caption | ID | Qué hace | Más info |
|---|---|---|---|
| **Parámetros** | 50108 | Catálogo de parámetros (nombre de variable, antigüedad máxima de vigencia); ficha 50138 con los valores por alcance | [[Configurar un parámetro y su vigencia]] |
| **Árbol de Parámetros** | 110013 | Valores ordenados por especificidad (defecto → convenio → convenio+categoría → empleado) | [[Configurar un parámetro y su vigencia]] |
| **Parámetros Vigentes** | 50154 | Lista plana de todos los valores con *Nuevo Valor* y *Limpiar bloqueos "En Uso"* | idem |
| **Variables Sistema** (*Variables Sistema Liquidación*) | 50146 | Qué variable de sistema está disponible y con qué nombre; *Sembrar variables estándar*, *Revisar nombres duplicados* | [[variable-sistema-hay-que-sembrarla]] |
| **Fuentes de Datos** | 50134 | Variables que leen cualquier tabla de BC; ficha 50141 | [[Configurar fuentes de datos]] |
| **Tipos de Atributo** | 110007 | Atributos con historial (convenio, categoría, zona, pesquería…) | [[atributos-tipados]] |
| **Valores de Atributo** | 110010 | Listas cerradas y el número que cada valor le pasa a las fórmulas | [[atributos-tipados]] |
| **Clases de Entidad** | 110015 | Agrupa entidades (buques, plantas, mareas) y define qué atributos les tocan | idem |
| **Entidades** | 110018 | Entidades tomadas de valores de dimensión; estados en lote y plantilla de atributos | idem |
| **Tablas Escalonadas** | 50131 | Tramos para `TRAMO()` (Ganancias, escalas); *Nueva Vigencia* | [[Ejemplos completos de conceptos]] |
| **Ded. Ganancias (AFIP)** (*Tabla Deducciones Ganancias (AFIP)*) | 50150 | Importes anuales de deducciones; *Nueva Vigencia* | [[familiar-alta-impuesto]] |

### Empleados

| Caption | ID | Qué hace | Más info |
|---|---|---|---|
| **Estados Empleado** | 50103 | Historial de estados del empleado (y del buque); fechas contiguas | [[estado-empleado-effective-dated]] |
| **Antigüedad de la Plantilla** | 110029 | Antigüedad de todos los empleados por fases de alta | [[antiguedad-suma-de-fases]] |
| **Cód. Estados** (Cód. Estados Empleado) | 50104 | Catálogo de estados; *Crear estados de buque* | idem |
| **Francos por Tripulante** | 110024 | Saldo de francos por tripulante y categoría del lote, a una fecha de corte | [[francos-fifo-ledger]] |
| **Saldo Inicial de Francos** | 110025 | Carga y aplicación del saldo previo a la puesta en marcha (*Aplicar* / *Revertir*) | idem |
| **Asignar Atributos en Lote** | informe 50045 | Asigna un atributo a muchos empleados, buques o proyectos | [[Reportes y procesos masivos]] |
| **Migrar Convenio y Categoría** | informe 50046 | Carga inicial del historial convenio/categoría como atributos | [[Reportes y procesos masivos]] |
| **Atributos** | 110011 | Valores de atributos por empleado/buque/marea con historial; abre mostrando sólo los vigentes | [[atributos-tipados]] |
| **Importaciones SIRADIG** | 50171 | Importa y procesa archivos SIRADIG | [[Importación SIRADIG - operación]] |

### Herramientas

| Caption | ID | Qué hace | Más info |
|---|---|---|---|
| **Asistente de Fórmulas** | 50139 | Probar fórmulas contra un empleado y período reales | [[Asistente de fórmulas y detalle del cálculo]] |
| **Historial de Fórmulas** (*Historial de Cambios de Fórmula*) | 110004 | Quién cambió qué fórmula; permite restaurar | [[Tabla - Historial Fórmula Concepto]] |
| **Registros de Proceso** | 110000 | Historial de cálculos, aprobaciones y reaperturas con errores y advertencias | [[Controles y avisos del cálculo]] |
| **Versiones Inactivas a Revisar** | 110006 | Versiones de concepto con `Activo = false` y qué cambia para cada una | [[conceptos-tres-vigencias]] |
| **Control de Orden de Cálculo** | 50014 | Detecta conceptos que leen un acumulador antes de que todos sus aportes entren | [[acumuladores-orden-calculo]] |
| **Días Liquidados por Empleado** (*Control de Cobertura Liq.*, objeto 110026) | 110026 | Días con estado que ninguna liquidación cubrió | [[Controles y avisos del cálculo]] |
| **Conceptos por Tipo Liq.** | 50193 | Asigna conceptos a tipos con dos listas | [[Configurar un concepto (guía paso a paso)]] |
| **Convenios por Concepto** | 50074 | Asigna convenios a varios conceptos a la vez | idem |
| **Conceptos por Convenio** | 50076 | Parte de un convenio (y categoría) y tilda los conceptos que le aplican | idem |
| **Buques** (*Valores de Dimensión y Entidades*) | 50191 | Valores de dimensión de buque; abre/crea la entidad asociada | [[atributos-tipados]] |

### Informes (área *Reporting*)

| Caption | ID | Más info |
|---|---|---|
| **Recibo de Sueldo** | 50041 | [[Recibo de sueldo (reporte)]] |
| **Asignar Estado Masivo** | 50042 | [[Reportes y procesos masivos]] |
| **Insertar Incidencia Masiva** | 50044 | [[Reportes y procesos masivos]] |
| **Crear Liq. para Empleado** | 50043 | [[Reportes y procesos masivos]] |
| **Préstamos y Anticipos** (página) | 50180 | Lista de préstamos; ficha 50181 con cuotas |

Además, la tarjeta de actividades del Role Center es `Cue SIRADIG` (50173).

## Pantallas fuera del menú

| Caption | ID | Se abre desde |
|---|---|---|
| **Control de Liquidación por Marea** | 110022 | Ficha y lista de *Proyectos* (Job): acción *Control de Liquidación* ([[Controles y avisos del cálculo]]) |
| **Control de Liquidación por Período** | 110056 | *Períodos* → acción *Control de liquidación* |
| **Fases de Alta** | 110028 | Ficha del empleado → *Fases de Alta*; o *Antigüedad de la Plantilla* |
| **Comparar BC contra Meta4** | 110051 | Búsqueda (corrida en paralelo con Meta4) |
| **Historia de Liquidaciones (Meta4)** | 110047 | Búsqueda; ficha 110048, catálogo de columnas 110050 |
| **Sincronización con NAV** | 110032 | Búsqueda; desde ahí las páginas de filas traídas (110033 a 110043) y la configuración (110037) — ver [[Sincronización NAV - visión general]] |
| **Líneas Liquidación** | 50118 | Es la subpágina de la ficha; también acción *Ver Líneas* en la lista |

## Páginas estándar de BC extendidas

| Página base | Extensión | Qué agrega |
|---|---|---|
| `Job Card` | `PagExt50351` | Hora de arribo/zarpada, estado predeterminado, zona desfavorable, proyecto de inactividad; acciones *Control de Liquidación*, *Liquidar Personal (Regular)*, *Crear Devengados*, *Crear Cierre Marea* (habilitada sólo con fecha de arribo), *Crear Nueva Marea*, *Copiar Personal de Proyecto* |
| `Job List` | `PagExt50358` | *Control de Liquidación (Excel)*, *Control de Liquidación*, *Crear Nueva Marea* |
| `Employee Card` | `PagExt50350` | Grupo **Liquidación** (convenio, categoría, antigüedad, antigüedad reconocida, fecha de jubilación, zona desfavorable) y partes Atributos, Fases de Alta, Proyectos Asignados, Historial de Estados, Deducciones Ganancias; acciones de navegación incluido *Nuevo Préstamo / Anticipo* |
| `Employee List` | `PagExt50356` | Acciones *Crear Liquidación*, *Establecer estado (lote)*, navegación y la vista **Pendientes de completar (Sinc.)** (empleados sin convenio) |
| `Human Resources Setup` | `PagExt50353`, `PagExt50355` | Grupo **Liquidaciones** (serie, proyecto nómina, estado de alta de sincronización, máx. intentos, concepto de neto garantizado, acumulador de haberes gravados) y grupo **SIRADIG** (carpeta) |
| `Employee Relatives` | `PagExt50354` | Tipo y número de documento, fechas de impuesto, tipo de deducción, % de deducción, adicional de obra social ([[familiar-alta-impuesto]]) |
| `Units of Measure` | `PagExt110032` | *Plural Liq.*: cómo se escribe la unidad en el recibo cuando la cantidad no es 1 |

> [!note] Dos ExtensionObjects con el mismo ID 50356
> `Pag-Ext50356.EmpFamilyExt.al` declara `pageextension 50357` (nombre de archivo y ID no coinciden) y `PagExt50356.EmployeeListExt.al` declara el 50356. No es un error de compilación, pero el nombre del archivo `Pag-Ext50356` es engañoso.

## Ver también

[[Extensión - Job]] · [[Extensión - Employee]] · [[Extensión - Human Resources Setup]] · [[Extensión - Human Resources Setup SIRADIG]] · [[Extensión - Employee Relative]] · [[Extensión - Unit of Measure]] · [[Sincronización NAV - operación y errores]] · [[Comparador BC vs Meta4]] · [[Objetos AL]]
