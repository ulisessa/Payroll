---
tipo: referencia
tags: [paginas, subpaginas, dialogos, ui]
fuente: [src/Pages]
actualizado: 2026-10-04
---

# Mapa de páginas auxiliares y subpáginas

Complemento de [[Mapa de páginas por menú]]: acá están las páginas que **no** tienen entrada de menú (fichas, subpáginas, FactBoxes, diálogos, listas de apoyo). Las ordenamos por la pantalla desde la que se las ve.

## Alrededor de la liquidación

| Caption | ID | Rol | Desde |
|---|---|---|---|
| **Liquidación** (Ficha Liquidación) | 50117 | Ficha: cabecera, totales y todas las subpáginas de abajo; acciones Calcular, Recalcular en cadena, Aprobar, Reabrir, Revertir aprobación, Imprimir recibo, Registros de proceso, Novedades del período | Lista, Árbol, Personal Proyecto |
| **Líneas Liquidación** | 50118 | Subpágina con una fila por concepto calculado; filtros *importes cero / no imprimibles / acumuladores* | Ficha |
| **Días que cubre** (Tramos Cobertura Sub) | 110055 | Los tramos de fechas que cubre la liquidación | Ficha |
| **Acumuladores** (Acumuladores Liq. Sub) | 50175 | Líneas de tipo Informativo (acumuladores) | Ficha |
| **Contexto del Cálculo** (Resumen Variable Liq. Sub) | 50177 | Variables del contexto con valor (incluye las marcadas *Mostrar en Recibo*) | Ficha |
| **Incidencias** (Incidencias Liquidación Sub) | 50148 | Importes manuales; editable sólo en Borrador | Ficha |
| **Novedades aplicadas** (Novedades Liq. Sub) | 110027 | Novedades que entraron; acción *Abrir hoja de novedades* | Ficha |
| **Variables del Cálculo** (Detalle Variable Línea Sub) | 50156 | FactBox: variables y valores de la línea elegida | Ficha, Líneas con variables |
| **Líneas de Liquidación** (Líneas Liq. con Variables) | 50170 | Vista completa con el panel de variables | Líneas → *Abrir con Variables* |
| **Detalle del cálculo** | 110046 | Explica una línea (Ganancias por etapas, francos por lotes, fórmula con valores) | Líneas → *Detalle del cálculo* |
| **Pasos Cálculo Sub** | 110057 | Filas de cada bloque del detalle | Detalle del cálculo |
| **Deducciones guardadas al liquidar** (Deducciones Aplicadas Liq.) | 110058 | Desglose de deducciones de Ganancias | Detalle del cálculo → *Desglose de deducciones* |
| **Lotes de franco consumidos** | 110054 | Lotes FIFO que pagó un concepto de consumo | Detalle del cálculo |
| **Variables del Cálculo** (Variables Cálculo Línea) | 50159 | Lista de variables de una línea; *Detalle Acumulador* | Líneas → *Variables del cálculo* |
| **Detalle Acumulador** | 50174 | Qué conceptos aportaron al acumulador y cuánto | Líneas / Variables |
| **Registro de Proceso** (Ficha) | 110003 | Ficha de un registro | Registros de Proceso |
| **Detalle del proceso** (Entradas Registro Liq. / Sub) | 110002 / 110001 | Entradas con severidad, categoría, concepto y variable | Registros de Proceso → *Ver detalle* |
| **Cambio de Fórmula** (Ficha Cambio Fórmula) | 110005 | Texto anterior y nuevo lado a lado; *Restaurar* | Historial de Fórmulas |
| **Selector Tipos Liq.** | 50176 | Diálogo para elegir los tipos de un concepto | Ficha del concepto → campo *Aplica a Tipo Liq.* |

## Alrededor del concepto

| Caption | ID | Rol |
|---|---|---|
| **Concepto Liquidación** (Concepto Liq. Card) | 50145 | Ficha del concepto: ver [[Configurar un concepto (guía paso a paso)]] |
| **Distribución en acumuladores** (Fracción Acumulador Sub) | 50144 | Fracciones por acumulador, con *Vigente* e *Invertir Signo* |
| **Conceptos que alimentan este acumulador** (Alimentadores Acumulador Sub) | **50157** | Para conceptos `Es Acumulador`; *el archivo se llama `Pag50148` pero el objeto declara el ID 50157* |
| **Convenios Aplicables** (Concepto CCT Sub) | 50147 | Restricción por convenio/categoría y *Excluye*; *Nueva Vigencia* |
| **Concepto CCT Vigente (todas las vigencias)** | 50197 | Lista plana de todas las vigencias de restricción CCT |
| **Copiar conceptos a otro convenio** | 50077 | Diálogo de *Conceptos por Convenio* |
| **Conceptos / Convenios / Tipos** (Conceptos Convenio Sub, Conceptos Selección Sub, Convenio Selección Sub, Conceptos Tipo Liq. Sub, Tipo Liq. Selección Sub) | 50073, 50075, 50198, 50194, 50196 | Listas "disponibles / asignados" de los tres asignadores masivos |
| **Nueva Vigencia** | 50183 | Diálogo que pide la fecha |
| **Copiar como...** (Nuevo Codigo Dialog) | 50179 | Diálogo para duplicar concepto, parámetro o fuente de datos con otro código |
| **Variables de prueba** (Variables Liq. Test Sub) | 50140 | Variables del Asistente de Fórmulas (doble clic = insertar) |
| **Acumuladores disponibles** (FactBox) | 50158 | FactBox de *Variables Sistema* |

