---
tipo: pagina
tags: [ui, asistente, formulas, detalle-calculo, diagnostico]
fuente: [src/Pages/Pag50139.AsistenteFormulaLiq.al, src/Pages/Pag50140.VariablesLiqTestSub.al, src/Pages/Pag50145.ConceptoLiqCard.al, src/Pages/Pag50118.LineasLiquidacion.al, src/Pages/Pag110046.DetalleCalculoLinea.al, src/Codeunits/Cod110044.DetalleCalculoLinea.al, src/Codeunits/Cod110055.PresentacionCalculoLiq.al, src/ControlAddIns/EditorFormula/editorFormula.js]
actualizado: 2026-10-04
---

# Asistente de fórmulas y detalle del cálculo

Dos herramientas que responden preguntas distintas:

| Pregunta | Herramienta |
|---|---|
| "¿Qué daría esta fórmula **si la calculara ahora** con este empleado y período?" (antes de guardar) | **Asistente de Fórmulas** |
| "¿**Por qué** esta línea ya liquidada dio este importe?" | **Detalle del cálculo** (y *Variables del cálculo*) |

## Asistente de Fórmulas (Pag50139)

**Cómo abrirlo:** Role Center → Herramientas → *Asistente de Fórmulas* (en blanco), o desde la ficha de un concepto → **Asistente de Formulación** (viene con la fórmula y condición cargadas y aparece **Aplicar y Cerrar**). Al abrirse **carga solo** el catálogo (y, si ya hay empleado + período, el contexto real): sin variables cargadas no podría validar ni autocompletar.

### Contexto de prueba

| Campo | Qué hace |
|---|---|
| **No. Empleado** | Al completarlo trae su convenio y categoría **de la ficha del empleado** y recarga el contexto |
| **Período** | Se propone el que contiene la fecha de trabajo |
| **Cód. Convenio** / **Cód. Categoría** | Se completan solos; cambiarlos a mano **simula otra escala** (parámetros por convenio/categoría). **Ojo:** el motor real resuelve el par desde los **atributos** del empleado a la fecha de referencia (la ficha es sólo el respaldo); si difieren, el asistente simula con el par de la ficha. Corregirlo a mano o comparar contra la línea real |
| **Tipo Liquidación** | Con un tipo de disparador *Arribo* (Cierre Marea), la fecha de referencia pasa a ser el **arribo del proyecto**, como en el motor |
| **No. Proyecto (Marea)** | Necesario para variables del viaje (`DIAS_PROYECTO`, `DIAS_PUERTO`, fuentes con `{JOB_NO}`). El tooltip dice que trae convenio y categoría de la asignación; `Personal Proyecto` ya no los guarda |

### Fórmula y resultado

- **Editor con IntelliSense** (add-in `Editor Fórmula Liq.`): resalta funciones, variables, operadores y números; subraya en rojo lo que el motor **no** entendería (su tokenizador es un espejo del de AL); autocompleta con **Ctrl+Espacio**; en una comparación de atributo (`CONVENIO = `) propone los valores configurados ([[atributo-comparar-por-codigo]]). Evalúa de verdad contra el contexto y muestra resultado o error en la barra inferior (con *debounce*, no en cada tecla).
- **Resultado**: **Importe calculado**, **Condición activa** y **Mensaje** (el error del evaluador si lo hay).
- **Variables (doble clic = insertar en fórmula)**: lista con *Tipo, Nombre, Valor, Descripción*; se filtra por texto y categoría. **El Valor es editable**: tocar un número para ver cómo reacciona la fórmula no modifica ningún dato real.

### Acciones

| Acción | Efecto |
|---|---|
| **Cargar catálogo completo** | Todas las variables disponibles (parámetros con *Nombre Variable*, variables de sistema, fuentes, acumuladores) leídas de las tablas reales. Los valores son **orientativos** (0, salvo parámetros con convenio/categoría) |
| **Cargar contexto completo** | Los valores **reales del motor** para ese empleado y período, incluyendo fuentes (`DIAS_VAC`, `INCID_*`…). Pide empleado y período |
| **Evaluar** | Evalúa fórmula y condición con los valores de prueba |
| **Aplicar y Cerrar** | Vuelca fórmula y condición al concepto que lo abrió. **Cerrar con la X / Esc no modifica el concepto** |
| **Ver texto plano** / **Auto-completar** | Cajas de texto comunes, para copiar/pegar o si el editor no cargara |
| **Insertar → Funciones** | `ABS, ROUND, MAX, MIN, REDONDEAR, PISO, TECHO, IF, IFZERO, DIV, TRAMO` y operadores `AND, OR, NOT` |

