---
tipo: referencia
tags: [modelo-datos, indice]
fuente: [src/Tables/, src/TableExtensions/, src/Enums/]
actualizado: 2026-10-04
---

# Índice Modelo de datos (60xxx)

Tablas `Tab60000`–`Tab60029`, `Tab50575/50576/50578`, las 7 TableExtensions y todos los Enums. Las tablas 110xxx tienen su propio índice (otra área). Diagramas: [[Mapa del modelo de datos - configuración y empleado]]. Enums: [[Enums de liquidación]].

> [!warning] ID declarado ≠ nombre de archivo
> | Archivo | ID declarado en el código | Nota |
> |---|---|---|
> | `Tab50575.PrestamoEmpleado.al` | **50579** `Préstamo Empleado` | Manda el declarado |
> | `Tab50576.CuotaPrestamo.al` | **50580** `Cuota Préstamo` | Manda el declarado |
> | `TabExt110033.UnidadPluralExt.al` | tableextension 110033, campo 52020 | Único tableextension en el rango 110xxx; los demás son 520xx |
>
> Huecos de numeración: **no existen** las tablas 60001, 60002 ni 60005 (ni 50577), y no existen los enums 50306 ni 50316. El rango de licencia corta en 60029 ([[rangos-licencia-objetos]]).

## Configuración
| ID | Tabla | Nota | Qué es |
|---|---|---|---|
| 60003 | Cód. Estado Empleado | [[Tabla - Cód. Estado Empleado]] | Catálogo de códigos de estado con banderas |
| 60004 | Convenio Colectivo | [[Tabla - Convenio Colectivo]] | Maestro de convenios |
| 60006 | Categoría CCT | [[Tabla - Categoría CCT]] | Categorías por convenio |
| 60007 | Concepto Liquidación | [[Tabla - Concepto Liquidación]] | Conceptos versionados (fórmula, orden) |
| 60017 | Fracción Acumulador | [[Tabla - Fracción Acumulador]] | Distribución de conceptos a acumuladores |
| 60019 | Concepto CCT Vigente | [[Tabla - Concepto CCT Vigente]] | Convenios/categorías a los que aplica un concepto |
| 60016 | Parámetro | [[Tabla - Parámetro]] | Definición de parámetros |
| 60008 | Parámetro Vigente | [[Tabla - Parámetro Vigente]] | Valores con vigencia (clave derivada) |
| 60018 | Variable Sistema Liq. | [[Tabla - Variable Sistema Liq]] | Cálculos de sistema con nombre configurable |
| 60015 | Fuente Datos Liquidación | [[Tabla - Fuente Datos Liquidación]] | Variables leídas de cualquier tabla |
| 60029 | Filtro Fuente Datos Liq. | [[Tabla - Filtro Fuente Datos Liq]] | Filtros de las fuentes |
| 60013 | Tabla Escalonada | [[Tabla - Tabla Escalonada]] | Cabecera de escalas (`TRAMO`) |
| 60014 | Tabla Escalonada Det. | [[Tabla - Tabla Escalonada Detalle]] | Tramos |
| 50578 | Tipo Liquidación | [[Tabla - Tipo Liquidación]] | Maestro de tipos (disparador, calendario, población) |
| 60021 | Ded. Ganancias Vigente | [[Tabla - Ded. Ganancias Vigente]] | Importes AFIP de deducción |

## Empleado, estados y asignación
| ID | Tabla | Nota | Qué es |
|---|---|---|---|
| 60000 | Estado Empleado | [[Tabla - Estado Empleado]] | Historial contiguo de estados (empleado y buque) |
| 60009 | Personal Proyecto | [[Tabla - Personal Proyecto]] | Asignación empleado↔proyecto |
| 60022 | Ded. Ganancias Empleado | [[Tabla - Ded. Ganancias Empleado]] | Declaraciones de deducción por empleado |
| 50579 | Préstamo Empleado (archivo Tab50575) | [[Tabla - Préstamo Empleado]] | Préstamos y anticipos |
| 50580 | Cuota Préstamo (archivo Tab50576) | [[Tabla - Cuota Préstamo]] | Cuotas |
| 60026 | Importación SIRADIG | [[Tabla - Importación SIRADIG]] | Registro de archivos SIRADIG |
| 60027 | Cue SIRADIG | [[Tabla - Cue SIRADIG]] | Tiles del Role Center |