## Parámetros, fuentes y tablas

| Caption | ID | Rol |
|---|---|---|
| **Parámetro** (Parámetro Card) | 50138 | Ficha con *Valores por alcance* — [[Configurar un parámetro y su vigencia]] |
| **Valores por alcance** (Parámetro Sufijo Sub) | 50153 | Subpágina de la ficha; *Nuevo valor...*, *Nueva vigencia* |
| **Valores Vigentes** (Parámetro Vigente Subpag) | 50137 | Subpágina clásica con *Nuevo Valor* |
| **Valor de Parámetro** (Ficha Valor Parámetro) | 110014 | Ficha de un valor con su alcance |
| **Claves de parámetro a revisar** | 110016 | Valores cuya clave derivada no coincide con su alcance; *Aplicar interpretación* |
| **Fuente de Datos de Liquidación** (Fuente Datos Card) | 50141 | Ficha — [[Configurar fuentes de datos]] |
| **Filtros** (Filtro Fuente Datos Liq. Sub) | 50178 | Filtros de la fuente |
| **Seleccionar Tabla / Seleccionar Campo** | 50142 / 50143 | Lookups de tabla y campo |
| **Tabla Escalonada** (Card) y **Tramos** (Det. Sub) | 50132 / 50133 | Ficha y tramos |
| **Tipo Deducción Ganancias** y **Deducciones Ganancias** | 50151 / 50152 | Ficha de la tabla AFIP; subpágina por empleado con *Nueva Declaración* |

## Atributos, entidades, estados y personal

| Caption | ID | Rol |
|---|---|---|
| **Tipo de Atributo** y **Valores permitidos** | 110008 / 110009 | Ficha y subpágina |
| **Entidad** (Ficha Entidad) | 110019 | Ficha con *Aplicar plantilla de atributos* e *Historial de estados* |
| **Atributos** (Atributos Entidad FactBox / Sub) | 110012 / 110030 | En la ficha del empleado y de la entidad |
| **Historial de Estados** (Estados Empleado Sub) | 110031 | En la ficha del empleado; acción *Fases de Alta* |
| **Fases de Alta** (List y Fases Alta Empleado Sub) | 110028 / 110044 | Alta y baja apareadas, días por fase y antigüedad a una fecha |
| **Estado Empleado** (FactBox) | 50136 | Estado vigente en la ficha del empleado |
| **Establecer Nuevo Estado** | 50135 | Diálogo del empleado: nuevo estado y fecha de inicio |
| **Establecer Estado en Lote** | 50190 | Diálogo para entidades y empleados seleccionados |
| **Estados de Buque** | 50192 | Estados de las entidades buque |
| **Estados que lo justifican** (Estados Tipo Liq. Sub) | 110053 | Parte de *Tipos de Liquidación*: estados que habilitan el tipo |
| **Personal Proyecto** | 50109 | Parte del Job y del empleado; acción *Crear Liquidación* |
| **Lista / Ficha de Préstamos y Cuotas** | 50180 / 50181 / 50182 | Préstamos y anticipos; *Generar Cuotas*, *Anular Cuota*, *Reactivar Cuota* |

## Controles, Meta4, NAV y SIRADIG

| Caption | ID | Rol |
|---|---|---|
| **Resumen por concepto**, **Diferencias dentro de la misma categoría**, **Datos de cálculo de la marea** | 110020, 110021, 110023 | Partes de *Control de Liquidación por Marea / Período* |
| **Liquidación Meta4** (ficha), **Valores**, **Columnas de la Historia Meta4** | 110048, 110049, 110050 | Historia importada de Meta4 |
| **Qué explica la diferencia** (Detalle Comp. Meta4) | 110052 | Drill-down de *Comparar BC contra Meta4* |
| **Proyectos / Empleados / Descargas (Cab y Lín) / Valores de dimensión / Informes del capitán (Cab y Lin) / Diario de abordo (Cab y Lin) traídos de NAV** | 110033, 110034, 110035, 110036, 110038, 110040, 110041, 110042, 110043 | Filas en staging por entidad |
| **Configuración Sincronización NAV** y **Clave de acceso a web services** | 110037 / 110039 | Origen NAV y clave (se guarda en Isolated Storage) |
| **Carpeta SIRADIG** y **SIRADIG** (cue) | 50172 / 50173 | Diálogo de importación desde carpeta del servidor y tarjeta del Role Center |

Detalle de NAV en [[Sincronización NAV - visión general]]; de SIRADIG en [[Importación SIRADIG - operación]].

## Ver también

[[Objetos AL]] · [[Índice Dominio - empleado y condiciones]] · [[Índice Dominio - marea y pagos]]
