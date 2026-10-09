---
tipo: tabla
tags: [modelo-de-datos, cobertura, liquidaciones]
fuente: [src/Tables/Tab110061.TramoCoberturaLiq.al, src/Codeunits/Cod110054.CoberturaTramosLiq.al, src/Codeunits/Cod50016.ContextoLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Tramo Cobertura Liq

**Tabla 110061 `Tramo Cobertura Liq.`** (caption *Tramos de cobertura*). **Datos persistentes** (derivados por el motor).

**Propósito.** Los tramos de días que una liquidación cubre. **Un día pertenece a UNA sola liquidación.** `Cobertura Desde/Hasta` de la cabecera es un solo intervalo y no alcanza para la Regular, que cubre "todo lo demás": con vacaciones en el medio del mes quedan dos tramos (1–4 y 26–31) y un desde/hasta sólo puede decir "del 1 al 31", que vuelve a pisar los días pagados. La cabecera conserva el desde/hasta como **envolvente**; para contar días mandan los tramos.

## Clave primaria
`("No. Liquidación","No. Línea")`. Secundaria `Fechas`: `("No. Liquidación", Desde)`.

## Campos relevantes
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` | Code[20] → [[Tabla - Liquidación]] | |
| `No. Línea` | Integer | |
| `Desde`, `Hasta` | Date | Tramo (ambos inclusive). |
| `Días` | Integer (no editable) | `Hasta − Desde + 1`, calculado en `OnInsert` y `OnModify`. |
| `Origen` | Text[50] | De dónde salió: el estado que lo justifica, la marea o "resto del período". Informativo ("no lo lee nadie"). |

## Lógica en triggers
`OnInsert`/`OnModify`: `Días := Hasta - Desde + 1`.

## Quién la lee y la escribe
- **Escribe:** `Cod110054 Cobertura Tramos Liq.`.`Recalcular(var Liq)`: borra los tramos de la liquidación, recorre los días y los reparte entre las liquidaciones del empleado en orden determinista (vacaciones, orden 30, antes que Regular, 100); ajusta `Cobertura Desde/Hasta` de la cabecera al envolvente **sin grabar** (el que llama hace el `Modify`). Lo invoca el motor `Cod50014` (línea ~125) bastante antes de aplicar novedades.
- **Lee:** `Cod50016 Contexto Liquidación` (`CargarTramos`, `DiaEnLaVentana`): para contar feriados, días, etc. dentro de lo que la liquidación realmente cubre; también la ficha (`Tramos Cobertura Sub`, 110055) y `Tab60011 Liquidación`.

## Vigencias
Se regeneran en cada cálculo; no hay historial.

## Trampas
> [!warning] Sin permisos en los PermissionSets
> `Tramo Cobertura Liq.` no figura en `LiqPescaAdmin`, `LiqPescaLiquidador` ni `LiqPescaLectura` (verificado en `src/PermissionSets/`) ni declara `InherentPermissions`, pero el motor la **escribe** en cada cálculo. Un liquidador no-SUPER recibiría error de permisos. Verificar en el entorno.

> [!warning] Sin tramos, la ventana es el desde/hasta de la cabecera
> La maquinaria entra sin cambiar resultados mientras la configuración del tipo no diga otra cosa. Al 1/10/2026 560 de las 567 liquidaciones de enero tenían tramos y 7 no; esas 7 caían al **período entero** (una mensual que cubre 1 y 2 de enero contaba los feriados de todo el mes). El contexto usa la cobertura de la cabecera como respaldo.

> [!warning] Guardar la cabecera tras Recalcular, no un Get+Modify aparte
> Un `Get`+`Modify` aparte cambia el timestamp bajo la instancia que el motor ya tiene abierta y el `Modify` del final muere con "hay información que no está actualizada".

- Un tipo con disparador de marea ya viene recortado a los días del viaje: se guarda en **un solo tramo**.
- Un día de estado se liquida una vez; antes de este reparto 133 empleados cobraron dos veces el SAC devengado, la ART, contribuciones y hasta Ganancias.

## Relacionado
[[Tabla - Estado Tipo Liq]] · [[Tabla - Liquidación]] · [[cobertura-en-tramos]] · [[ventana-liquidacion-es-cobertura]] · [[cobertura-devengado-tapa-dias]] · [[Buffers temporales - control y consulta de liquidaciones]]