## Transaccional
| ID | Tabla | Nota | Qué es |
|---|---|---|---|
| 60010 | Período Liquidación | [[Tabla - Período Liquidación]] | Ventana de liquidación |
| 60011 | Liquidación | [[Tabla - Liquidación]] | Cabecera del recibo |
| 60012 | Línea Liquidación | [[Tabla - Línea Liquidación]] | Conceptos calculados (con signo propio) |
| 60020 | Incidencia Liquidación | [[Tabla - Incidencia Liquidación]] | Importes manuales / materializados |
| 60023 | Detalle Variable Línea Liq. | [[Tabla - Detalle Variable Línea Liq]] | Variables y tramos por línea |
| 60024 | Resumen Variable Liq. | [[Tabla - Resumen Variable Liq]] | Variables por liquidación |
| 60025 | Detalle Ganancias Liq. | [[Tabla - Detalle Ganancias Liq]] | Deducciones y pasos de Ganancias |
| 60028 | Detalle Acumulador Liq. | [[Tabla - Detalle Acumulador Liq]] | Buffer temporal de pantalla |

> [!note] Nombres de nota
> Las tablas cuyo nombre termina en punto (`Variable Sistema Liq.`, `Tabla Escalonada Det.`, `Filtro Fuente Datos Liq.`, `Detalle … Liq.`, `Resumen Variable Liq.`, `Detalle Acumulador Liq.`) tienen la nota **sin el punto final** (`Tabla - Variable Sistema Liq`), porque un punto antes de `.md` es problemático en nombres de archivo. `Tabla Escalonada Det.` se llama `Tabla - Tabla Escalonada Detalle`.

## TableExtensions
| Objeto | Extiende | Nota |
|---|---|---|
| TabExt52000 Empleado Pesca Ext. | `Employee` | [[Extensión - Employee]] |
| TabExt52001 HR Setup Liq. Ext. | `Human Resources Setup` | [[Extensión - Human Resources Setup]] |
| TabExt52004 HR Setup SIRADIG Ext. | `Human Resources Setup` | [[Extensión - Human Resources Setup SIRADIG]] |
| TabExt52002 Empleado Relativo Liq. Ext. | `Employee Relative` | [[Extensión - Employee Relative]] |
| TabExt52003 Proyecto Pesca Ext. | `Job` | [[Extensión - Job]] |
| TabExt110033 Unidad Plural Liq. | `Unit of Measure` | [[Extensión - Unit of Measure]] |
| TabExt52005 Clase en Dimension Value | `Dimension Value` | [[Extensión - Dimension Value]] (obsoleta) |

## Enums
32 enums (50300–50333) en [[Enums de liquidación]], agrupados por dominio.

## Patrones transversales del modelo
- **Versionado por `Vigencia Desde`** (+ `Vigencia Hasta` sólo en conceptos): conceptos, parámetros, fracciones, convenios aplicables, tablas escalonadas, deducciones, estados. En conceptos y estados la cadena se **mantiene sola** (contigüidad); en el resto manda "la última `<=` fecha de referencia".
- **Una configuración, no un código**: banderas en catálogos (`Cód. Estado Empleado`, `Tipo Liquidación`), nombres de variable configurables, fuentes de datos por ID de tabla/campo ([[avoid-tables-principle]]).
- **Lo que no tiene TableRelation a propósito**: `Cód. Concepto` en las líneas (versionado), clave derivada de `Parámetro Vigente`, `Cód. Entidad` de `Estado Empleado` (apunta a Empleado **o** Buque).
- **`Modify()`/`Insert()`/`DeleteAll()` sin parámetro NO ejecutan triggers** en AL: varias cadenas (contigüidad de conceptos, cascadas de borrado, módulo de préstamos) dependen de eso a propósito.
- **Bloqueo por liquidaciones no Borrador**: estados, parámetros `En Uso` y vigencias de conceptos usados.
- **Obsoletos con datos**: campos `Pending` que se conservan (`Concepto.Activo`, `Aplica Tipo Liq.`, banderas de sufijo de `Parámetro`, filtros 1–3 de `Fuente Datos`, banderas de `Tipo Liquidación`, campos de impuesto de `Employee Relative`): ver cada nota.

