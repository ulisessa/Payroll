---
tipo: referencia
tags: [permisos, perfiles, role-center, seguridad]
fuente: [src/Profiles/Prof50300.PayrollManager.al, src/Profiles/Prof50301.DirectorTI.al, src/Pages/Pag50149.PayrollRoleCenter.al, src/PageExtensions/PagExt50352.ITManagerRCPayrollExt.al, src/PermissionSets/PermSet50300.LiqPescaAdmin.al, src/PermissionSets/PermSet50301.LiqPescaLiquidador.al, src/PermissionSets/PermSet50302.LiqPescaLectura.al]
actualizado: 2026-10-04
---

# Perfiles, Role Center y permisos

## Perfiles de BC

| Perfil (código) | Caption | Role Center | Para quién |
|---|---|---|---|
| `PAYROLL-MANAGER` (`Prof50300`) | *Payroll Manager* | `Payroll Role Center` (Pag50149), caption **Liquidación de Sueldos** | Liquidador: operación diaria. `Promoted = true`, `Enabled = true` |
| `DIRECTOR-TI` (`Prof50301`) | *Director de TI* | `Administrator Role Center` (el estándar de BC) con una sección agregada por `PagExt50352` | Configuración + operación |

El comentario de `Prof50301` avisa: el archivo sólo hace falta si *Director de TI* **no** existe ya en otra extensión; si existe, hay que borrarlo (la page extension alcanza).

> [!note] Divergencia con la guía vieja
> `GUIA-LIQUIDACION.md` decía que el Role Center del Director de TI es "IT Manager". En el código extiende `Administrator Role Center` (página 9018 según el comentario del perfil), no el Role Center de IT Manager. El nombre del archivo (`ITManagerRCPayrollExt`) induce a error.

## Role Center *Liquidación de Sueldos*

Una tarjeta de actividades (`Cue SIRADIG`, parte `CueSiradig`) y cinco secciones de navegación. La lista completa con ID y qué hace cada página está en [[Mapa de páginas por menú]].

| Sección (caption) | Contenido |
|---|---|
| **Nómina** | Liquidaciones, Árbol de Liquidaciones, Períodos, Novedades de Liquidación, Lanzador de Liquidaciones, Tipos de Liquidación |
| **Convenios** | Convenios Colectivos, Categorías CCT, Conceptos, Fórmulas con errores |
| **Parámetros** | Parámetros, Árbol de Parámetros, Parámetros Vigentes, Variables Sistema, Fuentes de Datos, Tipos de Atributo, Valores de Atributo, Clases de Entidad, Entidades, Tablas Escalonadas, Ded. Ganancias (AFIP) |
| **Empleados** | Estados Empleado, Antigüedad de la Plantilla, Cód. Estados, Francos por Tripulante, Saldo Inicial de Francos, Asignar Atributos en Lote, Migrar Convenio y Categoría, Atributos, Importaciones SIRADIG |
| **Herramientas** | Asistente de Fórmulas, Historial de Fórmulas, Registros de Proceso, Versiones Inactivas a Revisar, Control de Orden de Cálculo, Días Liquidados por Empleado, Conceptos por Tipo Liq., Convenios por Concepto, Conceptos por Convenio, Buques |
| **Informes** (área *Reporting*) | Recibo de Sueldo, Asignar Estado Masivo, Insertar Incidencia Masiva, Crear Liq. para Empleado, Préstamos y Anticipos |

### Lo que el Role Center de *Director de TI* agrega

`PagExt50352` agrega a `Administrator Role Center` tres grupos: **Liquidaciones** (Liquidaciones, Períodos, Lanzador), **Convenios CCT** (Convenios, Categorías, Conceptos) y **Config. Payroll** (Parámetros, Parámetros Vigentes, Variables Sistema, Fuentes de Datos, Tablas Escalonadas, Ded. Ganancias, Asistente de Fórmulas, Estados Empleado, Cód. Estados y **Config. RR.HH. (Series)**, que abre `Human Resources Setup`). **No** trae Árbol, Novedades, Tipos de Liquidación, atributos ni controles: quien administre con ese perfil los alcanza por la búsqueda de BC (*Alt+Q*) o cambiando al perfil *Payroll Manager*.

### Pantallas que no tienen entrada en ningún menú

Se llegan por búsqueda o desde otra página: *Comparar BC contra Meta4*, *Historia de Liquidaciones (Meta4)*, *Control de Liquidación por Período* (desde Períodos), *Control de Liquidación por Marea* (desde el Job), todas las páginas de *Sincronización con NAV* (se abren por búsqueda; `Control Sinc. NAV` es `UsageCategory = Administration`) y *Fases de Alta* (desde la ficha del empleado).

## Permission sets

Los tres son `Assignable = true` y cubren **sólo** objetos del módulo (rango 50000-61000 y 110000+). Para tener acceso completo hay que asignar además roles estándar de BC: *D365 HUMAN RES, FULL* (Employee / HR Setup) y *D365 PROJECT MGMT* (Job = marea). Está escrito como comentario en cada archivo.

