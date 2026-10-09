---
tipo: tabla
tags: [modelo-de-datos, integracion-nav, staging, descargas, produccion]
fuente: [src/Tables/Tab110044.StgDescargaLinNAV.al, src/Codeunits/Cod110037.AplicarFilaSincNAV.al, src/Codeunits/Cod110041.TraerNAVWS.al]
actualizado: 2026-10-04
---

# Tabla - Stg Descarga Lin NAV

**Tabla 110044 `Stg Descarga Lin NAV`** (*Staging Descarga - Líneas NAV*). **Datos persistentes** (staging). Patrón común: [[Patrón de las tablas de staging NAV]].

**Propósito.** Espejo de `Lín. descarga` (tabla 50562 de NAV), de donde sale **la producción de la marea**. Se copian **todos** los campos de datos del origen, no sólo los kilos: el motor la lee por Fuente de Datos, y una Fuente de Datos puede filtrar o sumar por cualquier campo (subfamilia, actividad, puerto) sin tocar código. Recortar la copia sería decidir hoy qué conceptos se van a poder configurar mañana. Quedan afuera únicamente los FlowFields del origen.

## Clave primaria
`("No Proyecto","Line No")`. Secundaria `("Estado Sinc","No Proyecto","Line No")`.

## Campos relevantes
| Campo | Propósito |
|---|---|
| `No Remito`, `Item No`, `Descripcion`, `Unidad Medida` | Identifican el remito y el producto. |
| `Cantidad`, `Peso Neto`, `Peso Bruto`, `Promedio`, `Tara`, `Bruto Mas Tara`, `Peso Manual`, `Unidad Medida Manual` | Magnitudes de peso. |
| `Fecha Remito`, `Hora Ingreso`, `Fecha Hora Pesaje` | Fechas/horas. |
| `Licencia Transporte`, `Temperatura`, `Tipo Amparo Sanitario` (ordinal), `No Amparo Sanitario`, `Destino`, `No Pallet`, `Cod Camara`, `Bin Code` | Logística y sanidad. |
| `Buque`, `Marea`, `Puerto`, `Actividad`, `Familia`, `Subfamilia` | Clasificación. **`Subfamilia`** es la que agrupan las Fuentes de Datos de producción (langostino cola, entero, merluza). |
| `Confirmado` (ordinal), `Estado Origen` | Estado en el origen. |
| 90–95 | Estado de sincronización común. |

## Se aplica sobre
`Lín. descarga` (`Cod110037.AplicarDescargaLin`).

## Quién la lee y la escribe
- **Escribe:** `Cod110041.VolcarDescargas` (junto con la cabecera; la cabecera mueve las dos marcas de agua porque una línea puede cambiar sin que cambie su cabecera) o el job SQL.
- **Aplica:** `Cod110037.AplicarDescargaLin`, orquestado por `Cod110036.ProcesarDescargasLin` (difiere si falta el proyecto).
- **Lee:** página `Sinc. Lín. Descargas NAV` (110036). El motor lee la tabla **real** `Lín. descarga`, no esta.
- **Permisos:** Admin RIMD, Liquidador R, Lectura R.

## Trampas
- Volumen: la Query `DetalleDescargas` devuelve del orden de 240.000 filas planas; por eso se pide una vez y se parte.
- Los campos de opción llegan como ordinal (`Tipo Amparo Sanitario`, `Confirmado`): traducir captions a ordinal sin verificar el orden real es cómo se guarda un valor plausible y equivocado.
- Si cambia una línea en NAV, la fila vuelve a Pendiente y se reaplica sobre `Lín. descarga`.

## Relacionado
[[Tabla - Stg Descarga Cab NAV]] · [[Tabla - Stg Informe Cap Lin NAV]] · [[Tabla - Stg Dia Abordo Lin NAV]] · [[produccion-no-se-prorratea]] · [[produccion-oficiales-poteros]]
