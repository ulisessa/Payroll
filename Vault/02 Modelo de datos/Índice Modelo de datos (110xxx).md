---
tipo: referencia
tags: [modelo-de-datos, indice]
fuente: [src/Tables/Tab110000.RegistroProcesoLiq.al, src/Tables/Tab110061.TramoCoberturaLiq.al, src/PermissionSets/]
actualizado: 2026-10-04
---

# Índice Modelo de datos (110xxx)

Las **42 tablas** del rango 110000–110061 (el resto de los objetos de datos, 50xxx y 60xxx, se documentan aparte). Distribución: **31 declaradas persistentes** y **11 `TableType = Temporary`**. Hay huecos de numeración (110015–110033 y 110039 **no son tablas**: esos números se usan para páginas y codeunits). Mapas visuales en [[Mapa del modelo de datos - atributos, novedades, francos y sincronización]].

> [!note] Nombre de archivo vs objeto
> El ID y el nombre **declarados dentro del archivo** mandan. Dos archivos engañan: `Tab110013.PeriodosLiqBuffer.al` declara `Cobertura Liq. Buffer`, y `Tab110034.VariableLiqTest.al` es un catálogo de variables, no un test.

## Auditoría y bitácora
| ID | Tabla | Tipo | Nota |
|---|---|---|---|
| 110000 | `Registro Proceso Liq.` | Persistente | [[Tabla - Registro Proceso Liq]] |
| 110001 | `Entrada Registro Liq.` | Persistente | [[Tabla - Entrada Registro Liq]] |
| 110002 | `Historial Fórmula Concepto` | Persistente | [[Tabla - Historial Fórmula Concepto]] |
| 110009 | `Uso Parámetro Liq.` | Persistente (índice) | [[Tabla - Uso Parámetro Liq]] |

## Atributos tipados y entidades
| ID | Tabla | Tipo | Nota |
|---|---|---|---|
| 110003 | `Tipo Atributo Liq.` | Persistente | [[Tabla - Tipo Atributo Liq]] |
| 110004 | `Valor Atributo Liq.` | Persistente | [[Tabla - Valor Atributo Liq]] |
| 110005 | `Atributo Entidad Liq.` | Persistente (effective-dated) | [[Tabla - Atributo Entidad Liq]] |
| 110006 | `Clase Entidad Liq.` | Persistente | [[Tabla - Clase Entidad Liq]] |
| 110008 | `Entidad Liq.` | Persistente | [[Tabla - Entidad Liq]] |

## Novedades, fases, tipos de liquidación y cobertura
| ID | Tabla | Tipo | Nota |
|---|---|---|---|
| 110038 | `Novedad Liquidación` | Persistente | [[Tabla - Novedad Liquidación]] |
| 110048 | `Fase Alta Empleado` | Persistente | [[Tabla - Fase Alta Empleado]] |
| 110059 | `Estado Tipo Liq.` | Persistente | [[Tabla - Estado Tipo Liq]] |
| 110061 | `Tramo Cobertura Liq.` | Persistente (derivado) | [[Tabla - Tramo Cobertura Liq]] |

## Francos
| ID | Tabla | Tipo | Nota |
|---|---|---|---|
| 110012 | `Saldo Inicial Francos Liq.` | Persistente (hoja de carga) | [[Tabla - Saldo Inicial Francos Liq]] |
| 110011 | `Francos Buffer Liq.` | Temporal | [[Buffers temporales - francos y antigüedad]] |
| 110014 | `Lote Franco Buffer Liq.` | Temporal | [[Buffers temporales - francos y antigüedad]] |

## Sincronización NAV (staging y control)
Diseño común en [[Patrón de las tablas de staging NAV]].

