---
tipo: tabla
tags: [modelo-datos, extension, empleado, convenios-cct]
fuente: [src/TableExtensions/TabExt52000.EmpleadoPescaExt.al]
actualizado: 2026-10-04
---

# Extensión - Employee (TabExt52000 "Empleado Pesca Ext.")

Extiende la tabla base `Employee`. Campos propios (IDs 52000–52004):

| Campo | ID | Tipo | Propósito |
|---|---|---|---|
| `Cód. Convenio` | 52000 | Code[20] → [[Tabla - Convenio Colectivo]] | **Par "de la ficha"**. OnValidate vacía la categoría |
| `Cód. Categoría` | 52001 | Code[20] → [[Tabla - Categoría CCT]] (filtrada por convenio) | Idem |
| `Antigüedad Reconocida` | 52002 | Decimal (0:2) ≥ 0, en años | Servicio previo reconocido que se suma como base. Su comentario dice "antigüedad total = este valor + años completos desde el último estado Alta en Estado Empleado": **desactualizado**, las altas hoy viven en las fases ([[Tabla - Estado Empleado]]) |
| `Zona Desfavorable` | 52003 | Integer ≥ 0 | Zona de la ficha; el motor la inyecta como `COD_ZONA` si el proyecto no trae una (ver [[Extensión - Job]]) |
| `Fecha Jubilación` | 52004 | Date | Lo lee el motor para `ES_JUBILADO` / aportes |

## Rol real del par convenio/categoría de la ficha
El encuadre efectivo del empleado es un **atributo con historial** (espejo de Convenio y Categoría CCT, ver [[atributos-tipados]] y `Cod50080.ConvenioCategoriaLiq`). El par de la ficha es **respaldo**: se usa como valor inicial de la cabecera ([[Tabla - Liquidación]] OnValidate de `No. Empleado`), como fallback en `Cod50018.ProcesoLiqPorLotes`, en `Cod110030.ControlCoberturaLiq`, en `Tab110038 Novedad Liquidación` y en el asistente de fórmulas, y lo lee `Rep50046 Migrar Convenio Categoría` para sembrar los atributos.

> [!warning] Dos fuentes para el mismo dato
> Si la ficha y el atributo discrepan, manda el atributo en el cálculo, pero la ficha se sigue viendo en `PagExt50350 EmployeeCardExt`. Ver [[un-valor-una-fuente]] y [[sindicato-obra-social-atributos]].

## Dónde se lee
`Cod50014.MotorLiquidacion` (jubilación, zona), `Cod50016.ContextoLiquidacion` (antigüedad reconocida), `Cod50017.GestionEstadoEmpleado`, `PagExt50350 Employee Card Ext`, `Pag110028 Fases de Alta`, `Pag110029 Antigüedad Plantilla`, `Tab110040`.

## Trampas
- La antigüedad es la suma de fases: [[antiguedad-suma-de-fases]], [[antiguedad-dia-por-fase]].
- El CUIL no está en un campo de esta extensión: vive en `CIF_NIF` de la tabla `$ext` ([[cuil-vive-en-cif-nif]], [[campos-extension-tabla-ext]]).
