---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, diario-de-abordo]
fuente: [src/Tables/Tab110051.StgDiaAbordoCabNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Dia Abordo Cab NAV

**Tabla 110051 `Stg Dia Abordo Cab NAV`** (*Staging Diario de Abordo - Cabecera*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** El parte de pesca de una marea antes de aplicarse; una fila por proyecto. Es la cabecera de la **producción por día** (las líneas, en [[Tabla - Stg Dia Abordo Lin NAV]]). El informe del capitán da el total del viaje y alcanza para liquidar una marea completa; esto permite **cortar a una fecha**, que hace falta cuando un tripulante deja el barco antes. Latitud y longitud no se traen (son del parte de pesca, no de la liquidación).

## Clave primaria
`"No Proyecto"` (Code[20]). Secundaria `("Estado Sinc","No Proyecto")`.

## Campos relevantes
`Buque`, `Marea`, `Patron`, `Zona Pesca` (Text[50]), `Fecha Salida`, `Historico` (Date) y campos 90–95.

## Se aplica sobre
`On board capture` (clave `Cód. Proyecto`; tabla NAV 50501) vía `Cod110037.AplicarDiaAbordoCab`.

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarDiaAbordoCab` o el job SQL (entity set `CabDiaAbordo`).
- **Aplica:** `Cod110036.ProcesarDiaAbordoCab`.
- **Lee:** página `Sinc. Dia Abordo Cab NAV` (110042).
- **Permisos:** Admin RIMD, Liquidador R, Lectura R.

## Trampas
> [!warning] Zona de pesca como texto, y no se escribe en BC
> En BC es un campo de opción: traducir una caption a su ordinal sin poder verificar el orden es guardar un valor plausible y equivocado. Queda a la vista en el staging; antes de escribirlo hay que mirar los `OptionMembers` reales.

- `ReprocesarErrores` no contempla esta entidad ([[Patrón de las tablas de staging NAV]]).

## Relacionado
[[Tabla - Stg Dia Abordo Lin NAV]] · [[Tabla - Stg Informe Cap Cab NAV]] · [[Tabla - Stg Proyecto NAV]]
