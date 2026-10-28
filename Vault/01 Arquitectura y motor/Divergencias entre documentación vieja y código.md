---
tipo: referencia
tags: [motor, divergencias, documentacion]
fuente: [GUIA-LIQUIDACION.md, GROSSING_UP_Y_TC_CONFIGURABLES.md, PROPUESTA_TOPE_SIPA_PERIODO.md, REVISION_RENDIMIENTO_2026-09-18.md, src/Codeunits/Cod50015.EvaluadorFormula.al, src/Codeunits/Cod50016.ContextoLiquidacion.al, src/Codeunits/Cod50014.MotorLiquidacion.al]
actualizado: 2026-10-21
---

# Divergencias entre documentación vieja y código

Regla del vault: **manda el código**. Esta nota lista dónde los documentos de la raíz, los comentarios y
algunas lecciones **no coinciden** con lo que el código hace al 4/10/2026, para que nadie los siga al pie
de la letra. Cada fila nombra la nota del vault que describe el comportamiento real.

## `GUIA-LIQUIDACION.md` (la más desactualizada)

| La guía dice | El código hace | Ver |
|---|---|---|
| "Separador decimal: siempre **coma** (`0,11`, `ROUND(x, 0,01)`)" | el decimal es el **punto**; la **coma separa argumentos** (`0,11` son dos argumentos) | [[Evaluador de fórmulas - sintaxis]] |
| `Función Agregado`: `First` o `Sum` | `SUM`, `COUNT`, `MAX`, `MIN`, `LOOKUP`, `DIAS_OVERLAP`, `DURACION_INICIO`, `DURACION_AÑO` | [[Fuentes de datos]] |
| Fuente con `No. Filtro 1/2/3` y `Filtro Valor 1/2/3` | obsoletos; los filtros viven en `Filtro Fuente Datos Liq.` (ilimitados) y, si hay alguno, los tres viejos **no se aplican** | [[Fuentes de datos]] |
| Tokens: `{JOB_NO}`, `{EMP_NO}`, `{PERIODO}`, `{FECHA_REF}`, `{LIQ_NO}` | 20 tokens (`{BUQUE}`, `{PERIODO_DESDE}`, `{ASIG_*}`, `{MAREA_*}`, `{AÑO_DESDE}`, `{SEM_*}`, `{PROM_*}`, `{AUS_PROM*}`, `{MONEDA}`…) | [[Tokens de filtro de fuentes de datos]] |
| Funciones: `TRAMO`, `ROUND`, `ABS`, `MIN`/`MAX`, `IF` | además `REDONDEAR`, `PISO`, `TECHO`, `IFZERO`, `CASE`, `DIV` | [[Evaluador de fórmulas - funciones]] |
| "Operadores lógicos **solo en el campo Condición**" | `AND`/`OR`/`NOT` y los comparadores funcionan en **cualquier** fórmula (los booleanos son 0/1) | [[Evaluador de fórmulas - sintaxis]] |
| "Un concepto calculado se referencia por su código: `1003 * 0,5`" | `1003` es un **número**; la referencia es **`#1003`** (importe ya calculado) o **`@1003`** (re-evalúa) | [[Evaluador de fórmulas - sintaxis]] |
| `Tipo Concepto` "define cómo se clasifica **y acumula** el importe" | sólo clasifica (totales, recibo); acumular depende **únicamente** de `Fracción Acumulador` | [[Tipos de concepto y su efecto en el recibo]] |
| Campo `Activo` "desactivar para excluir sin borrar" | obsoleto y **sin efecto**; la baja es `Vigencia Hasta` | [[Versionado de conceptos y fórmulas]] |
| `Aplica A`: "Todos / **Embarcado** / Mensualizado / Jornalizado" | `Todos`, `Tripulante`, `Mensualizado`, `Jornalizado` | [[Aplicabilidad de un concepto a una liquidación]] |
| `Aplica Tipo Liq.` (un valor) | obsoleto; `Tipos Liq. Aplicables` (lista con `\|`) + `Sólo Conceptos Declarados` del tipo; vacío = comodín | [[Aplicabilidad de un concepto a una liquidación]] |
| Variables del sistema `ANIOS_ANTIGUEDAD`, `DIAS_MAR` | `AÑOS_ANTIGUEDAD` (con Ñ), `DIAS_PROYECTO`/`DIAS_MAREA`; hay 33 códigos | [[Variables de sistema]] |
| Acumuladores "por defecto": `BASE_SS`, `BASE_OS`… | `BASE_SS`/`BASE_OS` fueron **borrados** y siguen recibiendo fracciones huérfanas; los vivos son `BASE_SS_TRAB`, `BASE_OS_TRAB`… (son datos, no del motor) | [[Acumuladores y fracciones]], [[Tope SIPA]] |
| "Nueva Vigencia crea una copia con **fecha de hoy**" | pide una fecha en un diálogo | [[Versionado de conceptos y fórmulas]] |
| Incidencias: "el importe queda disponible con `{LIQ_NO}`… Fuente de Datos sobre la tabla" | el motor **lee las incidencias directamente**; hay tres modos (importe, cantidad, cero explícito) y `CANT_INCIDENCIA` | [[Incidencias en el motor]] |
| Rango de órdenes recomendado (`1–99`, …, `900–929`, `999`) | es una recomendación; el orden real es dato y varios conceptos están fuera de rango | [[Orden de cálculo y precedencia]] |

