---
tipo: referencia
tags: [documentacion, discrepancias, guia-original, migracion-docs]
fuente: [GUIA-LIQUIDACION.md, COMIENZA_AQUI.md, README.md, RESUMEN_IMPLEMENTACION.txt, "Propuesta - Modulo Liquidacion de Haberes para BC - Versión HHRR.docx"]
actualizado: 2026-10-04
---

# Discrepancias de la guía original con el código

`GUIA-LIQUIDACION.md` (50 KB) fue la guía de uso del sistema. Se reestructuró en este manual **verificando cada afirmación contra el código** (2026-10-04). Esta nota registra **dónde la guía quedó desactualizada**, para que nadie la use como fuente. Regla del vault: **manda el código** ([[_Convenciones del vault]]).

## Dónde quedó cada sección de la guía

| Sección de `GUIA-LIQUIDACION.md` | Nota actual |
|---|---|
| Acceso y perfiles | [[Perfiles, Role Center y permisos]] |
| Conceptos fundamentales, tipos de concepto | [[Configurar un concepto (guía paso a paso)]] |
| Referencia de tablas (dominios) | Notas `Tabla - …` de `02 Modelo de datos` |
| Liquidaciones de marinería | [[Lanzador de liquidaciones y lotes]] |
| Configuración inicial | [[Configurar un parámetro y su vigencia]], [[Flujo operativo mensual de liquidación]] |
| Declaración de conceptos y fórmulas | [[Configurar un concepto (guía paso a paso)]] |
| Variables y funciones | [[Asistente de fórmulas y detalle del cálculo]], notas de `01 Arquitectura y motor` |
| Acumuladores y Fracción Acumulador | [[Configurar un concepto (guía paso a paso)]] §4, [[acumuladores-orden-calculo]] |
| Tablas escalonadas | [[Ejemplos completos de conceptos]] |
| Gestión de versiones | [[Configurar un concepto (guía paso a paso)]] §7, [[conceptos-tres-vigencias]] |
| Fuentes de datos dinámicas | [[Configurar fuentes de datos]] |
| Incidencias manuales | [[Novedades e incidencias - carga operativa]] |
| Flujo operativo | [[Flujo operativo mensual de liquidación]] |
| Ejemplos completos | [[Ejemplos completos de conceptos]] |
| Resolución de problemas | [[Resolución de problemas frecuentes]] |

## Lo que la guía dice y el código contradice

