---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, informe-capitan]
fuente: [src/Tables/Tab110049.StgInformeCapCabNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Informe Cap Cab NAV

**Tabla 110049 `Stg Informe Cap Cab NAV`** (*Staging Informe del Capitán - Cabecera*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** El informe del capitán de una marea antes de aplicarse: una fila por proyecto (la clave de `Cab. informe capitán` en NAV es sólo el No. de proyecto). Sirve para el caso en que un tripulante **corta la marea** (accidente, urgencia) y se le liquida la producción hasta ese día: el informe da el total del viaje por clasificación, los días a bordo salen del historial de estados y el prorrateo se hace con esas dos cosas.

> [!warning] Este informe NO tiene detalle diario
> Es por marea. Si hace falta la producción real de un día concreto el origen es otro: *On board capture* (tablas 50501/50502 de la personalización), que se trae en [[Tabla - Stg Dia Abordo Lin NAV]].

## Clave primaria
`"No Proyecto"` (Code[20]). Secundaria `("Estado Sinc","No Proyecto")`.

## Campos relevantes
`Capitan`, `Actividad`, `Fecha Inicio Descarga`, `Cantidad` (**Cantidad Total**; en NAV es FlowField = suma de las líneas, se trae como control: si no coincide con la suma de lo que llegó, faltaron líneas) y campos 90–95.

## Se aplica sobre
`Cab. informe capitán` (`Cod110037.AplicarInformeCapCab`).

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarInformeCapCab` o el job SQL (entity sets `CabInfoCap`; tabla NAV 50559).
- **Aplica:** `Cod110036.ProcesarInformeCapCab` (después de las descargas por dependencia: su clave es el proyecto), difiere si falta el proyecto.
- **Lee:** página `Sinc. Informe Cap. Cab NAV` (110040).
- **Permisos:** Admin RIMD, Liquidador R, Lectura R.

## Trampas
- Cabecera y líneas del informe vienen en **dos entity sets** (no hay Query que los junte): son dos pedidos.
- `ReprocesarErrores` **no** contempla esta entidad (ver [[Patrón de las tablas de staging NAV]]).

## Relacionado
[[Tabla - Stg Informe Cap Lin NAV]] · [[Tabla - Stg Dia Abordo Cab NAV]] · [[Tabla - Stg Proyecto NAV]] · [[produccion-no-se-prorratea]]