## `GROSSING_UP_Y_TC_CONFIGURABLES.md` (4/10/2026)

- Es un **diseño para revisar**, no una descripción: nada de lo propuesto está implementado (no existe `Cód. Variable TC` en `Parámetro Vigente` ni los campos nuevos en `Config. RRHH`). Ver [[Grossing-up y tipo de cambio]].
- Sus referencias de línea (`Cod50014:2289`, `Cod50016:430`, `Cod50016:153-155`) **siguen coincidiendo** con el código actual; la del comentario de `LoadAtributos` ("`Cod50016:2153`") se corrió unas líneas.

## `PROPUESTA_TOPE_SIPA_PERIODO.md`

- Propuesta de configuración; **no verificable desde el repo** si se aplicó. Ver [[Tope SIPA]].
- Su punto 7 ("el motor fija por nombre `DIAS_VAC_INICIO`, `NETO_GU` y `BASE_IG4`") **ya no es cierto**: el neto garantizado sale del concepto configurado en `Config. RRHH`, los haberes gravados del acumulador configurado, y `DIAS_VAC_INICIO` desapareció. Las referencias `Cod50014:1791-1793`, `1756-1759`, `198-199`, `1745` ya no apuntan a eso.

## `REVISION_RENDIMIENTO_2026-09-18.md`

- Las propuestas 1 (fin efectivo) y 2 (incidencias, par del puesto, aplicabilidad CCT) **ya están hechas**; las referencias de línea se corrieron.
- Dice que, si el grossing-up no converge, el bloque "termina sin un error explícito": **hoy corta con `ErrGUNoConverge`** y tiene rescate por escalón de redondeo.
- Ver [[Rendimiento y caché del cálculo]] para el estado actual.

## Lecciones de `07 Lecciones` que quedaron atrás