| ID | Tabla | Tipo | Nota |
|---|---|---|---|
| 110041 | `Ctrl Sinc NAV` | Persistente | [[Tabla - Ctrl Sinc NAV]] |
| 110046 | `Config Sinc NAV` | Persistente (`DataPerCompany = false`) | [[Tabla - Config Sinc NAV]] |
| 110047 | `Stg Valor Dim NAV` | Persistente | [[Tabla - Stg Valor Dim NAV]] |
| 110045 | `Stg Empleado NAV` | Persistente | [[Tabla - Stg Empleado NAV]] |
| 110042 | `Stg Proyecto NAV` | Persistente | [[Tabla - Stg Proyecto NAV]] |
| 110043 | `Stg Descarga Cab NAV` | Persistente | [[Tabla - Stg Descarga Cab NAV]] |
| 110044 | `Stg Descarga Lin NAV` | Persistente | [[Tabla - Stg Descarga Lin NAV]] |
| 110049 | `Stg Informe Cap Cab NAV` | Persistente | [[Tabla - Stg Informe Cap Cab NAV]] |
| 110050 | `Stg Informe Cap Lin NAV` | Persistente | [[Tabla - Stg Informe Cap Lin NAV]] |
| 110051 | `Stg Dia Abordo Cab NAV` | Persistente | [[Tabla - Stg Dia Abordo Cab NAV]] |
| 110052 | `Stg Dia Abordo Lin NAV` | Persistente | [[Tabla - Stg Dia Abordo Lin NAV]] |

## Archivo de historia Meta4
| ID | Tabla | Tipo | Nota |
|---|---|---|---|
| 110054 | `Hist. Liq. Meta4` | Persistente (~485.000 filas) | [[Tabla - Hist. Liq. Meta4]] |
| 110055 | `Columna Hist. Meta4` | Persistente (~1.818 filas) | [[Tabla - Columna Hist. Meta4]] |
| 110056 | `Valor Hist. Meta4` | Persistente (~117 M filas) | [[Tabla - Valor Hist. Meta4]] |
| 110057 | `Comp. Meta4 Buffer` | Temporal | [[Buffers temporales - comparador Meta4 y auxiliares]] |
| 110058 | `Comp. Det. Meta4 Buffer` | Temporal | [[Buffers temporales - comparador Meta4 y auxiliares]] |

## Buffers de interfaz y control (temporales)
| ID | Tabla | Nota |
|---|---|---|
| 110007 | `Árbol Liquidaciones Buffer` | [[Buffers temporales - control y consulta de liquidaciones]] |
| 110010 | `Control Marea Buffer` | idem |
| 110013 | `Cobertura Liq. Buffer` | idem |
| 110053 | `Paso Cálculo Línea` | idem |
| 110034 | `Variable Liq. Test` | idem |
| 110040 | `Antigüedad Plantilla Buffer` | [[Buffers temporales - francos y antigüedad]] |
| 110060 | `Mes Filtro Liq.` | [[Buffers temporales - comparador Meta4 y auxiliares]] |

## Buffers declarados persistentes (scratch)
`Tipo Liq. Selección Buffer` (110035), `Diag. Fuente Datos Buffer` (110036), `Diag. Orden Acum. Buffer` (110037): [[Buffers de selección y diagnóstico (110035-110037)]].

## Permisos: tablas persistentes ausentes de los PermissionSets
Verificado en `src/PermissionSets/PermSet50300/50301/50302` (`tabledata`) y sin `InherentPermissions` en ninguna tabla:

| Tabla | Presente en |
|---|---|
| `Estado Tipo Liq.` (110059), `Tramo Cobertura Liq.` (110061) | **ninguno** (el motor y el lote las usan en cada cálculo) |
| `Stg Valor Dim NAV` (110047) | ninguno |
| `Hist. Liq. Meta4`, `Columna Hist. Meta4`, `Valor Hist. Meta4` (110054–110056) | ninguno (sólo SUPER) |
| `Diag. Fuente Datos Buffer`, `Diag. Orden Acum. Buffer` | ninguno |
| `Tipo Liq. Selección Buffer` (110035) | sólo Admin |

## Reglas transversales del modelo
- **Vigencias:** historial contiguo con la regla "última vigencia con `Desde <= fecha` y `Hasta` vacío o `>= fecha`": [[Tabla - Atributo Entidad Liq]], [[estado-empleado-effective-dated]].
- **Valores congelados:** el valor numérico se copia al asignar para que una liquidación vieja recalcule con el número que usó.
- **Sin `TableRelation` a propósito** cuando el destino depende de otro campo (`Cód. Entidad`, `Cód. Valor`, `Cód. Valor Padre`).
- **Preferir configuración a tablas:** [[avoid-tables-principle]].

## Relacionado
[[Mapa del modelo de datos - atributos, novedades, francos y sincronización]] · [[rangos-licencia-objetos]]