| Permission set (ID) | Caption | Qué permite |
|---|---|---|
| `PermSet50300` | **Liq. Pesca - Admin** | `RIMD` sobre **todas** las tablas del módulo (configuración y operación), `RM` sobre `Human Resources Setup`; ejecuta todas las páginas del módulo, los informes y la página *Human Resources Setup*. Es el **único** con `Tipo Liq. Selección Buffer`, la página *Concepto CCT Vigente List*, *Versiones Inactivas a Revisar*, *Tipo Liq. Selección Sub* y el informe *Migrar Convenio y Categoría* |
| `PermSet50301` | **Liq. Pesca - Liquidador** | Operación completa: `RIMD` en `Liquidación`, `Línea Liquidación`, `Personal Proyecto`, `Incidencia`, `Novedad`, `Ded. Ganancias Empleado`, buffers de control; `RIM` en `Período Liquidación`, `Estado Empleado`, atributos y entidades, registros de proceso e historial de fórmulas. La **configuración maestra queda de sólo lectura** (convenios, categorías, conceptos, parámetros, fuentes, tablas escalonadas, variables, Ganancias vigente, sincronización NAV). Ejecuta *Lanzador*, *Asistente de Fórmulas*, *Conceptos por Convenio/Tipo Liq.*, y los informes *Recibo*, *Asignar Estado Masivo* y *Asignar Atributo Masivo* |
| `PermSet50302` | **Liq. Pesca - Lectura** | `R` sobre todo, salvo los buffers de las pantallas de control (`Control Marea Buffer`, `Francos Buffer Liq.`, `Cobertura Liq. Buffer`, `Fase Alta Empleado`, `Antigüedad Plantilla Buffer`), que son `RIMD` porque las páginas los llenan al abrirse. Ejecuta las pantallas de consulta y el informe *Recibo de Sueldo*; **no** ejecuta el Lanzador, el Asistente ni los informes masivos |

Los tres permiten además ejecutar los codeunits internos que cada pantalla necesita (el Liquidador, por ejemplo, necesita `Convenio Categoría Liq.` porque lo llama el motor; sin eso "liquidar falla para este rol", según el comentario del código).

## Qué puede y qué no puede cada rol en la operación

| Acción | Admin | Liquidador | Lectura |
|---|:-:|:-:|:-:|
| Crear / calcular / aprobar / reabrir liquidaciones | Sí | Sí | No |
| Cargar novedades e incidencias | Sí | Sí | No |
| Cerrar / reabrir períodos | Sí | Sí (`RIM`; no puede **borrar** períodos) | No |
| Editar conceptos, parámetros, fuentes, convenios | Sí | No (sólo lee) | No |
| Imprimir recibo | Sí | Sí | Sí |
| Migrar convenio y categoría | Sí | No | No |

> [!warning] Objetos sin permisos asignados en ningún set
> Al cruzar `src/` con los tres sets se encontraron objetos del módulo que **no figuran en ninguno**. Un usuario sin `SUPER` / *D365 FULL ACCESS* podría recibir "no tiene permisos" al abrirlos. No se probó en runtime (**sin verificar**); la lista es la verificable en el código al 2026-10-04:
>
> - **Informes:** *Crear Liq. para Empleado*, *Insertar Incidencia Masiva*, *Avisos del Cálculo*.
> - **Páginas operativas:** *Control Liquidación Período*, *Líneas Liq. con Variables*, *Importaciones SIRADIG* (+ *Carpeta SIRADIG Dialog*, *Cue SIRADIG*), *Lista/Ficha de Préstamos* (+ *Cuotas*), *Resumen Variable Liq. Sub*, *Tramos Cobertura Sub*, *Estados Tipo Liq. Sub*, *Filtro Fuente Datos Liq. Sub*, *Selector Tipos Liq.*, *Nuevo Codigo Dialog* y las de sincronización NAV de informes del capitán, diario de abordo y valores de dimensión.
> - **Tablas** (`tabledata`): `Tramo Cobertura Liq.`, `Estado Tipo Liq.`, `Filtro Fuente Datos Liq.`, `Préstamo Empleado`, `Cuota Préstamo`, `Importación SIRADIG`, `Cue SIRADIG`, `Hist. Liq. Meta4`, `Columna Hist. Meta4`, `Valor Hist. Meta4`, `Stg Valor Dim NAV`.
> - **Codeunits:** `Gestión Préstamos`, `Gestión Incidencia Masiva`, los de SIRADIG y los de sincronización NAV por web services.
>
> Si se asigna el set a un usuario real, probar con ese usuario cada pantalla que use. Ver [[rangos-licencia-objetos]] para los rangos de IDs que habilita la licencia.

## Relacionado

- [[Mapa de páginas por menú]] · [[Qué es y para qué sirve este sistema]]
- Modelo de datos: [[Tabla - Liquidación]], [[Tabla - Período Liquidación]]

## Ver también

[[Permission sets de la extensión]] (detalle técnico) · [[Rangos de IDs y licencia]] · [[Install y Upgrade - qué siembra cada uno]]
