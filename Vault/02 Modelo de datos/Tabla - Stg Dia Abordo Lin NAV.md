---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, diario-de-abordo, produccion]
fuente: [src/Tables/Tab110052.StgDiaAbordoLinNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Dia Abordo Lin NAV

**Tabla 110052 `Stg Dia Abordo Lin NAV`** (*Staging Diario de Abordo - Líneas*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** **La producción día por día**: la única fuente con esa granularidad (el informe del capitán consolida por marea y las descargas registran lo que bajó a puerto al final). Permite liquidarle a un tripulante lo producido hasta la fecha en que dejó el barco; sin esto sólo se podría prorratear el total por días a bordo, que no es lo mismo porque la pesca no se reparte pareja.

## Clave primaria
`("No Proyecto","Line No")`. Secundarias `("Estado Sinc","No Proyecto","Line No")` y `PorFecha`: `("No Proyecto","Fecha Registro")`.

## Campos relevantes
| Campo | Propósito |
|---|---|
| `Fecha Registro` | El día al que corresponde la producción: el campo que hace útil a la tabla. |
| `Concepto` (Code[10]) | Distingue días de pesca de los que no lo son (PUERTO, navegación). **Un día en puerto trae cantidad y kilos en cero y eso es el dato, no un faltante.** |
| `Producto` | En OData llega como `N_x00BA_` (el "No." de la línea con el símbolo de ordinal codificado); buscarlo por el nombre legible devuelve vacío sin fallar. |
| `Descripcion` (Text[199]), `Cantidad`, `Kilos` | |
| `Unidad Medida Desc` | OData expone la **descripción** de la unidad, no su código. |
| `Zona Pesca`, `Enviado` | Texto y no se escribe en BC (ver cabecera). |
| 90–95 | Estado de sincronización común. |

## Se aplica sobre
`On board capture lines` (tabla NAV 50502) vía `Cod110037.AplicarDiaAbordoLin`.

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarDiaAbordoLin` o el job SQL (entity set `LinDiaAbordo`).
- **Aplica:** `Cod110036.ProcesarDiaAbordoLin`, después de la cabecera.
- **Lee:** página `Sinc. Dia Abordo Lin NAV` (110043).
- **Permisos:** Admin RIMD, Liquidador R, Lectura R.

## Trampas
- Si se necesita el *código* de unidad de medida hay que agregarlo a la página de NAV origen.
- `ReprocesarErrores` no contempla esta entidad ([[Patrón de las tablas de staging NAV]]).
- [[produccion-no-se-prorratea]]: la producción de la marea no se prorratea por días; esta tabla es lo que habilitaría el corte por fecha.

## Relacionado
[[Tabla - Stg Dia Abordo Cab NAV]] · [[Tabla - Stg Informe Cap Lin NAV]] · [[Tabla - Stg Descarga Lin NAV]]
