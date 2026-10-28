---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, informe-capitan]
fuente: [src/Tables/Tab110050.StgInformeCapLinNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Informe Cap Lin NAV

**Tabla 110050 `Stg Informe Cap Lin NAV`** (*Staging Informe del Capitán - Líneas*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** El detalle del informe del capitán: una fila por **clasificación** declarada en la marea. La *clasificación* es el grado del producto (L-1, L-2, L-ENTERO...) y es lo que decide con qué valor se liquida cada kilo; no confundirla con el lote ni con la familia (la familia agrupa, la clasificación tarifa).

## Clave primaria
`("No Proyecto","Line No")`. Secundaria `("Estado Sinc","No Proyecto","Line No")`. `Line No` sin punto ni acento: `LineNo` a secas es palabra reservada de T-SQL.

## Campos relevantes
`Clasificacion` (Code[20]), `Descripcion` (Text[150]), `Unidad Medida` (Code[10]), `Cantidad` (Decimal) y campos 90–95.

## Se aplica sobre
`Lín. informe capitán` (`Cod110037.AplicarInformeCapLin`).

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarInformeCapLin` o el job SQL (entity set `LinInfoCap`; tabla NAV 50560).
- **Aplica:** `Cod110036.ProcesarInformeCapLin` (cabecera primero, por dependencia), difiere si falta el proyecto.
- **Lee:** página `Sinc. Informe Cap. Lin NAV` (110041).
- **Permisos:** Admin RIMD, Liquidador R, Lectura R.

## Trampas
- Contrastar `Cantidad` total de la cabecera contra la suma de estas líneas detecta líneas perdidas en la traída.
- `ReprocesarErrores` no contempla esta entidad ([[Patrón de las tablas de staging NAV]]).

## Relacionado
[[Tabla - Stg Informe Cap Cab NAV]] · [[Tabla - Stg Descarga Lin NAV]] · [[produccion-oficiales-poteros]]