## Hallazgos de verificación contra el código
1. `Tipo Liquidación.CodigoArribo()` filtra por la bandera **obsoleta** `Liquida al Arribo` y no por `Disparador = Arribo` ([[Tabla - Tipo Liquidación]]).
2. El catálogo de `Variable Sistema Liq.` documentado en la tabla y su `StrMenu` omiten `DIAS_MES`, `MESES_PROM_AUS_6/12`, `DIAS_ESTADO_PERIODO/PREVIOS` que el motor sí resuelve ([[Tabla - Variable Sistema Liq]]).
3. La lección [[tipo-liq-no-implementada]] está desactualizada: `TIPO_LIQ` sí está implementada en `Cod50016` y sembrada en `Cod50077`.
4. Tres enums sin referencias: `Tabla Origen Liq.`, `SIRADIG Código Deducción`, `SIRADIG Parentesco` ([[Enums de liquidación]]).
5. `Liquidación.OnDelete` no limpia `Detalle Ganancias Liq.` ni `Resumen Variable Liq.` explícitamente (sí lo hace `DeleteLineas` en el recálculo).
6. El comentario de `Employee."Antigüedad Reconocida"` habla de "último estado Alta en Estado Empleado": las altas viven hoy en las fases de alta ([[Extensión - Employee]]).
7. Los códigos de tipo de `Ded. Ganancias Vigente` del comentario (`HIJO_MENOR`, `HIJO_INCAP`) y los que menciona `Parámetro."Edad Máxima Familiar"` (`HIJO`, `HIJO_INC`) no coinciden: verificar en datos ([[Tabla - Ded. Ganancias Vigente]]).
## Divergencias de `GUIA-LIQUIDACION.md` ("Referencia de tablas del sistema") contra el código
La guía quedó desactualizada en la sección de tablas; **manda el código** (y estas notas). Puntos verificados:

