---
tipo: tabla
tags: [modelo-datos, transaccional, novedades]
fuente: [src/Tables/Tab60020.IncidenciaLiquidacion.al]
actualizado: 2026-10-04
---

# Tabla - Incidencia Liquidación (60020)

## Propósito
Importes **manuales o materializados** por liquidación para conceptos que necesitan carga de dato (ajustes, retroactivos, gratificaciones, cuotas de préstamo, novedades). La fórmula las lee vía una [[Tabla - Fuente Datos Liquidación]] (patrón `INCID_<concepto>`: filtro `No. Liquidación = {LIQ_NO}`, `Cód. Concepto = <literal>`, función LOOKUP, campo Importe).

Las **novedades** pre-liquidación (`Novedad Liquidación`, 110038) se cargan contra un período y se **materializan** como incidencias al calcular: ver [[novedades-pre-liquidacion]] y [[anticipos-como-novedades]].

## PK
`No. Liquidación` + `Cód. Concepto` (clustered): **una incidencia por concepto y liquidación**.

## Campos
| Campo | Tipo | Propósito |
|---|---|---|
| `No. Liquidación` (1) | → [[Tabla - Liquidación]] | |
| `Cód. Concepto` (2) | → [[Tabla - Concepto Liquidación]] | |
| `Importe` (3) | Decimal (2:2) | |
| `Cantidad` (6), `Valor Unitario` (8), `Unidad Cantidad` (7 → Unit of Measure) | | `Cantidad × Valor Unitario` autocompleta `Importe` (`Round(...,0.01)`) cuando ambos están cargados; una edición manual posterior de `Importe` se respeta hasta que se revalide uno de los dos |
| `Observaciones` (4) | Text[250] | |
| `Cód. Cuota Préstamo` (5) | Code[30] | Lo llena el módulo de préstamos (`"No.Prestamo|NoCuota"`); identifica las incidencias generadas por préstamos para limpiarlas al revertir |
| `Desde Novedad` (9) | Boolean | Marca las materializadas desde una novedad: permite borrarlas y regenerarlas en cada recálculo sin tocar las manuales |

## Triggers
- OnInsert/OnModify/OnDelete → `ValidarEstadoBorrador`: sólo se tocan incidencias de liquidaciones en **Borrador**.
- **OnModify**: tocar a mano una incidencia `Desde Novedad` la convierte en manual (`Desde Novedad := false`) → el recálculo la respeta en vez de rehacerla desde la novedad.

## Quién la lee / escribe
Escribe: `Cod50061.GestionNovedadesLiq` (materializa novedades; sólo inserta), `Cod50051.GestionPrestamos` (cuotas), `Cod50052.GestionIncidenciaMasiva`, `Cod50014.MotorLiquidacion` (limpieza al recalcular). Páginas: `Pag50148 Incidencias Liquidación Sub`.

## Vigencias
No tiene; vive y muere con la liquidación (Borrador).

## Trampas conocidas
> [!warning] Novedad con proyecto queda huérfana
> Una novedad con proyecto sólo entra en la liquidación de **ese** proyecto: 95 sin aplicar en enero sin ningún aviso. Ver [[novedad-con-proyecto-queda-huerfana]], [[novedad-estado-apunta-a-proyecto-sin-liquidar]] y [[novedad-tipo-liq-y-fecha-se-pelean]].

- Una novedad en cero quedaba Aplicada y la fórmula corría igual: [[novedad-en-cero-no-apagaba-el-concepto]].
- Anticipos viven en cuenta corriente y no son haberes: [[anticipos-cta-cte-meta4]], [[anticipo-no-es-haber-del-recibo]].
- Un valor, una fuente: no duplicar el dato en parámetro e incidencia ([[un-valor-una-fuente]]).