> [!tip] Errores típicos que el asistente muestra
> *Variable desconocida* (nombre mal escrito o el parámetro/fuente no está activo: recordar que **las variables distinguen mayúsculas**), *Función desconocida*, *División por cero*, *Referencia circular* con `@`, *No se encontró la tabla escalonada "X" vigente al …*. Un parámetro **sin vigencia para ese convenio/categoría vale 0 sin error**: cargar el contexto completo del empleado antes de probar.

> [!note] Si el editor aparece en blanco
> En la ficha del concepto: **Reiniciar editor** (devuelve los campos de texto plano y le pide a BC que rearme el control). Si sigue vacío, el problema está en los archivos del add-in: recargar con **Ctrl+F5** (saltea el caché del navegador). Ver [[Resolución de problemas frecuentes]].

## Detalle del cálculo de una línea

Se llega desde la **Ficha Liquidación** → subpágina **Líneas Liquidación** → seleccionar la línea → **Detalle del cálculo**.

Re-evalúa la **fórmula guardada en la línea** (`Fórmula Aplicada`) con los **valores guardados** (`Detalle Variable Línea Liq.`), **no** con la fórmula ni los datos de hoy: explica el número del recibo, no el que saldría si se recalculara. Por eso, si cambió una fórmula o un parámetro desde entonces, el detalle sigue siendo fiel.

La página cambia según la línea:

| Línea | Qué se ve |
|---|---|
| **Concepto común** | *Resultado de la liquidación* (concepto, **importe guardado**, **Comprobación**), *Cómo se aplicó la fórmula* (**fórmula utilizada** y **la misma fórmula con los valores**), *Datos utilizados* y *Desarrollo y resultado* (cada suma/resta paso a paso con subtotales) |
| **Ganancias 4.ª categoría** | Tres bloques: *1. Formación de la base imponible*, *2. Aplicación de la escala*, *3. Retención de esta liquidación*; acción **Desglose de deducciones** (las deducciones **guardadas al liquidar**) |
| **Concepto de franco con Rol "Consumo"** | En lugar de lo anterior abre **Lotes de franco consumidos**: de qué lote FIFO salió cada día y a qué categoría se valuó |
| **Devengo de franco** | Días devengados, convenio y categoría **de origen** |

**Comprobación** — el control final: compara lo reconstruido contra el importe guardado. Dice *"Coincide con el importe de la línea"* o *"NO COINCIDE con el importe de la línea (X). Revisar ajustes, incidencias y redondeo"* (típico cuando una **incidencia/novedad** reemplazó la fórmula, o el grossing-up iteró). Una línea sin fórmula guardada muestra "nada que explicar".

> [!note] Para que el detalle de Ganancias aparezca por etapas
> La página reconoce la línea de Ganancias por la **escala `TAB_IMP_4CAT`** en la fórmula, por un paso guardado, o porque el concepto tiene *Etiqueta Det. Ganancias*. Una escala con **otro nombre** de código no se presenta por etapas.

### Otras vistas de la línea

| Acción (en *Líneas Liquidación*) | Para qué |
|---|---|
| **Variables del cálculo** | Variables que usó **esa** línea y su valor (sólo las que la fórmula o la condición leyeron) |
| **Detalle Acumulador** | Si la variable es un acumulador: qué conceptos lo alimentaron y cuánto aportó cada uno (separa *aportes que suman* de *que restan*) |
| **Abrir Concepto** | La ficha en la **vigencia que se usó** en esa línea |
| **Abrir con Variables** | Lista completa con el panel de variables al costado |

Columnas útiles de la línea: **Fórmula Evaluada** (con los valores sustituidos), **Fuente Parámetros** (`VAR:…`, `TRAMO:…`), **Vigencias Distribución** (qué fracción se usó por acumulador; sirve para detectar si una fracción cargada con fecha retroactiva cambiaría un recálculo), **Vigencia Concepto**.

> [!warning] El detalle de un acumulador es el de **ahora**
> El *Detalle Acumulador* se recalcula al final con **todas** las líneas, así que muestra el acumulador completo aunque un concepto lo haya leído **antes** de que todos aportaran. Si el valor que leyó la línea no coincide con la suma del detalle, es un problema de **orden de cálculo** ([[acumuladores-orden-calculo]]).

## Relacionado

[[Configurar un concepto (guía paso a paso)]] · [[Controles y avisos del cálculo]] · [[Crear, calcular, aprobar y reabrir liquidaciones]] · [[Tabla - Línea Liquidación]] · [[grossing-up-tapa-errores]]

## Ver también

[[Detalle del cálculo y trazabilidad]] · [[Editor de fórmulas]] · [[Evaluador de fórmulas - sintaxis]] · [[Contexto de liquidación y variables]]
