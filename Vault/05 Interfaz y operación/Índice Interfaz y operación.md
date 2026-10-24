---
tipo: referencia
tags: [indice, manual-usuario, operacion, ui]
fuente: [src/Pages, src/PageExtensions, src/Profiles, src/PermissionSets, src/Reports]
actualizado: 2026-10-04
---

# Índice: Interfaz y operación

Manual del **usuario y operador** del sistema de liquidación. Todo lo que está acá se verificó contra el código (captions y tooltips reales). Reglas de redacción: [[_Convenciones del vault]].

## Empezar

| Nota | Para qué |
|---|---|
| [[Qué es y para qué sirve este sistema]] | Visión, alcance, usuarios, qué reemplaza (Meta4), qué no hace |
| [[Perfiles, Role Center y permisos]] | Perfiles, menú *Liquidación de Sueldos* y los 3 permission sets (con huecos detectados) |
| [[Mapa de páginas por menú]] | Todas las páginas del menú: caption, ID, qué hace, desde dónde se abre |
| [[Mapa de páginas auxiliares y subpáginas]] | Fichas, subpáginas, FactBoxes, diálogos |

## Operar el mes

| Nota | Para qué |
|---|---|
| [[Flujo operativo mensual de liquidación]] | La receta completa, de los datos al cierre del período |
| [[Novedades e incidencias - carga operativa]] | Cargar lo que no sale de una fórmula |
| [[Lanzador de liquidaciones y lotes]] | Crear y calcular en lote; cuándo corresponde cada tipo |
| [[Crear, calcular, aprobar y reabrir liquidaciones]] | Ciclo de vida de una liquidación y sus bloqueos |
| [[Árbol de liquidaciones]] | Acciones por nodo con subtotales |
| [[Recibo de sueldo (reporte)]] | Imprimir y qué trae cada diseño |
| [[Reportes y procesos masivos]] | Informes de proceso y acciones de "una sola vez" |
| [[Importación SIRADIG - operación]] | Deducciones y cargas de familia de Ganancias |

## Configurar

| Nota | Para qué |
|---|---|
| [[Configurar un concepto (guía paso a paso)]] | Ficha del concepto, tipos, fórmula, acumuladores, convenios, vigencias |
| [[Configurar un parámetro y su vigencia]] | Alcance, cascada, En Uso |
| [[Configurar fuentes de datos]] | Tablas, funciones, filtros y tokens |
| [[Ejemplos completos de conceptos]] | Recetas didácticas y fórmulas reales |

## Controlar y diagnosticar

| Nota | Para qué |
|---|---|
| [[Asistente de fórmulas y detalle del cálculo]] | Probar una fórmula; explicar una línea ya liquidada |
| [[Controles y avisos del cálculo]] | Catálogo de avisos y errores, y pantallas de control |
| [[Dónde se usa un símbolo]] | Qué fórmulas, filtros y acumuladores nombran a algo, y quién lo lee antes de que esté listo |
| [[Reporte SICOSS]] | La declaración mensual de la seguridad social en Excel, y qué columnas no cierran contra Meta4 |
| [[Resolución de problemas frecuentes]] | De síntoma a causa |

## Memoria del manual

| Nota | Para qué |
|---|---|
| [[Discrepancias de la guía original con el código]] | Qué de `GUIA-LIQUIDACION.md` está desactualizado y dónde quedó cada sección |

## Lecciones más enlazadas desde este manual

[[acumuladores-orden-calculo]] · [[conceptos-tres-vigencias]] · [[lote-tipo-liq-en-blanco]] · [[crear-y-calcular-descarta-vacias]] · [[cuando-corresponde-una-liquidacion]] · [[novedades-pre-liquidacion]] · [[vacio-en-tipos-liq-aplicables-es-comodin]] · [[arroba-ignora-el-par-del-concepto]] · [[fuente-datos-apunta-por-numero]] · [[variable-sistema-hay-que-sembrarla]] · [[atributos-tipados]] · [[Índice de lecciones]]

## Ver también (otras áreas del vault)

Modelo de datos (`02 Modelo de datos`): [[Tabla - Liquidación]] · [[Tabla - Línea Liquidación]] · [[Tabla - Concepto Liquidación]] · [[Tabla - Parámetro Vigente]] · [[Tabla - Período Liquidación]] · [[Tabla - Registro Proceso Liq]]. Integración con NAV: [[Sincronización NAV - visión general]].

## Ver también

[[Índice Arquitectura y motor]] · [[Índice Integraciones]] · [[Índice Dominio - empleado y condiciones]] · [[Índice Dominio - marea y pagos]] · [[Índice Desarrollo y operaciones]]

- [[Carga de atributos y parámetros desde las fichas]] — carga e historial de atributos, y parámetros vinculados desde su origen.

