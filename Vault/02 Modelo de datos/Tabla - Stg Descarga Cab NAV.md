---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, descargas]
fuente: [src/Tables/Tab110043.StgDescargaCabNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Descarga Cab NAV

**Tabla 110043 `Stg Descarga Cab NAV`** (*Staging Descarga - Cabecera NAV*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** Espejo de `Cab. descarga` (tabla 50561 de la personalización de NAV). Su clave primaria es **sólo el proyecto**: hay una cabecera por marea, no una por remito; los remitos son las líneas ([[Tabla - Stg Descarga Lin NAV]]). La tabla no tiene código ni lógica de negocio que respetar: lo único que importa es el orden (si el proyecto no llegó a BC, la fila espera en Pendiente en vez de fallar).

## Clave primaria
`"No Proyecto"` (Code[20]). Secundaria `("Estado Sinc","No Proyecto")`.

## Campos relevantes
`Capitan`, `Actividad`, `Fecha Inicio Descarga`, `Buque`, `Marea`, `Cod Camara` (campo `Location` en origen), `Libro Diario`, `Puerto`, `Pallets Desde/Hasta`, `Hora Inicio/Fin Descarga`, `Cod Balanza`, `Registrado`, `Origen Carton` (ordinal) y los campos 90–95 comunes.

## Se aplica sobre
`Cab. descarga` (tabla de la personalización "Final Version Customization" / Tables Only), `Cod110037.AplicarDescargaCab`.

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarDescargas` (un solo pedido trae cabecera y línea de la Query `DetalleDescargas`, y el traedor la parte en dos) o el job SQL.
- **Aplica:** `Cod110037.AplicarDescargaCab`; `Cod110036.ProcesarDescargasCab` difiere (`Diferir`) si el proyecto no existe.
- **Lee:** página `Sinc. Cab. Descargas NAV` (110035).
- **Permisos:** Admin RIMD, Liquidador R, Lectura R.

## Trampas
> [!warning] Los campos se llenan antes del Insert
> `Cab. descarga` exige `Puerto` en su `OnInsert`; insertar primero y asignar después hace fallar con "Puerto debe tener un valor" una fila cuyo puerto está bien en el staging. Y sólo fallan las descargas **nuevas** (las existentes entran por `Get` y no pasan por `OnInsert`): de 2957 cabeceras fallaban 148, que parecían un problema de datos.

- `Origen del cartón` se escribe con `Validate`.
- Un `Pendiente` por proyecto inexistente cuenta intentos y pasa a Error al llegar a `Máx. Intentos Sinc.`.

## Relacionado
[[Tabla - Stg Descarga Lin NAV]] · [[Tabla - Stg Proyecto NAV]] · [[Tabla - Ctrl Sinc NAV]] · [[produccion-no-se-prorratea]]