| # | La guía dice | El código hace | Impacto |
|---|---|---|---|
| 1 | **Decimales con coma** en fórmulas (`0,11`, `ROUND(x, 0,01)`) y "siempre coma" | **Punto** decimal; la coma **separa argumentos** (`0,11` se parte en dos argumentos y falla al validar) | **Alto**: copiar un ejemplo de la guía rompe la fórmula |
| 2 | Un concepto calculado antes se referencia por su código pelado (`1003 * 0,5`) | `1003` es un número. Referencias: **`@1003`** (re-evalúa con el par del que llama) y **`#1003`** (importe ya calculado) | Alto |
| 3 | Parámetro con check **"Sufijo CCT"** y clave `BASICO_729/15_MR00` | Sufijos **obsoletos**. Clave derivada de los campos de **alcance** del valor (empleado → convenio+categoría → convenio → base) | Alto |
| 4 | Variable `ANIOS_ANTIGUEDAD`; `DIAS_PROYECTO` mapeado a `DIAS_MAR`; 4-5 variables de sistema | **`AÑOS_ANTIGUEDAD`** (con Ñ); `DIAS_PROYECTO`, `DIAS_PUERTO`, `DIAS_MAREA`…; el catálogo sembrado tiene unas 30 variables | Alto: los ejemplos con `DIAS_MAR` no son del catálogo sembrado |
| 5 | Concepto con **`Activo`** para desactivar | `Activo` **sin efecto**; baja por **Vigencia Hasta**. Las versiones con `Activo = false` **ahora calculan** | Alto |
| 6 | **Aplica Tipo Liq.** de un solo valor; enum de tipos fijo (Regular, Aguinaldo, Vacaciones, Final, Reliquidación, Devengados, Cierre Marea) | Tabla **`Tipo Liquidación`** con **Disparador**, **Meses**, **Estados que lo justifican**, **Aplica a**, **Entra en corrida**; el concepto tiene **Tipos Liq. Aplicables** (multi-selección; vacío = todos) | Alto |
| 7 | **Aplica A** = Todos / **Embarcado** / Mensualizado / Jornalizado | Valores: Todos / **Tripulante** / Mensualizado / Jornalizado | Medio |
| 8 | Fuente de Datos: **3 pares** campo/valor; función **First** o **Sum**; 5 tokens | Filtros ilimitados en `Filtro Fuente Datos Liq.`; 8 funciones (Suma, Cantidad, Máximo, Mínimo, Búsqueda directa, Días solapados, Duración desde inicio, Duración en el año); **~20 tokens** | Alto |
| 9 | Una liquidación **aprobada no puede reabrirse** | **Revertir Aprobación** (Aprobada → Calculada) y luego Reabrir | Alto |
| 10 | El cierre de período es **irreversible** | Acción **Reabrir Período** (salvo que haya liquidaciones *Contabilizada*) | Medio |
| 11 | Lanzador con filtro de proyecto "Todos / Productivo / Improductivo" | Sólo **Período** y **Tipo**; el tipo de proyecto es un campo del *Tipo de Liquidación* | Medio |
| 12 | Lanzador / lotes calculan "Borrador o Calculada" | **Sólo Borrador** (tooltips aún dicen lo contrario) | Medio |
| 13 | **Personal Proyecto** guarda Cód. Convenio y Cód. Categoría; el motor los lee de ahí | `Personal Proyecto` **ya no** los tiene. El par sale de los **atributos del empleado** a la fecha de referencia; el concepto elige *El del empleado* o *El puesto del empleado* | Alto |
| 14 | Categoría CCT: `PCT_ESCALA = % Escala / 100` | Sigue; pero el par se resuelve por atributos | Bajo |
| 15 | **Concepto CCT Vigente** = (concepto, vigencia, convenio) | Además **Cód. Categoría** opcional y **Excluye** (una exclusión gana) | Medio |
| 16 | Incidencias se leen mediante una **Fuente de Datos** sobre la tabla de incidencias con `{LIQ_NO}` | El motor toma la **incidencia directamente** (importe reemplaza a la fórmula; cantidad la valoriza la fórmula vía `CANT_INCIDENCIA`), y existen **Novedades** que se materializan solas | Alto |
| 17 | Estado Empleado es **append-only**: "nunca modificar un estado existente" | El estado tiene **Fecha Fin mantenida** (acortar o alargar corre el siguiente) y se puede corregir, pero se **bloquea** si hay liquidaciones no revertidas del período; ver [[estado-empleado-effective-dated]] | Medio |
| 18 | Contribución patronal "no aparece en el recibo" | Aparece como costo laboral / aportes patronales (informativo) | Medio |
| 19 | Totales por acumuladores (`TOTAL_DESCUENTOS`, `TOTAL_CONTRIBUCIONES`) | Los totales de la cabecera se **suman por tipo de concepto** al final (`UpdateTotals`) | Medio |
| 20 | Los 14 acumuladores base "ya están creados" | No hay garantía: son conceptos de datos; verificar con *Control de Orden de Cálculo* y el catálogo del Asistente | Bajo |
| 21 | Orden de cálculo recomendado por rangos (1-99 haberes, 900-929 aportes…) | **No hay rangos impuestos**; en datos reales hay conceptos de adicionales en 195 y de "a cuenta" en 551. Lo único que manda: aportante < lector | Medio |
| 22 | Parámetros se actualizan insertando fila nueva; "En Uso" sólo es auditoría | `En Uso` **bloquea modificar y borrar** y el bloqueo es conservador (cualquier liquidación calculada) | Medio |
| 23 | Período con *Código* arbitrario | Código **`aaaamm`** generado de Año/Mes desde 26/9/2026 | Bajo |
| 24 | Recibo: un solo diseño | Dos diseños (*Decreto* predeterminado y clásico) que **no imprimen lo mismo** (variables "Mostrar en Recibo" sólo en el clásico) | Medio |
| 25 | Role Center del Director de TI = "IT Manager" | Extiende **`Administrator Role Center`** | Bajo |

## `COMIENZA_AQUI.md`, `README_SIRADIG.md` y compañía

Los nueve documentos SIRADIG de la raíz (fechados 11/6/2026) describen la **versión 1**: página 50161 (hoy **50171**), codeunits 50022-50025 (hoy 50046-50048 y 50058), importación sólo desde carpeta del servidor, "compilar con Ctrl+Shift+B en BC". Hoy: subida de archivos desde la PC y diálogo *¿Procesar automáticamente?*. Operación vigente en [[Importación SIRADIG - operación]].

`README.md` de la raíz sólo contiene la sección **"Comparar atributos por código"** (verificada: `CONVENIO = '729/15'`, ver [[atributo-comparar-por-codigo]]); `RESUMEN_IMPLEMENTACION.txt` es el resumen de la implementación de SIRADIG de junio.

## La propuesta comercial (`Propuesta - Modulo Liquidacion … HHRR.docx`)

Su alcance está recogido en [[Qué es y para qué sirve este sistema]]. Diferencias con el código: promete **asiento contable** y **Libro de Sueldos Digital** (no hay código para ninguno de los dos), "**sin interfaces**" (existen NAV y Meta4 de transición) y "**recibo en el formato de ley**" (hay dos diseños; el predeterminado omite algunos datos del clásico). Declara **fuera de alcance** firma digital, onboarding, legajo digital y gestión documental.

## Relacionado

[[Índice Interfaz y operación]] · [[Mapa de páginas por menú]] · [[Resolución de problemas frecuentes]]

## Ver también

[[Divergencias entre documentación vieja y código]] (versión por área técnica, en la carpeta 01 Arquitectura y motor)