| Lección | Qué cambió |
|---|---|
| [[dia-de-puerto-no-estira-la-marea]], [[ventana-liquidacion-es-cobertura]] | Corregidas el 21/10/2026: fuera del viaje el helper usa `Transcurre en Marea` sin distinguir códigos ni exigir el predeterminado del proyecto. El puerto posterior puede superar la fecha de valoración dentro de cobertura; TC, fuentes y viaje conservan su fecha y alcance. |
| [[tipo-liq-no-implementada]] | **Resuelta el 11/10/2026.** La nota se reescribió: `TIPO_LIQ` existe, y además se compara por código (`TIPO_LIQ = LIQ_FINAL`) |
| [[variables-rotas-valen-cero]] | `AÑOS_ANTIG_30JUN`, `MESES_PROM_AUS_6` y `MESES_PROM_AUS_12` **tienen `case`** en el motor; si valen 0, revisar el `Cód. Cálculo` cargado en la fila |
| [[acumuladores-orden-calculo]] | el importe de la línea **ya no pasa por `Abs`**: lleva su signo; el flag es `Invertir Signo`, no `Restar` |
| [[que-tc-usa-cada-concepto]], [[oficiales-netos-al-70]] | hablan de `NETO_GU` como parámetro: hoy el objetivo es la fórmula del concepto de `Config. RRHH."Cód. Concepto Neto Garantizado"` |
| [[atributo-comparar-por-codigo]] | las referencias de línea (`Cod50015:247`, `Cod50016:2185`) se corrieron |

## Comentarios y ayudas del propio código que no coinciden

| Dónde | Qué dice | Qué pasa |
|---|---|---|
| Cabecera de `Cod50015` | "Built-in functions: TRAMO(code, value)" | hay 12 funciones |
| `editorFormula.js` (cabecera) | "el motor distingue mayúsculas: 'basico' NO es 'BASICO'" | el evaluador pasa la fórmula a **mayúsculas**; los comentarios de `clasificar` ya lo reconocen |
| Ayuda de `AND`/`OR`/`NOT` en el catálogo | "debe escribirse en mayúsculas" | funcionan también en minúsculas |
| `Tab60015` / `Tab60029` (comentarios) | 4 y 13 tokens | 20 |
| `Tab60018` (comentario de `YTD_ACUM`) | "`Invertir Signo` = false" | el código también resta las fracciones con `Invertir Signo` |
| `Tab60018` (`Opciones` del lookup) y `Cod50077.Sembrar` | espejo de los códigos | `DIAS_MES` falta en las dos; `MESES_PROM_AUS_6/12`, `DIAS_ESTADO_PERIODO` y `DIAS_ESTADO_PREVIOS` faltan en `Opciones` |
| Cabecera y comentarios de `Cod50014` | las cachés se reutilizan entre empleados del lote | cada `LiquidarConRegistro` crea su propio `Motor` en `Ejecutor Liquidación` |
| `Lotes Liquidación Liq.`.`Calcular` (`summary`) | "Borrador, Calculada o Aprobada" | el cuerpo sólo calcula `Borrador` |
| `Concepto Liquidación.BuildKnownVarsCtx` (pasada 2 de la validación de la ficha) | arma "todas las variables configuradas" | **no incluye los tipos de atributo**: usar una variable de atributo en el campo `Fórmula` muestra el `Message` "variables que no existen" aunque exista. (El editor con IntelliSense no pasa por ese trigger) |
| `NETO_GARANTIZADO_ESFCY` | está en el catálogo del editor y en `BuildKnownVarsCtx` | el motor no la siembra |
| `AvisarCodigoDesconocido` | separa avisos con `''` | los demás usan `'\'`: los mensajes salen pegados |
| `Cod50018.ProcesoLiqPorLotes.al` / `Cod50060.CatalogoVariablesLiq.al` | nombre de archivo | declaran `codeunit 50050` y `codeunit 50064` |
| `Evaluador.SeedConceptoRef` | pensada para el detalle de cálculo | nadie la llama |
| `MESES_PROM_VAC` | — | arma una fórmula de fecha con `StrSubstNo('<+%1M>', i)`, patrón que la versión de ausencia evita a propósito (literales) |

> [!tip] Cómo mantener esta nota
> Cuando se corrija una divergencia (en el código o en el documento), **sacarla de acá** y actualizar la
> nota del vault que la describe. Si aparece una nueva, agregarla con la nota que tiene la versión correcta.

## Relacionado

[[Índice Arquitectura y motor]] · [[Visión general de la arquitectura]]
