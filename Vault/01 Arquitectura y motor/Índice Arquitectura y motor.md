---
tipo: guia
tags: [motor, indice]
fuente: [src/Codeunits/Cod50014.MotorLiquidacion.al, src/Codeunits/Cod50015.EvaluadorFormula.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-04
---

# Índice Arquitectura y motor

Cómo calcula el motor paramétrico de liquidación: del diagrama de capas al detalle de cada pieza. Todas
las notas se verificaron contra el código el 4/10/2026; donde la documentación vieja difiere, manda el
código ([[Divergencias entre documentación vieja y código]]).

## Panorama

- [[Visión general de la arquitectura]] — capas, objetos principales, IDs (ojo con los nombres de archivo que no coinciden con el ID) y principios de diseño.
- [[Ciclo de cálculo de una liquidación]] — paso a paso real de `Motor Liquidación`: guardas, fase 1 (validación), fase 2, bucle de conceptos, cierre.
- [[Estados y transiciones de una liquidación]] — Borrador, Calculada, Aprobada, Contabilizada; aprobar, reabrir, revertir y qué libera cada una.
- [[Transaccionalidad y errores del cálculo]] — `Codeunit.Run` + `Commit`, ejecutor, registro de procesos, dónde corta el motor.

## El lenguaje de fórmulas

- [[Evaluador de fórmulas - sintaxis]] — gramática, precedencias, literales, `@` y `#`, comparación de atributos por código, modos del evaluador.
- [[Evaluador de fórmulas - funciones]] — las 12 funciones con firma, perezosas vs. eager y trampas.
- [[Formateador de fórmulas]] — forma canónica, garantía de no cambiar el cálculo, ancho y reglas.
- [[Editor de fórmulas]] — control add-in con IntelliSense: protocolo, catálogo, robustez y mantenimiento.

## Datos que alimentan las fórmulas

- [[Contexto de liquidación y variables]] — cómo se arma el diccionario, orden de resolución y qué gana si un nombre se repite.
- [[Variables de sistema]] — catálogo completo de `Cód. Cálculo` (33) con su lógica y la siembra.
- [[Parámetros y vigencias]] — cascada de claves por empleado/convenio/categoría, `_ESFCY`, `En Uso`, avisos.
- [[Fuentes de datos]] — agregados, tipos de dato, fin efectivo, filtros y sus trampas.
- [[Tokens de filtro de fuentes de datos]] — los 20 tokens `{...}` con su resolución exacta.
- [[Nombres de variables y conflictos]] — espacio de nombres plano y el control de unicidad.
- [[Tablas escalonadas]] — `TRAMO`, tramos, versionado y caché.

## Conceptos, orden y acumuladores

- [[Tipos de concepto y su efecto en el recibo]] — totales, neto, columnas del recibo, campos copiados a la línea.
- [[Aplicabilidad de un concepto a una liquidación]] — versión en uso, tipo de empleado, convenio/categoría (inclusiones y exclusiones), tipo de liquidación, condición.
- [[Par convenio-categoría por concepto]] — encuadre de la cabecera vs. par alterno por concepto.
- [[Incidencias en el motor]] — los tres modos de carga y qué pasa con las que no encuentran concepto.
- [[Acumuladores y fracciones]] — cómo se arman las bases y qué falla en silencio.
- [[Orden de cálculo y precedencia]] — `#` vs `@`, controles estático y en runtime, cómo corregir un orden.
- [[Versionado de conceptos y fórmulas]] — `Vigencia Desde/Hasta`, encadenamiento, historial de fórmulas.

## Casos especiales de cálculo

- [[Grossing-up y tipo de cambio]] — neto garantizado, bucle de convergencia, rescate por redondeo, TC vendedor/comprador y el diseño propuesto.
- [[Tope SIPA]] — tope mensual con varias liquidaciones por mes, `PERIODO_ACUM` / `PERIODO_CONCEPTO` y la propuesta.

## Procesos y operación

- [[Procesos por lotes y progreso]] — crear/calcular en lote, guardas, "crear y calcular" de a una, ventana de progreso.
- [[Recálculo en cadena]] — rehacer una liquidación y sus posteriores sin perder la coherencia cronológica.

## Trazabilidad y calidad

- [[Detalle del cálculo y trazabilidad]] — qué se guarda al calcular y cómo se reproduce una línea (traza de sumas y restas).
- [[Avisos y advertencias del cálculo]] — catálogo de avisos y controles que no esperan al cálculo.
- [[Rendimiento y caché del cálculo]] — mapa de cachés, reglas para no romper nada y estado de la revisión de rendimiento.
- [[Divergencias entre documentación vieja y código]] — dónde los documentos de la raíz, los comentarios y algunas lecciones ya no coinciden.

## Lecciones más ligadas a esta carpeta

[[acumuladores-orden-calculo]] · [[al-sin-cortocircuito]] · [[arroba-ignora-el-par-del-concepto]] · [[atributo-comparar-por-codigo]] · [[concepto-negativo-despues-de-sus-consumidores]] · [[control-precedencia-formulas]] · [[dos-parametros-mismo-nombre]] · [[grossing-up-tapa-errores]] · [[parametro-y-atributo-mismo-nombre]] · [[system-variables-conventions]] · [[variable-sistema-hay-que-sembrarla]] · [[xrec-no-confiable-con-addin]]