| Tabla | La guía dice | El código dice |
|---|---|---|
| Convenio / Personal Proyecto | El convenio y la categoría salen de `Personal Proyecto` (`Cód. Convenio`, `Cód. Categoría`) | Esos campos **se eliminaron el 18/9/2026**; el par sale de atributos con historial (espejo de [[Tabla - Convenio Colectivo]] y [[Tabla - Categoría CCT]]), con la ficha de `Employee` como respaldo |
| Parámetro | Banderas `Sufijo CCT`, y clave `CÓDIGO_CONVENIO_CATEGORÍA` según la bandera | Las tres banderas son **obsoletas**; la clave derivada se arma desde los campos de cada valor ([[Tabla - Parámetro]]) |
| Parámetro Vigente | PK `Cód. Parámetro + Vigencia Desde` | PK `Cód. Parámetro Base + Cód. Parámetro + Vigencia Desde`; ejes empleado/convenio/categoría; `Nivel` ([[Tabla - Parámetro Vigente]]) |
| Variable Sistema Liq. | 5 variables; `ANIOS_ANTIGUEDAD`; `DIAS_PROYECTO` por defecto `DIAS_MAR` = fin − inicio del Job; desactivar deja la variable en 0 | ~33 códigos de cálculo; se escribe `AÑOS_ANTIGUEDAD`; `DIAS_PROYECTO` son días de **navegación** dentro de la ventana de liquidación; `DIAS_MAREA` = proyecto + puerto ([[Tabla - Variable Sistema Liq]]). El efecto de desactivar (sólo las activas entran al universo de nombres conocidos) no se verificó en runtime |
| Concepto Liquidación | `Activo`, `Aplica Tipo Liq.` (uno) | `Activo` **sin efecto** (baja = `Vigencia Hasta`); `Aplica Tipo Liq.` obsoleto → `Tipos Liq. Aplicables` (multi, vacío = comodín); nuevos: `Par CCT a Usar`, `Rol Franco`, valuación de lotes, `Grupo Costo Laboral` ([[Tabla - Concepto Liquidación]]) |
| Concepto CCT Vigente | PK `Cód. Concepto + Vigencia + Cód. Convenio`; para sumar un CCT hay que repetir todas las filas de la vigencia anterior | PK incluye `Cód. Categoría`; existe `Excluye`; el versionado es **por convenio** y una vigencia nueva **no revoca** lo que no menciona ([[Tabla - Concepto CCT Vigente]]) |
| Fracción Acumulador | `Acumulador += Importe × % / 100` | Además `Invertir Signo` y vigencia propia auditada en `Vigencias Distribución` ([[Tabla - Fracción Acumulador]]) |
| Tabla Escalonada Det. | Campo `Nro. Tramo`; "recorre los tramos de menor a mayor"; acción **Nueva Vigencia** | Campo `No. Tramo`; la búsqueda filtra `Límite Inferior <= valor` y `Límite Superior = 0 \| >= valor` y toma el `FindLast`; la acción Nueva Vigencia no se verificó ([[Tabla - Tabla Escalonada Detalle]]) |
| Fuente Datos Liquidación | Hasta **3** pares de filtro; funciones SUM/COUNT/MAX/MIN/LOOKUP; 5 tokens; `{COD_CONCEPTO}` | Filtros **ilimitados** en [[Tabla - Filtro Fuente Datos Liq]]; 8 funciones (+ `DIAS_OVERLAP`, `DURACION_INICIO`, `DURACION_AÑO`); 13 tokens; no hay token `{COD_CONCEPTO}` (el concepto va como literal); `Tipo Dato` y `Fin Efectivo` ([[Tabla - Fuente Datos Liquidación]]) |
| Cód. Estado Empleado | `Tipo Empleado` del **código de estado** filtra `Aplica A` | El tipo de empleado sale del **convenio** de la persona; las banderas reales son `Devenga Francos`, `Transcurre en Marea`, `Promedia Ausencia`, `Estado Siguiente` ([[Tabla - Cód. Estado Empleado]]) |
| Estado Empleado | PK `No. Empleado + Fecha Desde`; *append-only*, "nunca modificar"; si no hay estado falla el **cálculo** | PK `No. Mov.`; `Fecha Inicio`/`Fecha Fin`; historial contiguo que **se modifica** (empuja al siguiente); sirve a empleados y buques; exige fase de alta **al cargar** el estado ([[Tabla - Estado Empleado]]) |
| Período Liquidación | `Fecha Hasta` es *siempre* la fecha de referencia; el cierre impide calcular | En Cierre de Marea la referencia es el arribo; la tabla sólo impide **borrar** un período cerrado; el bloqueo de cálculo está en `Cod50014.MotorLiquidacion` (línea ~102) y `Cod50018.ProcesoLiqPorLotes`, que rechazan períodos Cerrados ([[Tabla - Período Liquidación]]) |
| Liquidación | Estados Borrador/Calculada/Aprobada; "una liquidación aprobada no puede reabrirse" | Hay 4 estados (+ **Contabilizada**) y existen `Reabrir`, `PuedeReabrir` (no si hay liquidaciones posteriores) y `RevertirAprobacion` en `Cod50019` ([[Enums de liquidación]]); 7 tipos fijos de la guía → tipos configurables ([[Tabla - Tipo Liquidación]]); `Cobertura Desde/Hasta`, `No. Liq. Origen`, `Haberes Ordinarios Gravados` ([[Tabla - Liquidación]]) |
| Línea Liquidación | `Fuente Parámetros` con `VAR:nombre` y `TRAMO:código\|fecha` | `Fuente Parámetros` es `PARAM\|FECHA`; el detalle de tramo va en [[Tabla - Detalle Variable Línea Liq]] (snapshot); el importe tiene **signo propio** ([[Tabla - Línea Liquidación]]) |
| Incidencia Liquidación | PK y filtros `{LIQ_NO}` y `{COD_CONCEPTO}`; sólo importe y observaciones | + `Cantidad`, `Valor Unitario`, `Cód. Cuota Préstamo`, `Desde Novedad` ([[Tabla - Incidencia Liquidación]]) |
| Ded. Ganancias Vigente/Empleado | Sólo describen familiares por tipo | Los familiares se leen de `Employee Relative` con `Cód. Tipo Ded.` apuntando a un **Parámetro** ([[Extensión - Employee Relative]], [[familiar-alta-impuesto]]) |

Tablas que la guía **no** menciona: `Cuota Préstamo`/`Préstamo Empleado`, `Tipo Liquidación`, `Filtro Fuente Datos Liq.`, `Resumen Variable Liq.`, `Detalle Ganancias Liq.`, `Detalle Acumulador Liq.`, `Importación SIRADIG`, `Cue SIRADIG` y las siete TableExtensions.
